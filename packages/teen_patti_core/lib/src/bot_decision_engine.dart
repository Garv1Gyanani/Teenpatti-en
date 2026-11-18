import 'dart:math';

import 'bot_profile_params.dart';
import 'seat_observation.dart';
import 'table_player_agent.dart';
import 'table_state.dart';
import 'teen_patti_hand_evaluator.dart';

/// Pure, stateless bot decision module operating exclusively on what a single
/// seat can legally see ([SeatObservation]) plus its [BotProfileParams].
///
/// By taking [SeatObservation] instead of full [TableState], it is structurally
/// impossible for any bot to inspect the remaining deck or opponents' unrevealed
/// hole cards.
class BotDecisionEngine {
  const BotDecisionEngine._();

  /// Decides whether a currently blind seat peeks at its cards before acting.
  static bool shouldSeeCards(
    SeatObservation observation,
    BotProfileParams profile, {
    double moodOffset = 0.0,
    Random? random,
  }) {
    final self = observation.self;
    if (self.hasSeenCards || self.blindTurnsTaken >= observation.maxBlindTurns) {
      return true;
    }

    final rng = random ?? Random();
    final minBoot = max(1, observation.minStake);
    final stakeLevel = observation.blindAmount / minBoot;

    var stayBlindProb = (profile.blindPlayRate +
            (self.blindTurnsTaken == 0 && stakeLevel <= 1.0 ? 0.14 : 0.0) +
            moodOffset * 0.12)
        .clamp(0.05, 0.90);

    if (self.blindTurnsTaken >= profile.maxPreferredBlindTurns) {
      stayBlindProb *= 0.25;
    } else if (self.blindTurnsTaken > 0) {
      stayBlindProb *= pow(0.72, self.blindTurnsTaken);
    }

    if (stakeLevel >= 2.0) {
      stayBlindProb *= (0.72 - profile.opponentReadWeight * 0.22).clamp(0.25, 0.85);
    }
    if (observation.activeSeats.length <= 2) {
      stayBlindProb *= 0.72;
    }

    return rng.nextDouble() >= stayBlindProb.clamp(0.05, 0.92);
  }

