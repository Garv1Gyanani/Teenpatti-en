import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti/core/models/game_user.dart';
import 'package:teen_patti/core/theme/app_theme.dart';
import 'package:teen_patti/features/game_table/data/repositories/game_table_repository_impl.dart';
import 'package:teen_patti/features/game_table/domain/entities/playing_card.dart';
import 'package:teen_patti/features/game_table/domain/entities/round_result.dart';
import 'package:teen_patti/features/game_table/domain/entities/table_player.dart';
import 'package:teen_patti/features/game_table/domain/entities/table_state.dart';
import 'package:teen_patti/features/game_table/domain/services/table_player_agent.dart';
import 'package:teen_patti/features/game_table/domain/services/teen_patti_engine.dart';
import 'package:teen_patti/features/game_table/domain/services/teen_patti_hand_evaluator.dart';
import 'package:teen_patti/features/game_table/presentation/controllers/game_table_controller.dart';
import 'package:teen_patti/features/game_table/presentation/pages/game_table_page.dart';
import 'package:teen_patti/features/game_table/presentation/widgets/round_result_dialog.dart';

PlayingCard _card(String rank, CardSuit suit) =>
    PlayingCard(rank: rank, suit: suit);

List<TablePlayer> _threePlayers() => const [
      TablePlayer(
        id: 'local',
        name: 'Garv',
        chips: 5000,
        avatarAsset: 'assets/images/splash_character.png',
        participantKind: ParticipantKind.human,
        isLocalPlayer: true,
      ),
      TablePlayer(
        id: 'bot_1',
        name: 'Rohit',
        chips: 5000,
        avatarAsset: 'assets/images/avatar_2.png',
        participantKind: ParticipantKind.clientBot,
        personaTag: 'balanced',
      ),
      TablePlayer(
        id: 'agent_2',
        name: 'NovaAI',
        chips: 5000,
        avatarAsset: 'assets/images/avatar_3.png',
        participantKind: ParticipantKind.onlineAgent,
        personaTag: 'online_v1',
      ),
    ];

class _StubOnlineAgent implements TablePlayerAgent {
  @override
  Future<bool> shouldSeeCards({
    required TableState state,
    required TablePlayer self,
  }) async =>
      true;

  @override
  Future<AgentTurnDecision> decideAction({
    required TableState state,
    required TablePlayer self,
  }) async {
    if (state.activePlayers.length == 2) {
      return const AgentTurnDecision(action: PlayerTableAction.show);
    }
    return const AgentTurnDecision(action: PlayerTableAction.chaal);
  }

  @override
  Future<bool> decideSideShowResponse({
    required TableState state,
    required TablePlayer self,
    required TablePlayer requester,
  }) async =>
      true;
}

