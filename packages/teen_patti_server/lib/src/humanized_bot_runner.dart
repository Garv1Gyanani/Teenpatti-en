import 'dart:math';

import 'package:teen_patti_core/teen_patti_core.dart';

import 'server_backend.dart';

class HumanizedBotTurnPlan {
  const HumanizedBotTurnPlan({
    required this.thinkDelay,
    required this.shouldTimeout,
    this.disconnectDuration,
    this.seeCards = false,
    this.decision,
  });

  final Duration thinkDelay;
  final bool shouldTimeout;
  final Duration? disconnectDuration;
  final bool seeCards;
  final AgentTurnDecision? decision;
}

class _BotSessionState {
  _BotSessionState({required this.bot});

  ClaimedBot bot;
  double moodOffset = 0.0;
  DateTime? disconnectedUntilUtc;
  bool hasDroppedThisSession = false;
}

/// Applies human-like pacing, marginal-hand hesitation, jitter, occasional
/// timeouts, transient disconnects, and win/loss mood drift on top of the pure
/// [BotDecisionEngine].
class HumanizedBotRunner {
  HumanizedBotRunner({
    Random? random,
    this.timeoutProbability = 0.02,
    this.sessionDisconnectProbability = 0.075,
    this.disableRandomFaults = false,
  }) : _rng = random ?? Random.secure();

  final Random _rng;
  final double timeoutProbability;
  final double sessionDisconnectProbability;
  final bool disableRandomFaults;

  final Map<String, _BotSessionState> _sessions = {};

  void registerBot(ClaimedBot bot) {
    final existing = _sessions[bot.profileId];
    if (existing != null) {
      existing.bot = bot;
    } else {
      _sessions[bot.profileId] = _BotSessionState(bot: bot);
    }
  }

  void unregisterBot(String profileId) {
    _sessions.remove(profileId);
  }

  double moodFor(String profileId) => _sessions[profileId]?.moodOffset ?? 0.0;

  bool isTemporarilyDisconnected(String profileId, DateTime nowUtc) {
    final state = _sessions[profileId];
    if (state == null || state.disconnectedUntilUtc == null) return false;
    if (!nowUtc.isBefore(state.disconnectedUntilUtc!)) {
      state.disconnectedUntilUtc = null;
      return false;
    }
    return true;
  }

  /// Loosens after losses (+moodOffset) and tightens after wins (-moodOffset).
  void recordHandOutcome(String profileId, {required int netChips}) {
    final state = _sessions[profileId];
    if (state == null) return;
    if (netChips < 0) {
      state.moodOffset = (state.moodOffset + 0.03).clamp(-0.12, 0.12);
    } else if (netChips > 0) {
      state.moodOffset = (state.moodOffset - 0.025).clamp(-0.12, 0.12);
    }
  }

