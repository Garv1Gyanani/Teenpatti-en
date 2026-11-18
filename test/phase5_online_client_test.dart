import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teen_patti/core/constants/app_assets.dart';
import 'package:teen_patti/core/router/app_routes.dart';
import 'package:teen_patti/core/router/deep_link_parser.dart';
import 'package:teen_patti/core/session/app_session_store.dart';
import 'package:teen_patti/core/session/supabase_sync_client.dart';
import 'package:teen_patti/features/friends/data/repositories/friends_repository_impl.dart';
import 'package:teen_patti/features/friends/domain/entities/friend_member.dart';
import 'package:teen_patti/features/friends/domain/usecases/get_friends_data_usecase.dart';
import 'package:teen_patti/features/friends/presentation/controllers/friends_controller.dart';
import 'package:teen_patti/features/friends/presentation/pages/friends_page.dart';
import 'package:teen_patti/features/game_table/data/repositories/online_game_table_repository.dart';
import 'package:teen_patti/features/game_table/domain/entities/game_table_config.dart';
import 'package:teen_patti/features/game_table/domain/entities/table_chat_message.dart';
import 'package:teen_patti/features/game_table/presentation/controllers/game_table_controller.dart';
import 'package:teen_patti/features/game_table/presentation/pages/game_table_page.dart';
import 'package:teen_patti/features/private_room/data/repositories/private_room_repository_impl.dart';
import 'package:teen_patti/features/private_room/domain/usecases/get_private_room_usecase.dart';
import 'package:teen_patti/features/private_room/presentation/controllers/private_room_controller.dart';
import 'package:teen_patti/features/private_room/presentation/pages/private_room_page.dart';
import 'package:teen_patti_core/teen_patti_core.dart';

