import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teen_patti/app.dart';
import 'package:teen_patti/core/constants/app_assets.dart';
import 'package:teen_patti/core/router/app_routes.dart';
import 'package:teen_patti/core/session/app_session_store.dart';
import 'package:teen_patti/core/session/local_storage_io.dart';
import 'package:teen_patti/core/session/supabase_sync_client.dart';
import 'package:teen_patti/features/daily_rewards/data/repositories/daily_rewards_repository_impl.dart';
import 'package:teen_patti/features/daily_rewards/domain/usecases/get_daily_rewards_usecase.dart';
import 'package:teen_patti/features/daily_rewards/presentation/controllers/daily_rewards_controller.dart';
import 'package:teen_patti/features/game_table/data/repositories/game_table_repository_impl.dart';
import 'package:teen_patti/features/game_table/domain/entities/game_table_config.dart';
import 'package:teen_patti/features/game_table/domain/entities/table_state.dart';
import 'package:teen_patti/features/game_table/presentation/controllers/game_table_controller.dart';
import 'package:teen_patti/features/home/data/repositories/home_repository_impl.dart';
import 'package:teen_patti/features/home/domain/usecases/claim_daily_reward_usecase.dart';
import 'package:teen_patti/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:teen_patti/features/home/presentation/controllers/home_controller.dart';
import 'package:teen_patti/features/private_room/data/repositories/private_room_repository_impl.dart';
import 'package:teen_patti/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:teen_patti/features/profile/domain/usecases/get_player_profile_usecase.dart';
import 'package:teen_patti/features/profile/presentation/controllers/profile_controller.dart';
import 'package:teen_patti/features/profile_setup/data/repositories/profile_setup_repository_impl.dart';
import 'package:teen_patti/features/profile_setup/domain/entities/user_profile.dart';
import 'package:teen_patti/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:teen_patti/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:teen_patti/features/wallet/domain/entities/wallet_data.dart';
import 'package:teen_patti/features/wallet/domain/usecases/get_wallet_data_usecase.dart';
import 'package:teen_patti/features/wallet/presentation/controllers/wallet_controller.dart';