  HumanizedBotTurnPlan planTurn({
    required AuthoritativeTableState authorativeState,
    required String botId,
    required DateTime nowUtc,
  }) {
    final session = _sessions[botId];
    final bot = session?.bot;
    if (bot == null) {
      return const HumanizedBotTurnPlan(
        thinkDelay: Duration(milliseconds: 1200),
        shouldTimeout: true,
      );
    }

    if (isTemporarilyDisconnected(botId, nowUtc)) {
      return const HumanizedBotTurnPlan(
        thinkDelay: Duration(milliseconds: 250),
        shouldTimeout: true,
      );
    }

    final seat = authorativeState.findPlayerById(botId);
    if (seat == null || seat.hasPacked) {
      return const HumanizedBotTurnPlan(
        thinkDelay: Duration(milliseconds: 250),
        shouldTimeout: true,
      );
    }

    // 5-10% of sessions experience a single 5-45s temporary network drop.
    if (!disableRandomFaults &&
        !session!.hasDroppedThisSession &&
        authorativeState.turnCount > 0 &&
        _rng.nextDouble() < (sessionDisconnectProbability / 4.0)) {
      session.hasDroppedThisSession = true;
      final dropSec = 5 + _rng.nextInt(41); // 5..45s
      final dropDuration = Duration(seconds: dropSec);
      session.disconnectedUntilUtc = nowUtc.add(dropDuration);
      return HumanizedBotTurnPlan(
        thinkDelay: const Duration(milliseconds: 300),
        shouldTimeout: true,
        disconnectDuration: dropDuration,
      );
    }

    // 1-3% of turns time out so the authoritative deadline auto-packs.
    if (!disableRandomFaults && _rng.nextDouble() < timeoutProbability) {
      return const HumanizedBotTurnPlan(
        thinkDelay: Duration(milliseconds: 300),
        shouldTimeout: true,
      );
    }

    final mood = session?.moodOffset ?? 0.0;
    final preObs = SeatObservation.fromTableState(
      authorativeState,
      viewerId: botId,
    );

    var seeCards = false;
    if (!seat.hasSeenCards) {
      seeCards = BotDecisionEngine.shouldSeeCards(
        preObs,
        bot.params,
        moodOffset: mood,
        random: _rng,
      );
    }

    // Build decision observation as seen if the bot just chose to look at cards.
    final decisionObs = seeCards && !seat.hasSeenCards
        ? SeatObservation(
            tableName: preObs.tableName,
            viewerId: botId,
            minStake: preObs.minStake,
            maxStake: preObs.maxStake,
            potAmount: preObs.potAmount,
            blindAmount: preObs.blindAmount,
            chaalAmount: preObs.chaalAmount,
            variant: preObs.variant,
            jokerCard: preObs.jokerCard,
            maxBlindTurns: preObs.maxBlindTurns,
            roundNumber: preObs.roundNumber,
            turnCount: preObs.turnCount,
            dealerIndex: preObs.dealerIndex,
            activeTurnIndex: preObs.activeTurnIndex,
            potLimit: preObs.potLimit,
            turnDeadline: preObs.turnDeadline,
            pendingSideShow: preObs.pendingSideShow,
            lastActionLabel: preObs.lastActionLabel,
            roundActionLog: preObs.roundActionLog,
            isRoundOver: preObs.isRoundOver,
            winnerId: preObs.winnerId,
            winReason: preObs.winReason,
            myCards: seat.cards,
            seats: [
              for (final s in preObs.seats)
                if (s.id == botId)
                  ObservedSeat(
                    id: s.id,
                    name: s.name,
                    chips: s.chips,
                    avatarAsset: s.avatarAsset,
                    seatIndex: s.seatIndex,
                    rating: s.rating,
                    isDealer: s.isDealer,
                    isActiveTurn: s.isActiveTurn,
                    hasPacked: s.hasPacked,
                    hasSeenCards: true,
                    totalBet: s.totalBet,
                    lastBetAmount: s.lastBetAmount,
                    blindTurnsTaken: s.blindTurnsTaken,
                    lastActionText: s.lastActionText,
                    hasGiftBadge: s.hasGiftBadge,
                    revealedCards: s.revealedCards,
                  )
                else
                  s,
            ],
          )
        : preObs;

    final decision = BotDecisionEngine.decideAction(
      decisionObs,
      bot.params,
      moodOffset: mood,
      random: _rng,
    );

    final delay = _sampleThinkDelay(
      meanMs: bot.thinkMeanMs,
      sigma: bot.thinkSigma,
      cards: seat.cards,
      variant: authorativeState.variant,
      jokerCard: authorativeState.jokerCard,
      hasSeen: decisionObs.self.hasSeenCards,
      bigPot: authorativeState.potAmount >= authorativeState.minStake * 8,
    );

    return HumanizedBotTurnPlan(
      thinkDelay: delay,
      shouldTimeout: false,
      seeCards: seeCards,
      decision: decision,
    );
  }

  bool decideSideShow({
    required AuthoritativeTableState authorativeState,
    required String targetBotId,
  }) {
    final session = _sessions[targetBotId];
    if (session == null) return false;
    final obs = SeatObservation.fromTableState(
      authorativeState,
      viewerId: targetBotId,
    );
    return BotDecisionEngine.decideSideShowResponse(
      obs,
      session.bot.params,
      moodOffset: session.moodOffset,
      random: _rng,
    );
  }

  Duration _sampleThinkDelay({
    required int meanMs,
    required double sigma,
    required List<PlayingCard> cards,
    required TeenPattiVariant variant,
    required PlayingCard? jokerCard,
    required bool hasSeen,
    required bool bigPot,
  }) {
    final u1 = max(1e-7, _rng.nextDouble());
    final u2 = _rng.nextDouble();
    final z = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    final mu = log(meanMs.toDouble()) - 0.5 * sigma * sigma;
    var ms = exp(mu + sigma * z);

    // Marginal hands (35th-65th percentile) receive extra deliberation time.
    if (hasSeen && cards.length == 3) {
      final eval = TeenPattiHandEvaluator.evaluate(
        cards,
        variant: variant,
        jokerCard: jokerCard,
      );
      final pct = BotDecisionEngine.handPercentile(eval, variant: variant);
      if (pct >= 0.35 && pct <= 0.65) {
        ms *= 1.25 + _rng.nextDouble() * 0.30;
      }
    }

    if (bigPot) {
      ms += 150 + _rng.nextInt(350);
    }

    // 100-600ms random jitter per action.
    final jitterMs = 100 + _rng.nextInt(501);
    final totalMs = (ms + jitterMs).round().clamp(650, 9500);
    return Duration(milliseconds: totalMs);
  }
}
