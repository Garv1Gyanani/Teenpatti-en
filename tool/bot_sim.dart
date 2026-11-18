import 'dart:io';
import 'dart:math';

import 'package:teen_patti_core/teen_patti_core.dart';

class SimBotConfig {
  const SimBotConfig(this.id, this.name, this.params);

  final String id;
  final String name;
  final BotProfileParams params;
}

class _SeatStats {
  int hands = 0;
  int wins = 0;
  int actionsTaken = 0;
  int blindActions = 0;
  int raises = 0;
  int totalInvested = 0;
  int totalWon = 0;
  int totalPotVolume = 0;

  double get winRatePct => hands == 0 ? 0 : (wins / hands) * 100.0;
  double get blindPct =>
      actionsTaken == 0 ? 0 : (blindActions / actionsTaken) * 100.0;
  double get raisePct =>
      actionsTaken == 0 ? 0 : (raises / actionsTaken) * 100.0;
  int get netChips => totalWon - totalInvested;
  double get roiPct =>
      totalInvested == 0 ? 0 : (netChips / totalInvested) * 100.0;
  double get potEvPct =>
      totalPotVolume == 0 ? 0 : (netChips / totalPotVolume) * 100.0;
}

final List<SimBotConfig> onlineBotConfigs = [
  SimBotConfig('bot_1', 'Vikram S', BotProfileParams.cautious),
  SimBotConfig('bot_2', 'Priya M', BotProfileParams.balanced),
  SimBotConfig('bot_3', 'Dev Kapoor', BotProfileParams.tightAggressive),
  SimBotConfig('bot_4', 'Naina R', BotProfileParams.blindBluffer),
  SimBotConfig('bot_5', 'Arjun Verma', BotProfileParams.shark),
  SimBotConfig('bot_6', 'Tara Gill', BotProfileParams.loosePassive),
  SimBotConfig('bot_7', 'Siddharth K', BotProfileParams.opportunist),
  SimBotConfig('bot_8', 'Kavya Nair', BotProfileParams.chaotic),
  SimBotConfig(
    'bot_9',
    'Ishaan Roy',
    BotProfileParams.tightAggressive.copyWith(
      archetype: 'tight_aggressive_v2',
      blindPlayRate: 0.50,
      foldThreshold: 0.45,
      raiseAggression: 0.30,
    ),
  ),
  SimBotConfig(
    'bot_10',
    'Zoya Khan',
    BotProfileParams.balanced.copyWith(
      archetype: 'balanced_v2',
      blindPlayRate: 0.44,
      sideShowAppetite: 0.65,
      bluffRate: 0.16,
    ),
  ),
];

