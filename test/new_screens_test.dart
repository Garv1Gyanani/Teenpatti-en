import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti/core/router/app_routes.dart';
import 'package:teen_patti/core/theme/app_theme.dart';
import 'package:teen_patti/core/utils/formatters.dart';
import 'package:teen_patti/features/daily_rewards/data/repositories/daily_rewards_repository_impl.dart';
import 'package:teen_patti/features/daily_rewards/domain/usecases/get_daily_rewards_usecase.dart';
import 'package:teen_patti/features/daily_rewards/presentation/controllers/daily_rewards_controller.dart';
import 'package:teen_patti/features/daily_rewards/presentation/pages/daily_rewards_page.dart';
import 'package:teen_patti/features/friends/data/repositories/friends_repository_impl.dart';
import 'package:teen_patti/features/friends/domain/usecases/get_friends_data_usecase.dart';
import 'package:teen_patti/features/friends/presentation/controllers/friends_controller.dart';
import 'package:teen_patti/features/friends/presentation/pages/friends_page.dart';
import 'package:teen_patti/features/home/data/repositories/home_repository_impl.dart';
import 'package:teen_patti/features/home/domain/usecases/claim_daily_reward_usecase.dart';
import 'package:teen_patti/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:teen_patti/features/home/presentation/controllers/home_controller.dart';
import 'package:teen_patti/features/home/presentation/pages/home_page.dart';
import 'package:teen_patti/features/private_room/data/repositories/private_room_repository_impl.dart';
import 'package:teen_patti/features/private_room/domain/usecases/get_private_room_usecase.dart';
import 'package:teen_patti/features/private_room/presentation/controllers/private_room_controller.dart';
import 'package:teen_patti/features/private_room/presentation/pages/private_room_page.dart';
import 'package:teen_patti/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:teen_patti/features/profile/domain/entities/player_profile_data.dart';
import 'package:teen_patti/features/profile/domain/usecases/get_player_profile_usecase.dart';
import 'package:teen_patti/features/profile/presentation/controllers/profile_controller.dart';
import 'package:teen_patti/features/profile/presentation/pages/profile_page.dart';
import 'package:teen_patti/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:teen_patti/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:teen_patti/features/settings/presentation/controllers/settings_controller.dart';
import 'package:teen_patti/features/settings/presentation/pages/settings_page.dart';
import 'package:teen_patti/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:teen_patti/features/wallet/domain/usecases/get_wallet_data_usecase.dart';
import 'package:teen_patti/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:teen_patti/features/wallet/presentation/pages/wallet_page.dart';

Widget _wrapScreen(Widget child, {Size size = const Size(390, 844)}) {
  return MaterialApp(
    theme: AppTheme.light,
    onGenerateRoute: AppRoutes.onGenerateRoute,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: child,
    ),
  );
}