  /// Picks a legal [PlayerTableAction] and optional 2x raise strictly from
  /// [observation] + [profile].
  static AgentTurnDecision decideAction(
    SeatObservation observation,
    BotProfileParams profile, {
    double moodOffset = 0.0,
    Random? random,
  }) {
    final rng = random ?? Random();
    final self = observation.self;
    final activeCount = observation.activeSeats.length;
    final opponents = max(1, activeCount - 1);

    // 1. Blind play decision when cards have not been seen.
    if (!self.hasSeenCards) {
      return _decideBlindAction(
        observation,
        profile,
        moodOffset: moodOffset,
        rng: rng,
      );
    }

    // 2. Seen hand decision: evaluate only [observation.myCards].
    final eval = TeenPattiHandEvaluator.evaluate(
      observation.myCards,
      variant: observation.variant,
      jokerCard: observation.jokerCard,
    );
    final percentile = handPercentile(
      eval,
      variant: observation.variant,
    );

    final stakeRatio =
        (observation.chaalAmount / max(1, observation.minStake * 2))
            .clamp(1.0, 16.0);
    final stakePressure =
        log(stakeRatio) / log(2.0); // 0 at base stake, 1 per 2x raise.

    final recentRaises = _countRecentRaises(observation.roundActionLog);
    final multiwayAdjustment =
        max(0, opponents - 1) * 0.03 * profile.opponentReadWeight;
    final potRatio = observation.potAmount / max(1, observation.chaalAmount);
    final potOddsRelief = (potRatio - 2.0).clamp(0.0, 4.0) * 0.025;

    final pressurePenalty =
        stakePressure * (0.095 - profile.betSizingBias * 0.055) +
            recentRaises * 0.025 * profile.opponentReadWeight;

    final effectiveThreshold = (profile.foldThreshold +
            multiwayAdjustment +
            pressurePenalty -
            potOddsRelief -
            moodOffset * 0.10 -
            (activeCount == 2 ? 0.04 : 0.0))
        .clamp(0.18, 0.84);

    // Mistake injection (human-like suboptimal slip).
    if (rng.nextDouble() < profile.mistakeRate) {
      return _suboptimalSeenAction(
        observation,
        percentile: percentile,
        rng: rng,
      );
    }

    final affordableChaal = self.chips >= observation.chaalAmount;
    if (!affordableChaal && percentile < 0.70) {
      return const AgentTurnDecision(action: PlayerTableAction.pack);
    }

    // 2-player endgame: decide Show vs value Chaal vs Pack.
    if (activeCount == 2 && observation.canShow) {
      if (percentile >= effectiveThreshold + 0.18) {
        if (observation.canRaiseStake &&
            rng.nextDouble() < profile.raiseAggression * 0.55) {
          return const AgentTurnDecision(
            action: PlayerTableAction.chaal,
            raiseStake: true,
          );
        }
        return const AgentTurnDecision(action: PlayerTableAction.show);
      }
      if (percentile >= effectiveThreshold - 0.06) {
        return const AgentTurnDecision(action: PlayerTableAction.show);
      }
      if (rng.nextDouble() < (profile.bluffRate + moodOffset * 0.08)) {
        return AgentTurnDecision(
          action: PlayerTableAction.chaal,
          raiseStake: observation.canRaiseStake &&
              rng.nextDouble() < profile.raiseAggression,
        );
      }
      return const AgentTurnDecision(action: PlayerTableAction.pack);
    }

    // 3+ players: check fold threshold, bluff frequency, Side Show, and Chaal.
    if (percentile < effectiveThreshold) {
      final canBluffHere = stakePressure <= 2.0 &&
          rng.nextDouble() < (profile.bluffRate + moodOffset * 0.08);
      if (!canBluffHere) {
        if (observation.canSideShow &&
            percentile >= effectiveThreshold - 0.12 &&
            rng.nextDouble() < profile.sideShowAppetite * 0.70) {
          return const AgentTurnDecision(action: PlayerTableAction.sideShow);
        }
        return const AgentTurnDecision(action: PlayerTableAction.pack);
      }
    }

    // Selective mid-game Side Show with solid hands.
    if (observation.canSideShow &&
        percentile >= effectiveThreshold &&
        percentile <= 0.88 &&
        rng.nextDouble() < profile.sideShowAppetite * 0.42) {
      return const AgentTurnDecision(action: PlayerTableAction.sideShow);
    }

    // Decide whether to 2x raise for value or balanced aggression.
    final raiseDrive =
        (profile.raiseAggression + moodOffset * 0.10).clamp(0.0, 0.90);
    final shouldRaise = observation.canRaiseStake &&
        ((percentile >= 0.74 && rng.nextDouble() < (0.28 + raiseDrive * 0.65)) ||
            (percentile >= effectiveThreshold + 0.10 &&
                rng.nextDouble() < raiseDrive * 0.45) ||
            (stakePressure < 1.5 &&
                rng.nextDouble() < profile.bluffRate * raiseDrive));

    return AgentTurnDecision(
      action: PlayerTableAction.chaal,
      raiseStake: shouldRaise,
    );
  }

  /// Decides whether to accept or decline a pending Side Show request.
  static bool decideSideShowResponse(
    SeatObservation observation,
    BotProfileParams profile, {
    double moodOffset = 0.0,
    Random? random,
  }) {
    final rng = random ?? Random();
    final self = observation.self;
    if (!self.hasSeenCards || observation.myCards.length != 3) {
      return rng.nextDouble() < profile.sideShowAppetite;
    }

    final eval = TeenPattiHandEvaluator.evaluate(
      observation.myCards,
      variant: observation.variant,
      jokerCard: observation.jokerCard,
    );
    final percentile = handPercentile(
      eval,
      variant: observation.variant,
    );

    if (percentile >= 0.74) return true;
    if (percentile <= 0.25) return false;

    final acceptChance = (profile.sideShowAppetite * 0.7 +
            (percentile - 0.45) * 0.8 +
            moodOffset * 0.10)
        .clamp(0.10, 0.92);
    return rng.nextDouble() < acceptChance;
  }