void main() {
  const totalHands = 100000;
  const minStake = 100;
  const maxStake = 3200;
  const startingStack = 50000;

  final rng = Random(20261115);
  final engine = TeenPattiEngine(random: rng);

  final statsById = <String, _SeatStats>{
    'human_baseline': _SeatStats(),
    for (final bot in onlineBotConfigs) bot.id: _SeatStats(),
  };

  for (var hand = 0; hand < totalHands; hand++) {
    // Rotate pairs of online bots against the human baseline in 3-handed tables
    // (benchmarking exact 3-player win rate target ~30-36% & ±3% EV).
    final firstIdx = hand % onlineBotConfigs.length;
    final secondIdx = (firstIdx + 1 + (hand ~/ onlineBotConfigs.length) % 9) %
        onlineBotConfigs.length;
    final botA = onlineBotConfigs[firstIdx];
    final botB = onlineBotConfigs[secondIdx];

    final lineup = <({String id, String name, BotProfileParams params})>[
      (
        id: 'human_baseline',
        name: 'HumanBaseline',
        params: BotProfileParams.humanBaseline,
      ),
      (id: botA.id, name: botA.name, params: botA.params),
      (id: botB.id, name: botB.name, params: botB.params),
    ];

    final paramsById = {for (final seat in lineup) seat.id: seat.params};
    final tablePlayers = [
      for (final seat in lineup)
        TablePlayer(
          id: seat.id,
          name: seat.name,
          chips: startingStack,
          avatarAsset: 'assets/images/online_avatar_1.png',
          participantKind: seat.id == 'human_baseline'
              ? ParticipantKind.human
              : ParticipantKind.onlineAgent,
        ),
    ];

    var state = engine.startNewRound(
      tableName: 'Sim Table',
      minStake: minStake,
      maxStake: maxStake,
      players: tablePlayers,
      roundNumber: hand + 1,
      dealerIndex: hand % lineup.length,
    );

    var safety = 0;
    while (!state.isRoundOver && safety < 200) {
      safety++;
      final pending = state.pendingSideShow;
      if (pending != null) {
        final targetObs = SeatObservation.fromTableState(
          state,
          viewerId: pending.targetId,
        );
        final accepted = BotDecisionEngine.decideSideShowResponse(
          targetObs,
          paramsById[pending.targetId]!,
          random: rng,
        );
        state = engine.resolveSideShow(state, accepted: accepted);
        continue;
      }

      final active = state.activeTurnPlayer;
      if (active == null) break;

      final seatStats = statsById[active.id]!;
      final profile = paramsById[active.id]!;

      if (!active.hasSeenCards) {
        final preObs = SeatObservation.fromTableState(
          state,
          viewerId: active.id,
        );
        if (BotDecisionEngine.shouldSeeCards(preObs, profile, random: rng)) {
          state = engine.seeCards(state, playerId: active.id);
        }
      }

      final actorAfterSee = state.findPlayerById(active.id)!;
      final obs = SeatObservation.fromTableState(state, viewerId: active.id);
      final decision = BotDecisionEngine.decideAction(
        obs,
        profile,
        random: rng,
      );

      seatStats.actionsTaken++;
      if (!actorAfterSee.hasSeenCards &&
          decision.action == PlayerTableAction.blind) {
        seatStats.blindActions++;
      }
      if (decision.raiseStake) {
        seatStats.raises++;
      }

      state = engine.applyAction(
        state,
        playerId: active.id,
        action: decision.action,
        raiseStake: decision.raiseStake,
      );

      if (state.pendingSideShow != null) {
        final p = state.pendingSideShow!;
        final targetObs = SeatObservation.fromTableState(
          state,
          viewerId: p.targetId,
        );
        final accepted = BotDecisionEngine.decideSideShowResponse(
          targetObs,
          paramsById[p.targetId]!,
          random: rng,
        );
        state = engine.resolveSideShow(state, accepted: accepted);
      }
    }

    final result = state.roundResult!;
    for (final p in state.players) {
      final st = statsById[p.id]!;
      st.hands++;
      st.totalInvested += p.totalBet;
      st.totalPotVolume += state.potAmount;
      if (p.id == result.winner.id) {
        st.wins++;
        st.totalWon += result.wonAmount;
      }
    }
  }

  stdout.writeln(
    '=== Teen Patti 100,000-Hand Headless Simulation (3-Handed Pots) ===',
  );
  stdout.writeln(
    'Seat             Hands    Win%    Blind%   Raise%     NetChips     PotEV%     ROI%',
  );

  void printRow(String label, _SeatStats s) {
    final winOk = s.winRatePct >= 29.5 && s.winRatePct <= 37.0 ? 'OK' : 'TUNE';
    final evOk = s.potEvPct.abs() <= 3.0 ? 'OK' : 'OUTLIER';
    stdout.writeln(
      '${label.padRight(16)} '
      '${s.hands.toString().padLeft(6)}  '
      '${s.winRatePct.toStringAsFixed(2).padLeft(5)}%  '
      '${s.blindPct.toStringAsFixed(1).padLeft(6)}%  '
      '${s.raisePct.toStringAsFixed(1).padLeft(6)}%  '
      '${s.netChips.toString().padLeft(11)}  '
      '${s.potEvPct.toStringAsFixed(2).padLeft(7)}%  '
      '${s.roiPct.toStringAsFixed(2).padLeft(6)}%  '
      '[$winOk/$evOk]',
    );
  }

  printRow('human_baseline', statsById['human_baseline']!);
  for (final bot in onlineBotConfigs) {
    printRow(bot.name, statsById[bot.id]!);
  }
}