void main() {
  test('formatIndianNumber formats standard and lakh numbers accurately', () {
    expect(formatIndianNumber(100), '100');
    expect(formatIndianNumber(1500), '1,500');
    expect(formatIndianNumber(124500), '1,24,500');
    expect(formatIndianNumber(200000), '2,00,000');
    expect(formatIndianNumber(-5000), '-5,000');
  });

  test('SettingsController loads and toggles preferences', () async {
    final controller = SettingsController(
      getSettingsUseCase: const GetSettingsUseCase(
        repository: SettingsRepositoryImpl(),
      ),
    );
    await controller.loadSettings();
    expect(controller.state!.playerName, 'Garv Gyanani');
    expect(controller.state!.playerId, 'TP458732');
    expect(controller.state!.soundEffects, isTrue);

    controller.toggleSoundEffects(false);
    expect(controller.state!.soundEffects, isFalse);

    controller.toggleBackgroundMusic(false);
    expect(controller.state!.backgroundMusic, isFalse);

    controller.toggleVibration(false);
    expect(controller.state!.vibration, isFalse);
    controller.dispose();
  });

  test('WalletController loads, watches ad, buys chips, and toggles view all',
      () async {
    final controller = WalletController(
      getWalletDataUseCase: const GetWalletDataUseCase(
        repository: WalletRepositoryImpl(),
      ),
    );
    await controller.loadWallet();
    expect(controller.data!.balance, 124500);
    expect(controller.visibleTransactions.length, 5);

    controller.toggleShowAllTransactions();
    expect(controller.visibleTransactions.length, 6);

    final earned = controller.claimWatchAndEarn();
    expect(earned, 1000);
    expect(controller.data!.balance, 125500);

    controller.purchaseChips(priceInr: 499, chipAmount: 200000);
    expect(controller.data!.balance, 325500);
    controller.dispose();
  });

  test('ProfileController loads profile and updates metric & name', () async {
    final controller = ProfileController(
      getPlayerProfileUseCase: const GetPlayerProfileUseCase(
        repository: ProfileRepositoryImpl(),
      ),
    );
    await controller.loadProfile();
    expect(controller.profile!.name, 'Garv Gyanani');
    expect(controller.profile!.chipBalance, 124500);
    expect(controller.selectedMetric, PerformanceMetric.gamesWon);

    controller.selectMetric(PerformanceMetric.winRate);
    expect(controller.selectedMetric, PerformanceMetric.winRate);

    controller.updateProfile(name: 'Ace Garv');
    expect(controller.profile!.name, 'Ace Garv');
    controller.dispose();
  });

  test('DailyRewardsController loads 7 days and claims day 5 reward', () async {
    final controller = DailyRewardsController(
      getDailyRewardsUseCase: const GetDailyRewardsUseCase(
        repository: DailyRewardsRepositoryImpl(),
      ),
    );
    await controller.loadRewards();
    expect(controller.data!.currentStreakDays, 5);
    expect(controller.featuredDays.length, 4);
    expect(controller.data!.totalRewardsEarned, 6200);

    final amount = controller.claimTodayReward();
    expect(amount, 1500);
    expect(controller.data!.isTodayClaimed, isTrue);
    expect(controller.data!.totalRewardsEarned, 7700);
    controller.dispose();
  });

  test('PrivateRoomController manages settings, toggles, ready, and seats',
      () async {
    final controller = PrivateRoomController(
      getPrivateRoomUseCase: const GetPrivateRoomUseCase(
        repository: PrivateRoomRepositoryImpl(),
      ),
    );
    await controller.loadRoom();
    expect(controller.state!.roomCode, '9F7K2D');
    expect(controller.state!.bootAmount, 100);
    expect(controller.state!.maxPlayers, 6);
    expect(controller.state!.gameVariant, 'Classic');
    expect(controller.state!.isRoomLocked, isTrue);
    expect(controller.state!.allowSpectators, isFalse);
    expect(controller.state!.autoNextRound, isTrue);

    controller.setBootAmount(500);
    controller.setGameVariant('Muflis');
    controller.toggleSpectators(true);
    controller.toggleReady();
    expect(controller.state!.bootAmount, 500);
    expect(controller.state!.gameVariant, 'Muflis');
    expect(controller.state!.allowSpectators, isTrue);
    expect(controller.state!.isLocalReady, isTrue);
    controller.dispose();
  });

  testWidgets('SettingsPage renders all sections without overflow',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapScreen(
        SettingsPage(
          controller: SettingsController(
            getSettingsUseCase: const GetSettingsUseCase(
              repository: SettingsRepositoryImpl(),
            ),
          ),
        ),
        size: const Size(360, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings & Help'), findsOneWidget);
    expect(find.text('Game Preferences'), findsOneWidget);
    expect(find.text('Sound Effects'), findsOneWidget);
    expect(find.text('Background Music'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
    expect(find.text('Garv Gyanani'), findsOneWidget);
    expect(find.text('Player ID: TP458732'), findsOneWidget);
    expect(find.text('Manage Account'), findsOneWidget);
    expect(find.text('Game Rules'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Help / FAQ'), findsOneWidget);
    expect(find.text('Contact Support'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
  });

  testWidgets('WalletPage renders balance, freebies, and transactions cleanly',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapScreen(
        WalletPage(
          controller: WalletController(
            getWalletDataUseCase: const GetWalletDataUseCase(
              repository: WalletRepositoryImpl(),
            ),
          ),
        ),
        size: const Size(360, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chip Wallet'), findsOneWidget);
    expect(find.text('Current Balance'), findsOneWidget);
    expect(find.text('Claim Free Chips'), findsOneWidget);
    expect(find.text('Buy Chips'), findsOneWidget);
    expect(find.text('Daily Claim'), findsOneWidget);
    expect(find.text('Streak Bonus'), findsOneWidget);
    expect(find.text('Watch & Earn'), findsOneWidget);
    expect(find.text('Transaction History'), findsOneWidget);
    expect(find.text('+2,00,000'), findsOneWidget);
    expect(find.text('-5,000'), findsOneWidget);
  });

  testWidgets('ProfilePage renders stats, performance chart, and menu links',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapScreen(
        ProfilePage(
          controller: ProfileController(
            getPlayerProfileUseCase: const GetPlayerProfileUseCase(
              repository: ProfileRepositoryImpl(),
            ),
          ),
        ),
        size: const Size(360, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Garv Gyanani'), findsOneWidget);
    expect(find.text('Player ID: TP458732'), findsOneWidget);
    expect(find.text('Club Member'), findsOneWidget);
    expect(find.text('₹1,24,500'), findsOneWidget);
    expect(find.text('1,248'), findsOneWidget);
    expect(find.text('58.7%'), findsOneWidget);
    expect(find.text('Games Won'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
  });

  testWidgets('DailyRewardsPage renders stepper, 4 day cards, and claims reward',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapScreen(
        DailyRewardsPage(
          controller: DailyRewardsController(
            getDailyRewardsUseCase: const GetDailyRewardsUseCase(
              repository: DailyRewardsRepositoryImpl(),
            ),
          ),
        ),
        size: const Size(360, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily Rewards'), findsOneWidget);
    expect(find.text('5 Days'), findsOneWidget);
    expect(find.text('₹2,000 Chips'), findsOneWidget);
    expect(find.text("Claim Today's Reward"), findsOneWidget);
    expect(find.text('₹6,200 Chips'), findsOneWidget);

    await tester.ensureVisible(find.text("Claim Today's Reward"));
    await tester.tap(find.text("Claim Today's Reward"));
    await tester.pumpAndSettle();

    expect(find.text('₹7,700 Chips'), findsOneWidget);
  });

  testWidgets('PrivateRoomPage renders table, seats, settings & host controls',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapScreen(
        PrivateRoomPage(
          controller: PrivateRoomController(
            getPrivateRoomUseCase: const GetPrivateRoomUseCase(
              repository: PrivateRoomRepositoryImpl(),
            ),
          ),
        ),
        size: const Size(360, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Private Room'), findsOneWidget);
    expect(find.text('9F7K2D'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Garv'), findsOneWidget);
    expect(find.text('Sneha'), findsOneWidget);
    expect(find.text('Rohit'), findsOneWidget);
    expect(find.text('Aryan'), findsOneWidget);
    expect(find.text('Invite'), findsNWidgets(2));
    expect(find.text('Room Settings'), findsOneWidget);
    expect(find.text('Host Controls'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Start Game'), findsOneWidget);
  });

  testWidgets('FriendsPage renders standalone and HomePage navigates tabs',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapScreen(
        FriendsPage(
          embedded: false,
          controller: FriendsController(
            getFriendsDataUseCase: const GetFriendsDataUseCase(
              repository: FriendsRepositoryImpl(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('A7K9D4'), findsOneWidget);

    await tester.pumpWidget(
      _wrapScreen(
        HomePage(
          controller: HomeController(
            getDashboardUseCase: const GetHomeDashboardUseCase(
              repository: HomeRepositoryImpl(),
            ),
            claimDailyRewardUseCase: const ClaimDailyRewardUseCase(
              repository: HomeRepositoryImpl(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Rewards'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);
  });
}