void main() {
  tearDown(() {
    AppSessionStore.setInstance(AppSessionStore());
  });

  test(
      'AppSessionStore unifies ProfileSetup, Home, GameTable, Wallet, Profile, DailyRewards & Settings',
      () async {
    final store = AppSessionStore();
    await store.hydrate();

    final setupRepo = ProfileSetupRepositoryImpl(sessionStore: store);
    await setupRepo.saveProfile(
      const UserProfile(
        nickname: 'KingAce',
        avatarId: 'avatar_3',
        linkedProvider: 'Google',
      ),
    );

    final homeRepo = HomeRepositoryImpl(sessionStore: store);
    final walletController = WalletController(
      getWalletDataUseCase: GetWalletDataUseCase(
        repository: WalletRepositoryImpl(sessionStore: store),
      ),
      sessionStore: store,
    );
    final profileController = ProfileController(
      getPlayerProfileUseCase: GetPlayerProfileUseCase(
        repository: ProfileRepositoryImpl(sessionStore: store),
      ),
      sessionStore: store,
    );
    final rewardsController = DailyRewardsController(
      getDailyRewardsUseCase: GetDailyRewardsUseCase(
        repository: DailyRewardsRepositoryImpl(sessionStore: store),
      ),
      sessionStore: store,
    );
    final homeController = HomeController(
      getDashboardUseCase: GetHomeDashboardUseCase(repository: homeRepo),
      claimDailyRewardUseCase: ClaimDailyRewardUseCase(repository: homeRepo),
      sessionListenable: store,
    );

    await walletController.loadWallet();
    await profileController.loadProfile();
    await rewardsController.loadRewards();
    await homeController.loadDashboard();

    // Nickname & avatar propagate everywhere, including Private Room host seat.
    expect(homeController.dashboard!.playerName, 'KingAce');
    expect(homeController.dashboard!.avatarAsset, AppAssets.avatar3);
    expect(profileController.profile!.name, 'KingAce');
    final settings =
        await SettingsRepositoryImpl(sessionStore: store).getSettings();
    expect(settings.playerName, 'KingAce');
    final privateRoom =
        await PrivateRoomRepositoryImpl(sessionStore: store).getInitialRoom();
    expect(privateRoom.seats.first.playerName, 'KingAce');
    expect(privateRoom.seats.first.avatarAsset, AppAssets.avatar3);

    // Claim daily reward -> updates DailyRewards, Wallet, and Home simultaneously.
    final claimed = rewardsController.claimTodayReward();
    expect(claimed, 1500);
    await Future<void>.delayed(Duration.zero);
    expect(walletController.data!.balance, 26500);
    expect(homeController.dashboard!.chips, 26500);
    expect(homeController.dashboard!.isDailyRewardClaimed, isTrue);

    // Play a configured 4-player ₹250-boot game round and pack -> updates Wallet & Profile!
    final tableRepo = GameTableRepositoryImpl(
      random: Random(42),
      sessionStore: store,
      config: const GameTableConfig(
        tableName: 'Ivory Table',
        minStake: 250,
        maxStake: 8000,
        maxPlayers: 4,
        entryChips: 5000,
      ),
    );
    final tableController = GameTableController.forRepository(
      repository: tableRepo,
      botTurnDelay: Duration.zero,
    );
    await tableController.loadTable();
    expect(tableController.state!.tableName, 'Ivory Table');
    expect(tableController.state!.players.length, 4);
    expect(tableController.state!.localPlayer.name, 'KingAce');
    expect(tableController.state!.potAmount, 1000); // 4 * ₹250 boot

    await tableController.performAction(PlayerTableAction.pack);
    for (var i = 0; i < 30 && !tableController.state!.isRoundOver; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(tableController.state!.isRoundOver, isTrue);
    expect(store.chips, 26250);
    expect(walletController.data!.balance, 26250);
    expect(
      walletController.data!.transactions.first.type,
      ChipTransactionType.gameEntry,
    );
    expect(walletController.data!.transactions.first.amount, -250);
    expect(profileController.profile!.gamesPlayed, 1);
    expect(profileController.profile!.chipBalance, 26250);

    tableController.dispose();
    walletController.dispose();
    profileController.dispose();
    rewardsController.dispose();
    homeController.dispose();
  });

  test('IoJsonStorageDriver persists session across simulated app restarts',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('teen_patti_p0_test_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final driverA = IoJsonStorageDriver(customDirectoryPath: tempDir.path);
    final storeA = AppSessionStore(storageDriver: driverA);
    await storeA.hydrate();

    await storeA.completeProfileSetup(
      nickname: 'PersistentAce',
      avatarAsset: AppAssets.avatar4,
      linkedProvider: 'Apple',
    );
    await storeA.updateSettings(
      soundEffects: false,
      backgroundMusic: true,
      vibration: false,
    );
    await storeA.claimDailyReward(now: DateTime(2026, 11, 14));
    await storeA.purchaseChips(priceInr: 99, chipAmount: 25000);
    await storeA.recordCompletedRound(
      tableName: 'Royal Circle',
      variant: 'Classic',
      bootAmount: 1250,
      roundNumber: 1,
      previousBalance: 51500,
      newBalance: 59000,
      potAmount: 10000,
      localTotalBet: 2500,
      isLocalWinner: true,
      handLabel: 'Pure Sequence (A-K-Q)',
      winReason: 'Won by Showdown',
    );

    // Simulate cold restart with a brand-new driver & store reading from disk.
    final driverB = IoJsonStorageDriver(customDirectoryPath: tempDir.path);
    final storeB = AppSessionStore(storageDriver: driverB);
    await storeB.hydrate();

    expect(storeB.hasCompletedOnboarding, isTrue);
    expect(storeB.displayName, 'PersistentAce');
    expect(storeB.avatarAsset, AppAssets.avatar4);
    expect(storeB.linkedProvider, 'Apple');
    expect(storeB.soundEffects, isFalse);
    expect(storeB.backgroundMusic, isTrue);
    expect(storeB.vibration, isFalse);
    expect(storeB.chips, 59000);
    expect(storeB.gamesPlayed, 1);
    expect(storeB.wins, 1);
    expect(storeB.bestStreak, 1);
    expect(storeB.winRatePercent, 100.0);
    expect(storeB.isDailyRewardClaimedToday(DateTime(2026, 11, 14)), isTrue);
    expect(
      storeB.transactions.any((t) => t.type == ChipTransactionType.gameWin),
      isTrue,
    );
    expect(
      storeB.transactions.any((t) => t.type == ChipTransactionType.gameEntry),
      isTrue,
    );
  });

  test('SupabaseSyncClient authenticates anonymously and syncs profile & round',
      () async {
    final recordedRequests = <String>[];

    final mockHttp = MockClient((http.Request request) async {
      recordedRequests.add('${request.method} ${request.url.path}');
      if (request.url.path == '/auth/v1/signup') {
        return http.Response(
          jsonEncode({
            'access_token': 'jwt_test_token',
            'refresh_token': 'refresh_test_token',
            'user': {'id': '11111111-2222-4333-8444-555555555555'},
          }),
          200,
        );
      }
      expect(request.headers['apikey'], 'anon_test_key');
      expect(request.headers['Authorization'], 'Bearer jwt_test_token');
      return http.Response('[]', 201);
    });

    final supabase = SupabaseSyncClient(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon_test_key',
      httpClient: mockHttp,
    );
    final store = AppSessionStore(supabaseClient: supabase);

    await store.completeProfileSetup(
      nickname: 'CloudAce',
      avatarAsset: AppAssets.avatar2,
    );
    await store.recordCompletedRound(
      tableName: 'Club Lounge',
      variant: 'Classic',
      bootAmount: 500,
      roundNumber: 1,
      previousBalance: 25000,
      newBalance: 28000,
      potAmount: 4000,
      localTotalBet: 1000,
      isLocalWinner: true,
      handLabel: 'Trail (Aces)',
      winReason: 'Won by Showdown',
    );
    // Allow background unawaited sync futures to complete.
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(recordedRequests, contains('POST /auth/v1/signup'));
    expect(recordedRequests, contains('POST /rest/v1/tp_profiles'));
    expect(recordedRequests, contains('POST /rest/v1/tp_wallet_transactions'));
    expect(recordedRequests, contains('POST /rest/v1/tp_game_history'));
  });

  testWidgets(
      'Returning onboarded user skips Landing on Splash, opens Private Room table config, and Logs Out cleanly',
      (WidgetTester tester) async {
    final store = AppSessionStore();
    await store.completeProfileSetup(
      nickname: 'HostGarv',
      avatarAsset: AppAssets.avatar5,
    );
    AppSessionStore.setInstance(store);

    await tester.pumpWidget(const AceSocietyApp());
    await tester.pump();

    // Splash auto-routes directly to Home because onboarding is saved.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Play as Guest'), findsNothing);
    expect(find.text('HostGarv'), findsOneWidget);

    // Open Private Room directly via route and verify Host seat + Start Game config.
    final navContext = tester.element(find.text('HostGarv'));
    Navigator.of(navContext).pushNamed(AppRoutes.privateRoom);
    await tester.pumpAndSettle();

    expect(find.text('Private Room'), findsOneWidget);
    expect(find.text('HostGarv'), findsOneWidget);

    await tester.ensureVisible(find.text('Start Game'));
    await tester.tap(find.text('Start Game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Private Room launches 'Private • 9F7K2D' with 6 seats * ₹100 boot = ₹600 pot!
    expect(find.text('Private • 9F7K2D'), findsOneWidget);
    expect(find.text('₹600'), findsOneWidget);
    expect(find.text('HostGarv'), findsOneWidget);
    expect(find.text('Sneha'), findsOneWidget);

    // Open Settings from table top bar and Log Out -> returns to Landing & clears session flag.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Settings & Help'), findsOneWidget);

    await tester.ensureVisible(find.text('Log Out'));
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
    await tester.pumpAndSettle();

    expect(store.hasCompletedOnboarding, isFalse);
    expect(find.text('Play as Guest'), findsOneWidget);
  });

  test(
      'AppSessionStore invokes server-authoritative Wallet RPCs and preserves server balance on sync',
      () async {
    final rpcCalls = <String>[];
    var serverChips = 25000;
    var serverRewards = 6200;
    var serverStreak = 5;

    final mockHttp = MockClient((http.Request request) async {
      final path = request.url.path;
      if (path == '/auth/v1/signup') {
        return http.Response(
          jsonEncode({
            'access_token': 'jwt_wallet_token',
            'refresh_token': 'refresh_wallet_token',
            'user': {'id': '22222222-3333-4444-8555-666666666666'},
          }),
          200,
        );
      }
      if (path == '/rest/v1/tp_profiles' && request.method == 'POST') {
        return http.Response('[]', 201);
      }
      if (path == '/rest/v1/rpc/tp_claim_daily_reward') {
        rpcCalls.add('tp_claim_daily_reward');
        serverChips += 1500;
        serverRewards += 1500;
        serverStreak = 6;
        return http.Response(
          jsonEncode([
            {
              'reward_amount': 1500,
              'new_chips': serverChips,
              'daily_streak': serverStreak,
              'best_daily_streak': 12,
              'total_rewards_earned': serverRewards,
              'claim_date': '2026-11-15',
              'tx_id': 'tx_daily_server_1',
            },
          ]),
          200,
        );
      }
      if (path == '/rest/v1/rpc/tp_claim_watch_reward') {
        rpcCalls.add('tp_claim_watch_reward');
        serverChips += 1000;
        serverRewards += 1000;
        return http.Response(
          jsonEncode([
            {
              'reward_amount': 1000,
              'new_chips': serverChips,
              'total_rewards_earned': serverRewards,
              'tx_id': 'tx_watch_server_1',
            },
          ]),
          200,
        );
      }
      if (path == '/rest/v1/rpc/tp_claim_chip_pack') {
        rpcCalls.add('tp_claim_chip_pack');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final added = (body['p_chip_amount'] as num).toInt();
        serverChips += added;
        return http.Response(
          jsonEncode([
            {
              'credited_amount': added,
              'new_chips': serverChips,
              'tx_id': 'tx_buy_server_1',
            },
          ]),
          200,
        );
      }
      if (path == '/rest/v1/rpc/tp_claim_bailout_chips') {
        rpcCalls.add('tp_claim_bailout_chips');
        serverChips += 2500;
        serverRewards += 2500;
        return http.Response(
          jsonEncode([
            {
              'reward_amount': 2500,
              'new_chips': serverChips,
              'total_rewards_earned': serverRewards,
              'tx_id': 'tx_bailout_server_1',
            },
          ]),
          200,
        );
      }
      if (path == '/rest/v1/tp_profiles' && request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': '22222222-3333-4444-8555-666666666666',
              'player_code': 'TP22222222',
              'display_name': 'Garv',
              'avatar_asset': AppAssets.splashCharacter,
              'chips': serverChips,
              'rating': 1000,
              'games_played': 0,
              'wins': 0,
              'current_win_streak': 0,
              'best_streak': 0,
              'daily_streak': serverStreak,
              'best_daily_streak': 12,
              'total_rewards_earned': serverRewards,
              'last_daily_claim_date': '2026-11-15',
            },
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });

    final supabase = SupabaseSyncClient(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon_test_key',
      httpClient: mockHttp,
    );
    final store = AppSessionStore(supabaseClient: supabase);

    await store.claimDailyReward(now: DateTime(2026, 11, 15));
    await store.claimWatchAndEarn();
    await store.purchaseChips(priceInr: 99, chipAmount: 25000);
    await store.claimBailoutChips();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      rpcCalls,
      equals(<String>[
        'tp_claim_daily_reward',
        'tp_claim_watch_reward',
        'tp_claim_chip_pack',
        'tp_claim_bailout_chips',
      ]),
    );
    expect(store.chips, 55000);

    // Subsequent server profile sync preserves the RPC-credited balance.
    await store.syncOnlineProfileFromServer();
    expect(store.chips, 55000);
    expect(store.dailyStreakDays, 6);
    expect(store.totalRewardsEarned, 11200);
  });

  testWidgets(
      'Landing Sign In modal and Settings Guest Account Linking persist linked email cleanly',
      (WidgetTester tester) async {
    final authRequests = <String>[];
    final mockHttp = MockClient((http.Request request) async {
      authRequests.add('${request.method} ${request.url.path}');
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': 'jwt_member_token',
            'refresh_token': 'refresh_member_token',
            'user': {
              'id': '33333333-4444-4555-8666-777777777777',
              'email': 'kabir@acesociety.club',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/auth/v1/user' && request.method == 'PUT') {
        return http.Response(
          jsonEncode({
            'id': '33333333-4444-4555-8666-777777777777',
            'email': 'linked@acesociety.club',
          }),
          200,
        );
      }
      if (request.url.path == '/rest/v1/tp_profiles' &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': '33333333-4444-4555-8666-777777777777',
              'player_code': 'TP33333333',
              'display_name': 'KabirClub',
              'avatar_asset': AppAssets.avatar3,
              'linked_provider': 'Email (kabir@acesociety.club)',
              'chips': 42000,
              'rating': 1120,
              'games_played': 8,
              'wins': 5,
              'current_win_streak': 2,
              'best_streak': 4,
              'daily_streak': 3,
              'best_daily_streak': 7,
              'total_rewards_earned': 9000,
            },
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });

    final supabase = SupabaseSyncClient(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon_test_key',
      httpClient: mockHttp,
    );
    final store = AppSessionStore(supabaseClient: supabase);
    AppSessionStore.setInstance(store);

    await tester.pumpWidget(const AceSocietyApp());
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    // Tap Sign In on LandingPage -> opens ClubAuthDialog.
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Member Sign In'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'kabir@acesociety.club',
    );
    await tester.enterText(
      find.byKey(const Key('auth_password_field')),
      'royalflush99',
    );
    await tester.tap(find.byKey(const Key('auth_submit_button')));
    await tester.pumpAndSettle();

    // Signed in and routed to Home with server profile & chip balance restored.
    expect(authRequests, contains('POST /auth/v1/token'));
    expect(store.hasCompletedOnboarding, isTrue);
    expect(store.displayName, 'KabirClub');
    expect(store.chips, 42000);
    expect(find.text('KabirClub'), findsOneWidget);

    // Simulate unlinked guest session in SettingsPage and upgrade via Link Account.
    await store.completeProfileSetup(
      nickname: 'GuestPlayer',
      avatarAsset: AppAssets.avatar2,
      linkedProvider: null,
    );
    await tester.pumpAndSettle();
    final navContext = tester.element(find.text('GuestPlayer'));
    Navigator.of(navContext).pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();

    expect(find.text('Manage Account'), findsOneWidget);
    expect(find.text('Link Email'), findsOneWidget);

    await tester.ensureVisible(find.text('Manage Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Account'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Guest Session (Unlinked)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'linked@acesociety.club',
    );
    await tester.enterText(
      find.byKey(const Key('auth_password_field')),
      'securepass99',
    );
    await tester.ensureVisible(find.byKey(const Key('auth_submit_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(authRequests, contains('PUT /auth/v1/user'));
    expect(store.linkedProvider, 'Email (linked@acesociety.club)');
    expect(find.text('Linked'), findsOneWidget);
  });
}