  /// Exact classic 3-card percentile over the 22,100 combinations, and smooth
  /// monotonic strength mapping for wild/lowball variants.
  static double handPercentile(
    EvaluatedHand eval, {
    TeenPattiVariant variant = TeenPattiVariant.classic,
  }) {
    if (variant == TeenPattiVariant.muflis ||
        variant != TeenPattiVariant.classic) {
      return eval.normalizedStrength.clamp(0.01, 0.99);
    }

    return switch (eval.category) {
      TeenPattiHandCategory.highCard => _lerpCategory(
          eval.normalizedStrength,
          minStrength: 0.04,
          maxStrength: 0.30,
          startP: 0.01,
          endP: 0.7439,
        ),
      TeenPattiHandCategory.pair => _lerpCategory(
          eval.normalizedStrength,
          minStrength: 0.33,
          maxStrength: 0.55,
          startP: 0.7439,
          endP: 0.9133,
        ),
      TeenPattiHandCategory.color => _lerpCategory(
          eval.normalizedStrength,
          minStrength: 0.58,
          maxStrength: 0.72,
          startP: 0.9133,
          endP: 0.9629,
        ),
      TeenPattiHandCategory.sequence => _lerpCategory(
          eval.normalizedStrength,
          minStrength: 0.75,
          maxStrength: 0.85,
          startP: 0.9629,
          endP: 0.9955,
        ),
      TeenPattiHandCategory.pureSequence => _lerpCategory(
          eval.normalizedStrength,
          minStrength: 0.87,
          maxStrength: 0.93,
          startP: 0.9955,
          endP: 0.9976,
        ),
      TeenPattiHandCategory.trail => _lerpCategory(
          eval.normalizedStrength,
          minStrength: 0.94,
          maxStrength: 1.00,
          startP: 0.9976,
          endP: 1.00,
        ),
    };
  }

  static AgentTurnDecision _decideBlindAction(
    SeatObservation observation,
    BotProfileParams profile, {
    required double moodOffset,
    required Random rng,
  }) {
    final self = observation.self;
    if (self.chips < observation.blindAmount) {
      return const AgentTurnDecision(action: PlayerTableAction.pack);
    }

    if (observation.canShow &&
        observation.turnCount >= 4 &&
        rng.nextDouble() < (0.35 + profile.sideShowAppetite * 0.25)) {
      return const AgentTurnDecision(action: PlayerTableAction.show);
    }

    final shouldRaise = observation.canRaiseStake &&
        rng.nextDouble() <
            ((profile.raiseAggression * 0.50 + moodOffset * 0.08)
                .clamp(0.02, 0.60));

    if (rng.nextDouble() < profile.mistakeRate * 0.35) {
      return const AgentTurnDecision(action: PlayerTableAction.pack);
    }

    return AgentTurnDecision(
      action: PlayerTableAction.blind,
      raiseStake: shouldRaise,
    );
  }

  static AgentTurnDecision _suboptimalSeenAction(
    SeatObservation observation, {
    required double percentile,
    required Random rng,
  }) {
    if (percentile < 0.75 && rng.nextDouble() < 0.45) {
      return const AgentTurnDecision(action: PlayerTableAction.pack);
    }
    if (observation.canShow && rng.nextDouble() < 0.5) {
      return const AgentTurnDecision(action: PlayerTableAction.show);
    }
    return const AgentTurnDecision(action: PlayerTableAction.chaal);
  }

  static int _countRecentRaises(List<String> roundActionLog) {
    var count = 0;
    for (final line in roundActionLog) {
      if (line.contains('2x')) {
        count++;
      }
    }
    return count;
  }

  static double _lerpCategory(
    double strength, {
    required double minStrength,
    required double maxStrength,
    required double startP,
    required double endP,
  }) {
    final t = ((strength - minStrength) / (maxStrength - minStrength))
        .clamp(0.0, 1.0);
    return startP + (endP - startP) * t;
  }
}