void main() {
  test('GameUser adapts seamlessly across human, clientBot, and onlineAgent',
      () {
    const human = GameUser(
      id: 'u1',
      name: 'Garv',
      chips: 12000,
      avatarAsset: 'assets/images/splash_character.png',
      kind: ParticipantKind.human,
      rating: 1450,
    );
    const bot = GameUser(
      id: 'b1',
      name: 'Rohit',
      chips: 9000,
      avatarAsset: 'assets/images/avatar_2.png',
      kind: ParticipantKind.clientBot,
      personaTag: 'aggressive',
    );
    const onlineAi = GameUser(
      id: 'oa1',
      name: 'AriaAI',
      chips: 15000,
      avatarAsset: 'assets/images/avatar_4.png',
      kind: ParticipantKind.onlineAgent,
      personaTag: 'pro_agent',
      rating: 1820,
    );

    final humanSeat = TablePlayer.fromUser(human, isLocalPlayer: true);
    final botSeat = TablePlayer.fromUser(bot);
    final agentSeat = TablePlayer.fromUser(onlineAi);

    expect(humanSeat.isAutomated, isFalse);
    expect(botSeat.isClientBot, isTrue);
    expect(botSeat.isAutomated, isTrue);
    expect(agentSeat.isOnlineAgent, isTrue);
    expect(agentSeat.isAutomated, isTrue);
    expect(agentSeat.toUser().kind, ParticipantKind.onlineAgent);
    expect(agentSeat.toUser().rating, 1820);
    expect(agentSeat.toUser().personaTag, 'pro_agent');
  });

  test('TeenPattiHandEvaluator enforces exact Teen Patti hand hierarchy', () {
    final trailAces = [
      _card('A', CardSuit.spades),
      _card('A', CardSuit.hearts),
      _card('A', CardSuit.clubs),
    ];
    final pureAKQ = [
      _card('A', CardSuit.spades),
      _card('K', CardSuit.spades),
      _card('Q', CardSuit.spades),
    ];
    final pureA23 = [
      _card('A', CardSuit.hearts),
      _card('2', CardSuit.hearts),
      _card('3', CardSuit.hearts),
    ];
    final pureKQJ = [
      _card('K', CardSuit.diamonds),
      _card('Q', CardSuit.diamonds),
      _card('J', CardSuit.diamonds),
    ];
    final seqAKQ = [
      _card('A', CardSuit.spades),
      _card('K', CardSuit.hearts),
      _card('Q', CardSuit.clubs),
    ];
    final seqA23 = [
      _card('A', CardSuit.spades),
      _card('3', CardSuit.hearts),
      _card('2', CardSuit.clubs),
    ];
    final seq432 = [
      _card('4', CardSuit.spades),
      _card('3', CardSuit.hearts),
      _card('2', CardSuit.clubs),
    ];
    final colorAK9 = [
      _card('A', CardSuit.clubs),
      _card('K', CardSuit.clubs),
      _card('9', CardSuit.clubs),
    ];
    final pairKings = [
      _card('K', CardSuit.spades),
      _card('K', CardSuit.diamonds),
      _card('4', CardSuit.clubs),
    ];
    final ka2Mixed = [
      _card('K', CardSuit.spades),
      _card('A', CardSuit.hearts),
      _card('2', CardSuit.clubs),
    ];

    final ordered = [
      ka2Mixed,
      pairKings,
      colorAK9,
      seq432,
      seqA23,
      seqAKQ,
      pureKQJ,
      pureA23,
      pureAKQ,
      trailAces,
    ];

    for (var i = 0; i < ordered.length - 1; i++) {
      expect(
        TeenPattiHandEvaluator.compare(ordered[i + 1], ordered[i]),
        greaterThan(0),
        reason: '${ordered[i + 1]} should beat ${ordered[i]}',
      );
    }

    // K-A-2 is NOT a valid sequence in Teen Patti.
    expect(
      TeenPattiHandEvaluator.evaluate(ka2Mixed).category,
      TeenPattiHandCategory.highCard,
    );

    // Identical ranks of different off-suit combinations tie cleanly.
    final pairKingsB = [
      _card('K', CardSuit.hearts),
      _card('K', CardSuit.clubs),
      _card('4', CardSuit.diamonds),
    ];
    expect(TeenPattiHandEvaluator.compare(pairKings, pairKingsB), 0);
  });

  test('TeenPattiEngine deals unique cards, validates Side Show, Show, and Pack win',
      () {
    final engine = TeenPattiEngine(random: Random(7));
    var state = engine.startNewRound(
      tableName: 'Classic',
      minStake: 100,
      maxStake: 3200,
      players: _threePlayers(),
      roundNumber: 1,
      dealerIndex: 2, // local goes first
    );

    // 52 unique cards in deck; 9 dealt uniquely across 3 seats.
    expect(PlayingCard.standardDeck().toSet().length, 52);
    final dealtCards = state.players.expand((p) => p.cards).toSet();
    expect(dealtCards.length, 9);
    expect(state.potAmount, 300);
    expect(state.activeTurnPlayer?.id, 'local');

    // Blind vs Seen & Side Show guard before previous player is seen.
    expect(engine.canBlind(state, 'local'), isTrue);
    expect(engine.canChaal(state, 'local'), isFalse);
    expect(engine.canShow(state, 'local'), isFalse); // 3 active players
    expect(engine.canSideShow(state, 'local'), isFalse);

    // Blind bet from local, then bot_1 sees & chaals, then agent_2 packs ->
    // 2 players remain so Show becomes legal!
    state = engine.applyAction(
      state,
      playerId: 'local',
      action: PlayerTableAction.blind,
    );
    expect(state.potAmount, 400);
    expect(state.activeTurnPlayer?.id, 'bot_1');

    state = engine.seeCards(state, playerId: 'bot_1');
    state = engine.applyAction(
      state,
      playerId: 'bot_1',
      action: PlayerTableAction.chaal,
    );
    expect(state.potAmount, 600);
    expect(state.activeTurnPlayer?.id, 'agent_2');

    // Pack agent_2 -> leaves local & bot_1 (2 active players).
    state = engine.applyAction(
      state,
      playerId: 'agent_2',
      action: PlayerTableAction.pack,
    );
    expect(state.activePlayers.length, 2);
    expect(engine.canShow(state, 'local'), isTrue);

    // Pack bot_1 next if local chaals -> auto wins pot!
    state = engine.seeCards(state, playerId: 'local');
    state = engine.applyAction(
      state,
      playerId: 'local',
      action: PlayerTableAction.chaal,
    );
    state = engine.applyAction(
      state,
      playerId: 'bot_1',
      action: PlayerTableAction.pack,
    );

    expect(state.isRoundOver, isTrue);
    expect(state.roundResult?.winner.id, 'local');
    expect(state.roundResult?.wonAmount, 800);
  });

  test('Side Show compares two seen players and packs loser when accepted', () {
    final engine = TeenPattiEngine(random: Random(1));
    final initial = engine.startNewRound(
      tableName: 'Classic',
      minStake: 100,
      maxStake: 3200,
      players: _threePlayers(),
      roundNumber: 1,
      dealerIndex: 2,
    );

    // Override hands deterministically to verify Side Show outcome.
    final customPlayers = [
      initial.players[0].copyWith(
        hasSeenCards: true,
        cards: [
          _card('A', CardSuit.spades),
          _card('A', CardSuit.hearts),
          _card('A', CardSuit.clubs),
        ],
      ),
      initial.players[1].copyWith(
        hasSeenCards: true,
        isActiveTurn: false,
        cards: [
          _card('K', CardSuit.spades),
          _card('K', CardSuit.hearts),
          _card('9', CardSuit.clubs),
        ],
      ),
      initial.players[2].copyWith(
        hasSeenCards: true,
        isActiveTurn: false,
        cards: [
          _card('2', CardSuit.spades),
          _card('7', CardSuit.hearts),
          _card('9', CardSuit.diamonds),
        ],
      ),
    ];

    final state = initial.copyWith(players: customPlayers);
    // local's previous active player is agent_2, who is seen.
    expect(engine.canSideShow(state, 'local'), isTrue);

    final pending = engine.applyAction(
      state,
      playerId: 'local',
      action: PlayerTableAction.sideShow,
    );
    expect(pending.pendingSideShow, isNotNull);
    expect(pending.pendingSideShow!.targetId, 'agent_2');

    final resolved = engine.resolveSideShow(pending, accepted: true);
    expect(resolved.pendingSideShow, isNull);
    expect(resolved.findPlayerById('agent_2')?.hasPacked, isTrue);
    expect(resolved.findPlayerById('local')?.hasPacked, isFalse);
  });

  test('Offline bots and future onlineAgent complete full rounds deterministically',
      () async {
    final users = const [
      GameUser(
        id: 'local',
        name: 'Garv',
        chips: 20000,
        avatarAsset: 'assets/images/splash_character.png',
        kind: ParticipantKind.human,
      ),
      GameUser(
        id: 'bot_rohit',
        name: 'Rohit',
        chips: 20000,
        avatarAsset: 'assets/images/avatar_2.png',
        kind: ParticipantKind.clientBot,
        personaTag: 'aggressive',
      ),
      GameUser(
        id: 'online_aria',
        name: 'Aria',
        chips: 20000,
        avatarAsset: 'assets/images/avatar_3.png',
        kind: ParticipantKind.onlineAgent,
        personaTag: 'online_v1',
      ),
      GameUser(
        id: 'bot_meera',
        name: 'Meera',
        chips: 20000,
        avatarAsset: 'assets/images/avatar_5.png',
        kind: ParticipantKind.clientBot,
        personaTag: 'tight',
      ),
    ];

    final repo = GameTableRepositoryImpl(
      random: Random(99),
      initialUsers: users,
      initialDealerIndex: 3,
      agentsByPlayerId: {'online_aria': _StubOnlineAgent()},
    );

    final controller = GameTableController.forRepository(
      repository: repo,
      botTurnDelay: Duration.zero,
    );

    await controller.loadTable();
    expect(controller.state!.players.length, 4);

    // Play 3 consecutive rounds rotating dealer cleanly.
    for (var round = 1; round <= 3; round++) {
      expect(controller.state!.roundNumber, round);

      // If AI didn't open directly, step local turns until round ends.
      var guard = 0;
      while (!controller.state!.isRoundOver && guard < 25) {
        guard++;
        final s = controller.state!;
        if (s.pendingSideShow != null &&
            s.pendingSideShow!.targetId == s.localPlayer.id) {
          await controller.respondToSideShow(accepted: true);
          continue;
        }
        if (s.isLocalPlayersTurn) {
          if (!s.localPlayer.hasSeenCards) {
            await controller.seeCards();
          }
          if (controller.canLocalShow && guard > 2) {
            await controller.performAction(PlayerTableAction.show);
          } else {
            await controller.performAction(PlayerTableAction.chaal);
          }
        }
      }

      expect(controller.state!.isRoundOver, isTrue);
      expect(controller.state!.roundResult, isNotNull);

      if (round < 3) {
        await controller.dealNewHand();
      }
    }

    controller.dispose();
  });

  for (final size in [const Size(360, 800), const Size(390, 844)]) {
    testWidgets('GameTablePage renders cleanly without overflow at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = GameTableRepositoryImpl(random: Random(11));
      final controller = GameTableController.forRepository(
        repository: repo,
        botTurnDelay: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GameTablePage(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'state=${controller.state} isLoading=${controller.isLoading}',
      );
      expect(
        controller.state,
        isNotNull,
        reason: 'isLoading=${controller.isLoading}',
      );
      expect(find.text('See Cards'), findsOneWidget);
      expect(find.text('Pack'), findsOneWidget);
      expect(tester.getSize(find.text('Pack')).width, greaterThan(20));

      await tester.tap(find.text('See Cards'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('See Cards'), findsNothing);
    });
  }

  testWidgets('RoundResultDialog renders AI winner and showdown hands at 360x800',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final aiWinner = TablePlayer(
      id: 'bot_rohit',
      name: 'Rohit',
      chips: 22000,
      avatarAsset: 'assets/images/avatar_2.png',
      participantKind: ParticipantKind.clientBot,
      cards: [
        _card('A', CardSuit.spades),
        _card('K', CardSuit.spades),
        _card('Q', CardSuit.spades),
      ],
    );
    final localRunnerUp = TablePlayer(
      id: 'local',
      name: 'Garv',
      chips: 23800,
      avatarAsset: 'assets/images/splash_character.png',
      participantKind: ParticipantKind.human,
      isLocalPlayer: true,
      cards: [
        _card('K', CardSuit.hearts),
        _card('K', CardSuit.diamonds),
        _card('9', CardSuit.clubs),
      ],
    );

    final result = RoundResult(
      wonAmount: 3600,
      previousBalance: 25000,
      newBalance: 23800,
      handLabel: 'Pure Sequence (A-K-Q)',
      winner: aiWinner,
      packedOpponents: _threePlayers().sublist(1),
      showdownHands: [
        ShowdownHandSummary(
          player: aiWinner,
          handLabel: 'Pure Sequence (A-K-Q)',
          isWinner: true,
        ),
        ShowdownHandSummary(
          player: localRunnerUp,
          handLabel: 'Pair (Kings)',
          isWinner: false,
        ),
      ],
      winReason: 'Won by Showdown',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RoundResultDialog(
            result: result,
            onBackToLobby: () {},
            onPlayAgain: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Rohit Won'), findsOneWidget);
    expect(find.text('Pure Sequence (A-K-Q)'), findsOneWidget);
    expect(find.text('Pair (Kings)'), findsOneWidget);
    expect(find.text('Play Again'), findsOneWidget);
  });
}