void main() {
  test(
    'SupabaseSyncClient strips server-protected profile columns, aligns auth id, and parses matchmaking RPCs',
    () async {
      Map<String, dynamic>? capturedProfilePayload;
      final recordedPaths = <String>[];

      final mockHttp = MockClient((http.Request request) async {
        recordedPaths.add('${request.method} ${request.url.path}');
        if (request.url.path == '/auth/v1/signup') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'jwt_user_1',
              'refresh_token': 'ref_user_1',
              'user': <String, dynamic>{
                'id': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/rest/v1/tp_profiles' &&
            request.method == 'POST') {
          capturedProfilePayload =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('[]', 201);
        }
        if (request.url.path == '/rest/v1/tp_profiles' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
                'chips': 31400,
                'rating': 1120,
                'games_played': 8,
                'wins': 5,
                'current_win_streak': 2,
                'best_streak': 4,
                'total_rewards_earned': 7700,
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/rest/v1/rpc/tp_join_or_create_public_room') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'room_id': '11111111-1111-4111-8111-111111111111',
                'seat_index': 0,
                'table_name': 'Mumbai Velvet',
                'variant': 'Classic',
                'min_stake': 100,
                'max_stake': 3200,
                'max_players': 5,
                'fill_with_ai': true,
                'status': 'waiting',
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/rest/v1/rpc/tp_create_private_room') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['p_fill_with_ai'], isFalse);
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'room_id': '22222222-2222-4222-8222-222222222222',
                'room_code': 'AB12CD',
                'seat_index': 0,
                'table_name': 'Private Club',
                'variant': 'Classic',
                'min_stake': 250,
                'max_stake': 8000,
                'max_players': 4,
                'fill_with_ai': false,
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/rest/v1/rpc/tp_join_room_by_code') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'room_id': '22222222-2222-4222-8222-222222222222',
                'room_code': 'AB12CD',
                'seat_index': 1,
                'table_name': 'Private Club',
                'variant': 'Classic',
                'min_stake': 250,
                'max_stake': 8000,
                'max_players': 4,
                'fill_with_ai': false,
                'status': 'waiting',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final supabase = SupabaseSyncClient(
        supabaseUrl: 'https://demo.supabase.co/',
        supabaseAnonKey: 'anon_demo_key',
        httpClient: mockHttp,
      );
      expect(
        supabase.realtimeWebSocketUrl,
        'wss://demo.supabase.co/realtime/v1',
      );

      final store = AppSessionStore(supabaseClient: supabase);
      final prepared = await store.prepareOnlineSession();
      expect(prepared, isTrue);
      expect(store.profileId, 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee');
      expect(store.chips, 31400);
      expect(store.rating, 1120);
      expect(store.gamesPlayed, 8);
      expect(store.wins, 5);

      expect(capturedProfilePayload, isNotNull);
      expect(
        capturedProfilePayload!['id'],
        'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      );
      expect(capturedProfilePayload!.containsKey('chips'), isFalse);
      expect(capturedProfilePayload!.containsKey('rating'), isFalse);
      expect(capturedProfilePayload!.containsKey('games_played'), isFalse);
      expect(capturedProfilePayload!.containsKey('wins'), isFalse);
      expect(
        capturedProfilePayload!.containsKey('current_win_streak'),
        isFalse,
      );
      expect(capturedProfilePayload!.containsKey('best_streak'), isFalse);
      expect(
        capturedProfilePayload!.containsKey('total_rewards_earned'),
        isFalse,
      );

      final publicTicket = await supabase.joinOrCreatePublicRoom(
        tableName: 'Mumbai Velvet',
      );
      expect(publicTicket?.roomId, '11111111-1111-4111-8111-111111111111');
      expect(publicTicket?.fillWithAi, isTrue);

      final privateTicket = await supabase.createPrivateRoom(
        tableName: 'Private Club',
        minStake: 250,
        maxPlayers: 4,
        fillWithAi: false,
      );
      expect(privateTicket?.roomCode, 'AB12CD');
      expect(privateTicket?.fillWithAi, isFalse);

      final joinedTicket = await supabase.joinRoomByCode('ab12cd');
      expect(joinedTicket?.seatIndex, 1);
      expect(recordedPaths, contains('POST /rest/v1/rpc/tp_join_room_by_code'));
    },
  );

  test(
    'OnlineGameTableRepository preserves card hiding, hides automated flags, and maps showdown results',
    () {
      const uid = 'human-1';
      const fallback = TablePlayer(
        id: uid,
        name: 'Garv',
        chips: 25000,
        avatarAsset: AppAssets.avatar2,
        isLocalPlayer: true,
      );

      final waitingObs = SeatObservation(
        tableName: 'Club Table',
        viewerId: uid,
        minStake: 100,
        maxStake: 3200,
        potAmount: 0,
        blindAmount: 100,
        chaalAmount: 200,
        roundNumber: 0,
        seats: const <ObservedSeat>[
          ObservedSeat(
            id: uid,
            name: 'Garv',
            chips: 25000,
            avatarAsset: AppAssets.avatar2,
            seatIndex: 0,
          ),
        ],
      );
      final waitingTable = OnlineGameTableRepository.mapObservationToTableState(
        waitingObs,
        viewerId: uid,
        localFallback: fallback,
      );
      expect(waitingTable.roundNumber, 0);
      expect(waitingTable.lastActionLabel, 'Searching for players...');

      const aceSpades = PlayingCard(suit: CardSuit.spades, rank: 'A');
      const kingSpades = PlayingCard(suit: CardSuit.spades, rank: 'K');
      const queenSpades = PlayingCard(suit: CardSuit.spades, rank: 'Q');
      const twoHearts = PlayingCard(suit: CardSuit.hearts, rank: '2');
      const threeDiamonds = PlayingCard(suit: CardSuit.diamonds, rank: '3');
      const fiveClubs = PlayingCard(suit: CardSuit.clubs, rank: '5');

      final liveBlindObs = SeatObservation(
        tableName: 'Club Table',
        viewerId: uid,
        minStake: 100,
        maxStake: 3200,
        potAmount: 600,
        blindAmount: 100,
        chaalAmount: 200,
        roundNumber: 1,
        seats: const <ObservedSeat>[
          ObservedSeat(
            id: uid,
            name: 'Garv',
            chips: 24900,
            avatarAsset: AppAssets.avatar2,
            seatIndex: 0,
            totalBet: 100,
            isActiveTurn: true,
          ),
          ObservedSeat(
            id: 'opp-1',
            name: 'Riya',
            chips: 29900,
            avatarAsset: 'assets/images/online_avatar_1.png',
            seatIndex: 1,
            totalBet: 100,
            hasSeenCards: true,
          ),
        ],
      );
      final liveBlindTable =
          OnlineGameTableRepository.mapObservationToTableState(
        liveBlindObs,
        viewerId: uid,
        localFallback: fallback,
        roundStartChipsByRound: <int, int>{1: 25000},
      );
      expect(liveBlindTable.localPlayer.cards, isEmpty);
      expect(liveBlindTable.players[1].cards, isEmpty);
      expect(liveBlindTable.players[1].participantKind, ParticipantKind.human);
      expect(liveBlindTable.isLocalPlayersTurn, isTrue);

      final showdownObs = SeatObservation(
        tableName: 'Club Table',
        viewerId: uid,
        minStake: 100,
        maxStake: 3200,
        potAmount: 1000,
        blindAmount: 200,
        chaalAmount: 400,
        roundNumber: 1,
        isRoundOver: true,
        winnerId: uid,
        winReason: 'Won by Showdown',
        myCards: const <PlayingCard>[aceSpades, kingSpades, queenSpades],
        seats: const <ObservedSeat>[
          ObservedSeat(
            id: uid,
            name: 'Garv',
            chips: 25500,
            avatarAsset: AppAssets.avatar2,
            seatIndex: 0,
            totalBet: 500,
            hasSeenCards: true,
            revealedCards: <PlayingCard>[aceSpades, kingSpades, queenSpades],
          ),
          ObservedSeat(
            id: 'opp-1',
            name: 'Riya',
            chips: 29500,
            avatarAsset: 'assets/images/online_avatar_1.png',
            seatIndex: 1,
            totalBet: 500,
            hasSeenCards: true,
            revealedCards: <PlayingCard>[twoHearts, threeDiamonds, fiveClubs],
          ),
        ],
      );
      final showdownTable =
          OnlineGameTableRepository.mapObservationToTableState(
        showdownObs,
        viewerId: uid,
        localFallback: fallback,
        roundStartChipsByRound: <int, int>{1: 25000},
      );
      expect(showdownTable.isRoundOver, isTrue);
      expect(showdownTable.roundResult?.winner.id, uid);
      expect(showdownTable.roundResult?.previousBalance, 25000);
      expect(showdownTable.roundResult?.newBalance, 25500);
      expect(showdownTable.roundResult?.showdownHands.length, 2);
      expect(showdownTable.roundResult?.handLabel, contains('Pure Sequence'));
    },
  );

  testWidgets(
    'PrivateRoomPage defaults Fill empty seats with AI to OFF and toggles cleanly',
    (WidgetTester tester) async {
      final session = AppSessionStore();
      await session.hydrate();
      final controller = PrivateRoomController(
        getPrivateRoomUseCase: GetPrivateRoomUseCase(
          repository: PrivateRoomRepositoryImpl(sessionStore: session),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: PrivateRoomPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(controller.state?.fillWithAi, isFalse);
      expect(find.text('Fill empty seats with AI'), findsOneWidget);
      expect(find.text('Join Room by Code'), findsOneWidget);

      final toggleFinder = find.byKey(const Key('fill_empty_seats_ai_toggle'));
      await tester.ensureVisible(toggleFinder);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(controller.state?.fillWithAi, isTrue);
    },
  );

  testWidgets(
    'GameTablePage online mode shows Searching for players pill, auto-dismisses round dialog on next deal, and triggers explicit leave on Back',
    (WidgetTester tester) async {
      final session = AppSessionStore();
      await session.hydrate();
      final fakeRepo = _FakeOnlineRepo(sessionStore: session);
      final controller = GameTableController.forRepository(
        repository: fakeRepo,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameTablePage(controller: controller),
                      ),
                    );
                  },
                  child: const Text('Enter'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.isWaitingForOpponents, isTrue);
      expect(find.text('Searching for players...'), findsOneWidget);
      expect(controller.canLocalSeeCards, isFalse);

      // Push live round 1 deal -> waiting pill clears, See Cards becomes enabled.
      const aceSpades = PlayingCard(suit: CardSuit.spades, rank: 'A');
      const kingHearts = PlayingCard(suit: CardSuit.hearts, rank: 'K');
      const queenDiamonds = PlayingCard(suit: CardSuit.diamonds, rank: 'Q');
      final round1 = TableState(
        tableName: 'Classic Club',
        minStake: 100,
        maxStake: 3200,
        potAmount: 300,
        blindAmount: 100,
        chaalAmount: 200,
        roundNumber: 1,
        turnDeadline: DateTime.now().toUtc().add(const Duration(seconds: 22)),
        players: const <TablePlayer>[
          TablePlayer(
            id: 'u-local',
            name: 'Garv',
            chips: 24900,
            avatarAsset: AppAssets.avatar2,
            isLocalPlayer: true,
            isActiveTurn: true,
          ),
          TablePlayer(
            id: 'u-opp-1',
            name: 'Riya',
            chips: 29900,
            avatarAsset: 'assets/images/online_avatar_1.png',
          ),
        ],
      );
      fakeRepo.pushState(round1);
      await tester.pump();

      expect(controller.isWaitingForOpponents, isFalse);
      expect(find.text('Searching for players...'), findsNothing);
      expect(controller.canLocalSeeCards, isTrue);

      // Showdown finishes Round 1 -> RoundResultDialog appears.
      fakeRepo.pushState(
        round1.copyWith(
          roundResult: RoundResult(
            wonAmount: 600,
            previousBalance: 25000,
            newBalance: 25300,
            handLabel: 'High Card',
            winner: round1.players.first,
            packedOpponents: const <TablePlayer>[],
            showdownHands: <ShowdownHandSummary>[
              ShowdownHandSummary(
                player: round1.players.first.copyWith(
                  cards: const <PlayingCard>[
                    aceSpades,
                    kingHearts,
                    queenDiamonds,
                  ],
                ),
                handLabel: 'High Card',
                isWinner: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back to Lobby'), findsOneWidget);

      // Authoritative server deals Round 2 -> open RoundResultDialog auto-closes!
      fakeRepo.pushState(round1.copyWith(roundNumber: 2, potAmount: 200));
      await tester.pumpAndSettle();
      expect(find.text('Back to Lobby'), findsNothing);

      // Tap Back button -> leaves online table cleanly and pops route.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(fakeRepo.leftTable, isTrue);
      expect(find.text('Enter'), findsOneWidget);
    },
  );

  test(
    'GameTableController relays online chat & quick reactions over OnlineGameTableRepository and displays incoming peer/bot bubbles',
    () async {
      final session = AppSessionStore();
      await session.hydrate();
      final fakeRepo = _FakeOnlineRepo(sessionStore: session);
      final controller = GameTableController.forRepository(
        repository: fakeRepo,
      );

      await controller.loadTable();
      fakeRepo.pushState(
        const TableState(
          tableName: 'Classic Club',
          minStake: 100,
          maxStake: 3200,
          potAmount: 300,
          blindAmount: 100,
          chaalAmount: 200,
          roundNumber: 1,
          players: <TablePlayer>[
            TablePlayer(
              id: 'u-local',
              name: 'Garv',
              chips: 24900,
              avatarAsset: AppAssets.avatar2,
              isLocalPlayer: true,
              isActiveTurn: true,
            ),
            TablePlayer(
              id: 'u-opp-1',
              name: 'Riya',
              chips: 29900,
              avatarAsset: 'assets/images/online_avatar_1.png',
            ),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Local player sends a quick emoji reaction -> forwarded to online repo.
      controller.sendQuickReaction('🔥');
      expect(fakeRepo.sentChats.length, 1);
      expect(fakeRepo.sentChats.first.text, '🔥');
      expect(fakeRepo.sentChats.first.isQuickReaction, isTrue);

      // Immediate second reaction during cooldown is blocked locally.
      controller.sendQuickReaction('😎');
      expect(fakeRepo.sentChats.length, 1);

      // Incoming broadcast from remote opponent/bot updates chat log and seat bubble.
      fakeRepo.pushChat(
        TableChatMessage(
          id: 'chat_remote_1',
          senderId: 'u-opp-1',
          senderName: 'Riya',
          senderAvatar: 'assets/images/online_avatar_1.png',
          text: 'Well played! 👏',
          timestamp: DateTime(2026, 11, 15, 17, 0),
          isQuickReaction: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        controller.chatMessages.any(
          (m) => m.senderId == 'u-opp-1' && m.text == 'Well played! 👏',
        ),
        isTrue,
      );
      expect(
        controller.activeSeatReactions['u-opp-1'],
        'Well played! 👏',
      );

      controller.dispose();
    },
  );

  test(
    'AppSessionStore syncs real Friends graph and Room Invites via Supabase RPCs',
    () async {
      final recordedRpcPaths = <String>[];

      final mockHttp = MockClient((http.Request request) async {
        final path = request.url.path;
        if (path == '/auth/v1/signup') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'access_token': 'jwt_friends_test',
              'refresh_token': 'ref_friends_test',
              'user': <String, dynamic>{
                'id': '33333333-4444-4555-8666-777777777777',
              },
            }),
            200,
          );
        }
        if (path == '/rest/v1/tp_profiles') {
          return http.Response('[]', 201);
        }
        if (path.startsWith('/rest/v1/rpc/')) {
          recordedRpcPaths.add(path);
        }
        if (path == '/rest/v1/rpc/tp_touch_presence') {
          return http.Response('null', 200);
        }
        if (path == '/rest/v1/rpc/tp_get_friends_directory') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'friend_id': '44444444-5555-4666-8777-888888888888',
                'player_code': 'TP44445555',
                'display_name': 'Vikram',
                'avatar_asset': AppAssets.avatar3,
                'chips': 42000,
                'rating': 1180,
                'is_online': true,
                'last_seen_at': DateTime.now().toUtc().toIso8601String(),
              },
            ]),
            200,
          );
        }
        if (path == '/rest/v1/rpc/tp_get_pending_room_invites') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'invite_id': '55555555-6666-4777-8888-999999999999',
                'sender_id': '44444444-5555-4666-8777-888888888888',
                'sender_name': 'Vikram',
                'sender_avatar': AppAssets.avatar3,
                'room_code': 'VIP999',
                'table_name': 'Royal Private',
                'variant': 'Muflis',
                'min_stake': 250,
                'created_at': DateTime.now().toUtc().toIso8601String(),
              },
            ]),
            200,
          );
        }
        if (path == '/rest/v1/rpc/tp_add_friend_by_code') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'friend_id': '66666666-7777-4888-8999-000000000000',
                'player_code': 'TPDEV108',
                'display_name': 'Devika',
                'avatar_asset': AppAssets.avatar4,
                'chips': 50000,
                'rating': 1250,
                'is_online': true,
              },
            ]),
            200,
          );
        }
        if (path == '/rest/v1/rpc/tp_send_room_invite') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'invite_id': '77777777-8888-4999-8000-111111111111',
                'recipient_id': '66666666-7777-4888-8999-000000000000',
                'room_code': 'CLUB88',
                'status': 'pending',
              },
            ]),
            200,
          );
        }
        if (path == '/rest/v1/rpc/tp_respond_room_invite') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'invite_id': '55555555-6666-4777-8888-999999999999',
                'room_code': 'VIP999',
                'table_name': 'Royal Private',
                'variant': 'Muflis',
                'min_stake': 250,
                'status': 'accepted',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final supabase = SupabaseSyncClient(
        supabaseUrl: 'https://demo.supabase.co',
        supabaseAnonKey: 'anon_demo_key',
        httpClient: mockHttp,
      );
      final store = AppSessionStore(supabaseClient: supabase);
      await store.hydrate();

      await store.syncFriendsAndInvitesFromServer();
      expect(
        recordedRpcPaths,
        containsAll(<String>[
          '/rest/v1/rpc/tp_touch_presence',
          '/rest/v1/rpc/tp_get_friends_directory',
          '/rest/v1/rpc/tp_get_pending_room_invites',
        ]),
      );
      expect(store.friends.first.name, 'Vikram');
      expect(store.pendingRoomInvites.length, 1);
      expect(store.pendingRoomInvites.first.roomCode, 'VIP999');

      final added = await store.addFriendByCode('tpdev108');
      expect(added.name, 'Devika');
      expect(store.friends.first.name, 'Devika');
      expect(recordedRpcPaths, contains('/rest/v1/rpc/tp_add_friend_by_code'));

      final inviteSent = await store.sendTableInviteToFriend(
        friend: added,
        roomCode: 'CLUB88',
      );
      expect(inviteSent, isTrue);
      expect(recordedRpcPaths, contains('/rest/v1/rpc/tp_send_room_invite'));

      final joinedCode = await store.respondToTableInvite(
        inviteId: '55555555-6666-4777-8888-999999999999',
        accept: true,
      );
      expect(joinedCode, 'VIP999');
      expect(store.pendingRoomInvites, isEmpty);
      expect(recordedRpcPaths, contains('/rest/v1/rpc/tp_respond_room_invite'));
    },
  );

  testWidgets(
    'DeepLinkParser extracts ?room=XXXXXX and FriendsPage / PrivateRoomPage integrate with live Friends & Invites',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      expect(
        DeepLinkParser.extractRoomCodeFromUri(
          Uri.parse('https://acesociety.club/?room=ab12cd'),
        ),
        'AB12CD',
      );
      expect(
        DeepLinkParser.extractRoomCodeFromUri(
          Uri.parse('https://acesociety.club/#/private-room?room=xy98zw'),
        ),
        'XY98ZW',
      );
      expect(
        DeepLinkParser.extractRoomCodeFromRouteName('/?room=vip777'),
        'VIP777',
      );
      expect(
        DeepLinkParser.buildShareableRoomUrl(
          'ab12cd',
          baseUri: Uri.parse('https://acesociety.club/home'),
        ),
        'https://acesociety.club/?room=AB12CD',
      );

      final store = AppSessionStore();
      await store.hydrate();
      AppSessionStore.setInstance(store);

      // Push an incoming table invite and add a friend by code.
      await store.addFriendByCode('TP998877');
      store.pushIncomingRoomInvite(
        TableRoomInvite(
          id: 'inv_live_1',
          senderId: 'fr_aryan',
          senderName: 'Aryan',
          senderAvatar: AppAssets.avatar2,
          roomCode: 'JOIN77',
          tableName: 'High Stakes Club',
          variant: 'Classic',
          minStake: 250,
          createdAt: DateTime(2026, 11, 15, 17, 0),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: FriendsPage(
            embedded: false,
            controller: FriendsController(
              getFriendsDataUseCase: GetFriendsDataUseCase(
                repository: FriendsRepositoryImpl(sessionStore: store),
              ),
              sessionStore: store,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify pending invite banner and newly added friend appear on FriendsPage.
      expect(find.text('Table Invites (1)'), findsOneWidget);
      expect(find.text('Aryan invited you'), findsOneWidget);
      expect(find.text('Member TP9988'), findsOneWidget);

      // Tap Join Table on the pending invite -> navigates to PrivateRoomPage with roomCode 'JOIN77'!
      await tester.tap(find.byKey(const Key('accept_room_invite_inv_live_1')));
      await tester.pumpAndSettle();

      expect(find.text('Private Room'), findsOneWidget);
      expect(find.text('JOIN77'), findsOneWidget);
    },
  );
}

class _FakeOnlineRepo extends OnlineGameTableRepository {
  _FakeOnlineRepo({required super.sessionStore})
      : super(
          config: const GameTableConfig(
            tableName: 'Classic Club',
            minStake: 100,
            maxStake: 3200,
            isOnline: true,
          ),
        );

  final StreamController<TableState> _fakeStream =
      StreamController<TableState>.broadcast();
  final StreamController<TableChatMessage> _fakeChatStream =
      StreamController<TableChatMessage>.broadcast();
  final List<({String text, bool isQuickReaction})> sentChats =
      <({String text, bool isQuickReaction})>[];
  bool leftTable = false;

  @override
  Stream<TableState> get stateStream => _fakeStream.stream;

  @override
  Stream<TableChatMessage> get chatStream => _fakeChatStream.stream;

  void pushState(TableState state) {
    _fakeStream.add(state);
  }

  void pushChat(TableChatMessage event) {
    _fakeChatStream.add(event);
  }

  @override
  Future<bool> sendChatOrReaction({
    required String text,
    required bool isQuickReaction,
    String? playerId,
  }) async {
    sentChats.add((text: text, isQuickReaction: isQuickReaction));
    _fakeChatStream.add(
      TableChatMessage(
        id: 'local_${sentChats.length}',
        senderId: playerId ?? 'u-local',
        senderName: 'Garv',
        senderAvatar: AppAssets.avatar2,
        text: text,
        timestamp: DateTime.now(),
        isQuickReaction: isQuickReaction,
      ),
    );
    return true;
  }

  @override
  Future<bool> prepareSession() async => true;

  @override
  Future<TableState> getInitialTableState() async {
    return const TableState(
      tableName: 'Classic Club',
      minStake: 100,
      maxStake: 3200,
      potAmount: 0,
      blindAmount: 100,
      chaalAmount: 200,
      roundNumber: 0,
      lastActionLabel: 'Searching for players...',
      players: <TablePlayer>[
        TablePlayer(
          id: 'u-local',
          name: 'Garv',
          chips: 25000,
          avatarAsset: AppAssets.avatar2,
          isLocalPlayer: true,
        ),
      ],
    );
  }

  @override
  Future<void> leaveTable() async {
    leftTable = true;
    if (!_fakeStream.isClosed) {
      await _fakeStream.close();
    }
    if (!_fakeChatStream.isClosed) {
      await _fakeChatStream.close();
    }
  }
}
