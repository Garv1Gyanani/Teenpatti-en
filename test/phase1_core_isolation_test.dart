import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teen_patti/core/session/app_session_store.dart';
import 'package:teen_patti/core/session/supabase_sync_client.dart';
import 'package:teen_patti/features/game_table/data/repositories/game_table_repository_impl.dart';
import 'package:teen_patti/features/game_table/domain/entities/game_table_config.dart';
import 'package:teen_patti_core/teen_patti_core.dart';

void main() {
  test('SeatObservation masks blind self cards and all opponent hole cards', () {
    final engine = TeenPattiEngine(random: Random(7));
    final seats = const [
      TablePlayer(
        id: 'p1',
        name: 'Alice',
        chips: 10000,
        avatarAsset: 'assets/images/splash_character.png',
        participantKind: ParticipantKind.human,
        isLocalPlayer: true,
      ),
      TablePlayer(
        id: 'p2',
        name: 'Bob',
        chips: 10000,
        avatarAsset: 'assets/images/online_avatar_1.png',
        participantKind: ParticipantKind.onlineAgent,
      ),
      TablePlayer(
        id: 'p3',
        name: 'Charlie',
        chips: 10000,
        avatarAsset: 'assets/images/online_avatar_2.png',
        participantKind: ParticipantKind.human,
      ),
    ];

    var state = engine.startNewRound(
      tableName: 'Mask Test',
      minStake: 100,
      maxStake: 3200,
      players: seats,
      roundNumber: 1,
      dealerIndex: 2,
    );

    expect(state.turnDeadline, isNotNull);
    expect(state.turnDeadline!.isUtc, isTrue);

    // Blind seat sees empty myCards and empty opponent revealedCards.
    final blindObs = SeatObservation.fromTableState(state, viewerId: 'p1');
    expect(blindObs.myCards, isEmpty);
    for (final seat in blindObs.seats) {
      expect(seat.revealedCards, isEmpty);
    }

    // After seeing cards, only viewer's own cards become visible to viewer.
    state = engine.seeCards(state, playerId: 'p1');
    final seenObs = SeatObservation.fromTableState(state, viewerId: 'p1');
    expect(seenObs.myCards.length, 3);
    final p2Obs = SeatObservation.fromTableState(state, viewerId: 'p2');
    expect(p2Obs.myCards, isEmpty);

    // Public JSON payload never leaks myCards.
    final publicJson = seenObs.toPublicJson();
    expect(publicJson.containsKey('myCards'), isFalse);
    final jsonSeats = publicJson['seats'] as List<dynamic>;
    for (final s in jsonSeats) {
      expect((s as Map<String, dynamic>).containsKey('participantKind'), isFalse);
      expect(s.containsKey('revealedCards'), isFalse);
    }
  });

  test('TeenPattiEngine works without any isLocalPlayer flag (server-safe)', () {
    final engine = TeenPattiEngine();
    final state = engine.startNewRound(
      tableName: 'Server Room',
      minStake: 100,
      maxStake: 3200,
      players: const [
        TablePlayer(
          id: 's1',
          name: 'UserOne',
          chips: 5000,
          avatarAsset: 'assets/images/online_avatar_1.png',
          participantKind: ParticipantKind.human,
        ),
        TablePlayer(
          id: 's2',
          name: 'BotTwo',
          chips: 5000,
          avatarAsset: 'assets/images/online_avatar_2.png',
          participantKind: ParticipantKind.onlineAgent,
        ),
      ],
      roundNumber: 1,
      dealerIndex: 0,
    );

    expect(state.localPlayerOrNull, isNull);
    expect(state.turnDeadline, isNotNull);

    final next = engine.applyAction(
      state,
      playerId: state.activeTurnPlayer!.id,
      action: PlayerTableAction.pack,
    );
    expect(next.isRoundOver, isTrue);
    expect(next.turnDeadline, isNull);
    expect(next.roundResult, isNotNull);
  });

  test('BotDecisionEngine respects blindPlayRate and foldThreshold parameters',
      () {
    var blindBlufferStayedBlind = 0;
    var cautiousStayedBlind = 0;
    final engine = TeenPattiEngine(random: Random(99));

    for (var i = 0; i < 100; i++) {
      final state = engine.startNewRound(
        tableName: 'Param Test',
        minStake: 100,
        maxStake: 3200,
        players: const [
          TablePlayer(
            id: 'b1',
            name: 'BlindBot',
            chips: 10000,
            avatarAsset: 'assets/images/online_avatar_4.png',
            participantKind: ParticipantKind.onlineAgent,
          ),
          TablePlayer(
            id: 'b2',
            name: 'CautiousBot',
            chips: 10000,
            avatarAsset: 'assets/images/online_avatar_1.png',
            participantKind: ParticipantKind.onlineAgent,
          ),
          TablePlayer(
            id: 'h1',
            name: 'Human',
            chips: 10000,
            avatarAsset: 'assets/images/splash_character.png',
            participantKind: ParticipantKind.human,
          ),
        ],
        roundNumber: i + 1,
        dealerIndex: 0,
      );

      final obs1 = SeatObservation.fromTableState(state, viewerId: 'b1');
      if (!BotDecisionEngine.shouldSeeCards(
        obs1,
        BotProfileParams.blindBluffer,
        random: Random(1000 + i),
      )) {
        blindBlufferStayedBlind++;
      }

      final obs2 = SeatObservation.fromTableState(state, viewerId: 'b2');
      if (!BotDecisionEngine.shouldSeeCards(
        obs2,
        BotProfileParams.cautious,
        random: Random(2000 + i),
      )) {
        cautiousStayedBlind++;
      }
    }

    expect(blindBlufferStayedBlind, greaterThan(cautiousStayedBlind));
  });

  test(
      'Practice mode isolates practiceChips from online chips and sends zero Supabase requests',
      () async {
    final supabaseHits = <String>[];
    final mockHttp = MockClient((http.Request req) async {
      supabaseHits.add('${req.method} ${req.url.path}');
      return http.Response('[]', 200);
    });
    final supabase = SupabaseSyncClient(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon_test',
      httpClient: mockHttp,
    )..restoreTokens(
        accessToken: 'jwt_token',
        refreshToken: 'refresh_token',
        authUserId: '11111111-1111-4111-8111-111111111111',
      );

    final store = AppSessionStore(supabaseClient: supabase);
    expect(store.chips, 25000);
    expect(store.practiceChips, 25000);

    final repo = GameTableRepositoryImpl(
      random: Random(12),
      sessionStore: store,
      config: const GameTableConfig(
        tableName: 'Practice Table',
        minStake: 50,
        maxStake: 1600,
        maxPlayers: 4,
        variant: 'Practice',
        isPractice: true,
      ),
    );

    var state = await repo.getInitialTableState();
    state = await repo.performAction(
      currentState: state,
      action: PlayerTableAction.pack,
    );
    while (!state.isRoundOver) {
      state = await repo.performAutomatedTurn(currentState: state);
    }

    // Only practiceChips changed; online chips & Supabase remained untouched.
    expect(store.practiceChips, 24950);
    expect(store.chips, 25000);
    expect(store.gamesPlayed, 0);
    expect(supabaseHits, isEmpty);

    await store.claimPracticeReliefChips(amount: 1050);
    expect(store.practiceChips, 26000);
    await store.resetPracticeChips();
    expect(store.practiceChips, 25000);
    expect(store.chips, 25000);
  });
}
