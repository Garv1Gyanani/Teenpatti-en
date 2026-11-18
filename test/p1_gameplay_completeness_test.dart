import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti/core/models/game_user.dart';
import 'package:teen_patti/core/router/app_routes.dart';
import 'package:teen_patti/core/session/app_session_store.dart';
import 'package:teen_patti/core/theme/app_theme.dart';
import 'package:teen_patti/features/game_table/data/repositories/game_table_repository_impl.dart';
import 'package:teen_patti/features/game_table/domain/entities/game_table_config.dart';
import 'package:teen_patti/features/game_table/domain/entities/playing_card.dart';
import 'package:teen_patti/features/game_table/domain/entities/table_player.dart';
import 'package:teen_patti/features/game_table/domain/entities/table_state.dart';
import 'package:teen_patti/features/game_table/domain/services/teen_patti_engine.dart';
import 'package:teen_patti/features/game_table/domain/services/teen_patti_hand_evaluator.dart';
import 'package:teen_patti/features/game_table/presentation/controllers/game_table_controller.dart';
import 'package:teen_patti/features/game_table/presentation/pages/game_table_page.dart';
import 'package:teen_patti/features/home/data/repositories/home_repository_impl.dart';
import 'package:teen_patti/features/home/domain/usecases/claim_daily_reward_usecase.dart';
import 'package:teen_patti/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:teen_patti/features/home/presentation/controllers/home_controller.dart';
import 'package:teen_patti/features/home/presentation/pages/home_page.dart';

PlayingCard _card(String rank, CardSuit suit) =>
    PlayingCard(rank: rank, suit: suit);

List<TablePlayer> _twoPlayers() => const [
      TablePlayer(
        id: 'local',
        name: 'Garv',
        chips: 10000,
        avatarAsset: 'assets/images/splash_character.png',
        participantKind: ParticipantKind.human,
        isLocalPlayer: true,
      ),
      TablePlayer(
        id: 'bot_1',
        name: 'Rohit',
        chips: 10000,
        avatarAsset: 'assets/images/avatar_2.png',
        participantKind: ParticipantKind.clientBot,
        personaTag: 'balanced',
      ),
    ];

void main() {
  tearDown(() {
    AppSessionStore.setInstance(AppSessionStore());
  });

  test(
      'TeenPattiHandEvaluator supports Muflis (Lowball), AK47, and Joker variants accurately',
      () {
    // 1. Muflis (Lowball): 5-3-2 off-suit is unbeatable #1; Trail Aces is worst.
    final lowest532 = [
      _card('5', CardSuit.spades),
      _card('3', CardSuit.hearts),
      _card('2', CardSuit.clubs),
    ];
    final low642 = [
      _card('6', CardSuit.spades),
      _card('4', CardSuit.hearts),
      _card('2', CardSuit.clubs),
    ];
    final pairTwos = [
      _card('2', CardSuit.spades),
      _card('2', CardSuit.hearts),
      _card('3', CardSuit.clubs),
    ];
    final suited532 = [
      _card('5', CardSuit.hearts),
      _card('3', CardSuit.hearts),
      _card('2', CardSuit.hearts),
    ];
    final trailAces = [
      _card('A', CardSuit.spades),
      _card('A', CardSuit.hearts),
      _card('A', CardSuit.clubs),
    ];

    expect(
      TeenPattiHandEvaluator.compare(
        lowest532,
        low642,
        variant: TeenPattiVariant.muflis,
      ),
      greaterThan(0),
    );
    expect(
      TeenPattiHandEvaluator.compare(
        low642,
        pairTwos,
        variant: TeenPattiVariant.muflis,
      ),
      greaterThan(0),
    );
    expect(
      TeenPattiHandEvaluator.compare(
        pairTwos,
        suited532,
        variant: TeenPattiVariant.muflis,
      ),
      greaterThan(0),
    );
    expect(
      TeenPattiHandEvaluator.compare(
        suited532,
        trailAces,
        variant: TeenPattiVariant.muflis,
      ),
      greaterThan(0),
    );

    // Exact ties in Muflis still return 0.
    final lowest532Alt = [
      _card('5', CardSuit.diamonds),
      _card('3', CardSuit.clubs),
      _card('2', CardSuit.spades),
    ];
    expect(
      TeenPattiHandEvaluator.compare(
        lowest532,
        lowest532Alt,
        variant: TeenPattiVariant.muflis,
      ),
      0,
    );

    final muflisBestEval = TeenPattiHandEvaluator.evaluate(
      lowest532,
      variant: TeenPattiVariant.muflis,
    );
    final muflisWorstEval = TeenPattiHandEvaluator.evaluate(
      trailAces,
      variant: TeenPattiVariant.muflis,
    );
    expect(
      muflisBestEval.normalizedStrength,
      greaterThan(muflisWorstEval.normalizedStrength),
    );

    // 2. AK47: A, K, 4, 7 are Wild Jokers.
    final ak47TrailNines = TeenPattiHandEvaluator.evaluate(
      [
        _card('4', CardSuit.spades),
        _card('9', CardSuit.hearts),
        _card('9', CardSuit.clubs),
      ],
      variant: TeenPattiVariant.ak47,
    );
    expect(ak47TrailNines.category, TeenPattiHandCategory.trail);
    expect(ak47TrailNines.label, contains('Trail'));
    expect(ak47TrailNines.label, contains('(Wild)'));

    final ak47PureSeq = TeenPattiHandEvaluator.evaluate(
      [
        _card('7', CardSuit.diamonds),
        _card('Q', CardSuit.spades),
        _card('J', CardSuit.spades),
      ],
      variant: TeenPattiVariant.ak47,
    );
    expect(ak47PureSeq.category, TeenPattiHandCategory.pureSequence);

    final ak47AllWild = TeenPattiHandEvaluator.evaluate(
      [
        _card('A', CardSuit.spades),
        _card('K', CardSuit.hearts),
        _card('4', CardSuit.clubs),
      ],
      variant: TeenPattiVariant.ak47,
    );
    expect(ak47AllWild.category, TeenPattiHandCategory.trail);
    expect(ak47AllWild.tieBreakers.first, 14); // Trail of Aces

    // 3. Joker: Matching rank of drawn jokerCard acts as Wild.
    final drawnJoker = _card('6', CardSuit.diamonds);
    final jokerPureAKQ = TeenPattiHandEvaluator.evaluate(
      [
        _card('6', CardSuit.spades),
        _card('A', CardSuit.hearts),
        _card('K', CardSuit.hearts),
      ],
      variant: TeenPattiVariant.joker,
      jokerCard: drawnJoker,
    );
    expect(jokerPureAKQ.category, TeenPattiHandCategory.pureSequence);
    expect(jokerPureAKQ.label, contains('(Wild)'));

    // Engine deals unique jokerCard in Joker mode and runs bots across variants.
    final engine = TeenPattiEngine(random: Random(21));
    final jokerRound = engine.startNewRound(
      tableName: 'Joker Lounge',
      minStake: 100,
      maxStake: 3200,
      players: _twoPlayers(),
      roundNumber: 1,
      dealerIndex: 1,
      variant: TeenPattiVariant.joker,
    );
    expect(jokerRound.jokerCard, isNotNull);
    final playerCards = jokerRound.players.expand((p) => p.cards).toSet();
    expect(playerCards.contains(jokerRound.jokerCard), isFalse);
  });

  test(
      'TeenPattiEngine enforces 4-blind-turn cap and auto-transitions player to Seen on 5th turn',
      () {
    final engine = TeenPattiEngine(random: Random(12));
    var state = engine.startNewRound(
      tableName: 'Classic',
      minStake: 100,
      maxStake: 6400,
      players: _twoPlayers(),
      roundNumber: 1,
      dealerIndex: 1, // local acts first
      maxBlindTurns: 4,
    );

    for (var turn = 1; turn <= 4; turn++) {
      expect(state.activeTurnPlayer?.id, 'local');
      expect(state.localPlayer.hasSeenCards, isFalse);
      expect(engine.canBlind(state, 'local'), isTrue);

      state = engine.applyAction(
        state,
        playerId: 'local',
        action: PlayerTableAction.blind,
      );
      expect(state.localPlayer.blindTurnsTaken, turn);

      // Bot matches blind to pass turn back to local.
      state = engine.applyAction(
        state,
        playerId: 'bot_1',
        action: state.findPlayerById('bot_1')!.hasSeenCards
            ? PlayerTableAction.chaal
            : PlayerTableAction.blind,
      );
    }

    // On local's 5th turn, cards are auto-revealed because 4 blind turns were used!
    expect(state.activeTurnPlayer?.id, 'local');
    expect(state.localPlayer.blindTurnsTaken, 4);
    expect(state.localPlayer.hasSeenCards, isTrue);
    expect(engine.canBlind(state, 'local'), isFalse);
    expect(engine.canChaal(state, 'local'), isTrue);
  });

  testWidgets(
      '2x Stake Raise toggle doubles Blind and Chaal stakes cleanly on GameTablePage',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = GameTableRepositoryImpl(
      random: Random(15),
      initialUsers: const [
        GameUser(
          id: 'local',
          name: 'Garv',
          chips: 25000,
          avatarAsset: 'assets/images/splash_character.png',
          kind: ParticipantKind.human,
        ),
        GameUser(
          id: 'bot_1',
          name: 'Rohit',
          chips: 25000,
          avatarAsset: 'assets/images/avatar_2.png',
          kind: ParticipantKind.clientBot,
        ),
        GameUser(
          id: 'bot_2',
          name: 'Sneha',
          chips: 25000,
          avatarAsset: 'assets/images/avatar_3.png',
          kind: ParticipantKind.clientBot,
        ),
      ],
      initialDealerIndex: 2, // local goes first
    );
    final controller = GameTableController.forRepository(
      repository: repo,
      botTurnDelay: const Duration(milliseconds: 400),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GameTablePage(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Blind 0/4'), findsOneWidget);
    expect(find.text('2x Stake'), findsOneWidget);
    expect(controller.effectiveBlindAmount, 100);

    // Toggle 2x Stake ON -> previews Blind 2x (₹200).
    await tester.tap(find.byKey(const Key('raise_2x_toggle')));
    await tester.pump();

    expect(find.text('2x Stake ON'), findsOneWidget);
    expect(find.text('Blind 2x'), findsOneWidget);
    expect(controller.effectiveBlindAmount, 200);
    expect(tester.takeException(), isNull);

    // Execute Blind 2x -> stake doubles from ₹100 to ₹200 and toggle resets!
    await tester.tap(find.text('Blind 2x'));
    await tester.pump();

    expect(controller.state!.blindAmount, 200);
    expect(controller.state!.chaalAmount, 400);
    expect(controller.state!.localPlayer.blindTurnsTaken, 1);
    expect(controller.isRaiseSelected, isFalse);
  });

  testWidgets(
      'Turn timer pauses while sheet is open and auto-packs local player when time expires',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = GameTableRepositoryImpl(random: Random(8));
    final controller = GameTableController.forRepository(
      repository: repo,
      botTurnDelay: const Duration(milliseconds: 100),
      turnTimeout: const Duration(seconds: 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GameTablePage(controller: controller),
      ),
    );
    await tester.pump();
    expect(controller.state!.isLocalPlayersTurn, isTrue);

    // Open Chat sheet -> timer pauses, so 4s elapsed does NOT auto-pack!
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Table Chat & Reactions'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(controller.state!.localPlayer.hasPacked, isFalse);

    // Close Chat sheet -> timer resumes and auto-packs after 3s!
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(controller.state!.localPlayer.hasPacked, isTrue);
    expect(find.text('Deal New Hand'), findsOneWidget);
  });

  testWidgets(
      'Low-chip bailout credits relief chips, records Hand History, sends Chat & Seat Reactions, and launches Variants from Home',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = AppSessionStore();
    await store.hydrate();
    // Simulate a player entering with only ₹40 chips (< ₹100 boot).
    await store.recordCompletedRound(
      tableName: 'High Roller',
      variant: 'Classic',
      bootAmount: 100,
      roundNumber: 1,
      previousBalance: 25000,
      newBalance: 40,
      potAmount: 50000,
      localTotalBet: 24960,
      isLocalWinner: false,
      handLabel: 'Packed',
      winReason: 'Folded',
    );
    AppSessionStore.setInstance(store);
    expect(store.chips, 40);

    final repo = GameTableRepositoryImpl(
      random: Random(33),
      sessionStore: store,
      config: const GameTableConfig(
        tableName: 'Emerald Club',
        minStake: 100,
        maxStake: 3200,
        maxPlayers: 4,
      ),
    );
    final controller = GameTableController.forRepository(
      repository: repo,
      sessionStore: store,
      botTurnDelay: const Duration(milliseconds: 100),
      turnTimeout: const Duration(seconds: 15),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: GameTablePage(controller: controller),
      ),
    );
    await tester.pump();

    // 1. Low-Chip Bailout Dialog blocks entry and offers Free Relief.
    expect(find.text('Low Chip Stack'), findsOneWidget);
    expect(find.textContaining('Claim Free Relief'), findsOneWidget);

    await tester.tap(find.textContaining('Claim Free Relief'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Low Chip Stack'), findsNothing);
    expect(controller.state, isNotNull);
    expect(
      store.transactions.any((t) => t.title == 'Club Relief Chips'),
      isTrue,
    );

    // 2.Table Chat & Floating Seat Reaction Bubble.
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Good game everyone!');
    await tester.tap(find.text('Send'));
    await tester.pump();
    // Appears in both the live chat feed and the floating seat bubble!
    expect(find.text('Good game everyone!'), findsNWidgets(2));

    // Tap quick emoji -> closes sheet and floats reaction bubble above seat.
    await tester.tap(find.text('🔥'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('🔥'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let reaction bubble expire cleanly.
    await tester.pump(const Duration(seconds: 3));

    // 3. Complete round and inspect In-Table Hand History sheet.
    await tester.tap(find.text('Pack'));
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      if (find.text('Play Again').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Play Again'), findsOneWidget);
    await tester.tap(find.text('Play Again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.handHistory.length, 1);
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Table Hand History'), findsOneWidget);
    expect(find.textContaining('Round #1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 4. Home Variant Picker launches Joker Lounge with active Wild Joker card.
    final homeRepo = HomeRepositoryImpl(sessionStore: store);
    final homeController = HomeController(
      getDashboardUseCase: GetHomeDashboardUseCase(repository: homeRepo),
      claimDailyRewardUseCase: ClaimDailyRewardUseCase(repository: homeRepo),
      sessionListenable: store,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: HomePage(controller: homeController, sessionStore: store),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Variants'));
    await tester.tap(find.text('Variants'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Teen Patti Variant'), findsOneWidget);
    expect(find.text('Muflis (Lowball)'), findsOneWidget);
    expect(find.text('AK47 (4 Wild Ranks)'), findsOneWidget);
    expect(find.text('Joker (Random Wild)'), findsOneWidget);

    await tester.tap(find.text('Joker (Random Wild)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Joker Lounge'), findsOneWidget);
    expect(find.textContaining('Wild Joker:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
