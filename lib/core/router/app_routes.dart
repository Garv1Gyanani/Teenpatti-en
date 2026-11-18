import 'package:flutter/material.dart';

import '../../features/daily_rewards/data/repositories/daily_rewards_repository_impl.dart';
import '../../features/daily_rewards/domain/usecases/get_daily_rewards_usecase.dart';
import '../../features/daily_rewards/presentation/controllers/daily_rewards_controller.dart';
import '../../features/daily_rewards/presentation/pages/daily_rewards_page.dart';
import '../../features/friends/data/repositories/friends_repository_impl.dart';
import '../../features/friends/domain/usecases/get_friends_data_usecase.dart';
import '../../features/friends/presentation/controllers/friends_controller.dart';
import '../../features/friends/presentation/pages/friends_page.dart';
import '../../features/game_table/data/repositories/game_table_repository_impl.dart';
import '../../features/game_table/data/repositories/online_game_table_repository.dart';
import '../../features/game_table/domain/entities/game_table_config.dart';
import '../../features/game_table/domain/repositories/game_table_repository.dart';
import '../../features/game_table/presentation/controllers/game_table_controller.dart';
import '../../features/game_table/presentation/pages/game_table_page.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/usecases/claim_daily_reward_usecase.dart';
import '../../features/home/domain/usecases/get_home_dashboard_usecase.dart';
import '../../features/home/presentation/controllers/home_controller.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/landing/data/repositories/landing_repository_impl.dart';
import '../../features/landing/domain/usecases/enter_as_guest_usecase.dart';
import '../../features/landing/presentation/controllers/landing_controller.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/private_room/data/repositories/private_room_repository_impl.dart';
import '../../features/private_room/domain/usecases/get_private_room_usecase.dart';
import '../../features/private_room/presentation/controllers/private_room_controller.dart';
import '../../features/private_room/presentation/pages/private_room_page.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/usecases/get_player_profile_usecase.dart';
import '../../features/profile/presentation/controllers/profile_controller.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile_setup/data/repositories/profile_setup_repository_impl.dart';
import '../../features/profile_setup/domain/usecases/get_avatar_options_usecase.dart';
import '../../features/profile_setup/domain/usecases/save_user_profile_usecase.dart';
import '../../features/profile_setup/presentation/controllers/profile_setup_controller.dart';
import '../../features/profile_setup/presentation/pages/profile_setup_page.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/usecases/get_settings_usecase.dart';
import '../../features/settings/presentation/controllers/settings_controller.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/splash/data/repositories/splash_repository_impl.dart';
import '../../features/splash/domain/usecases/initialize_app_usecase.dart';
import '../../features/splash/presentation/controllers/splash_controller.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/usecases/get_wallet_data_usecase.dart';
import '../../features/wallet/presentation/controllers/wallet_controller.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import '../session/app_session_store.dart';
import 'deep_link_parser.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String landing = '/landing';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String gameTable = '/game-table';
  static const String settings = '/settings';
  static const String wallet = '/wallet';
  static const String profile = '/profile';
  static const String dailyRewards = '/daily-rewards';
  static const String privateRoom = '/private-room';
  static const String friends = '/friends';

  static String? _normalizeRouteName(String? rawName) {
    if (rawName == null || rawName.isEmpty) return rawName;
    final parsed = Uri.tryParse(rawName);
    if (parsed == null) return rawName;
    return parsed.path.isEmpty ? splash : parsed.path;
  }

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    final session = AppSessionStore.instance;
    final deepLinkedRoomCode =
        DeepLinkParser.extractRoomCodeFromRouteName(routeSettings.name) ??
            DeepLinkParser.extractRoomCodeFromUri(Uri.base);
    if (deepLinkedRoomCode != null) {
      session.setPendingRoomCode(deepLinkedRoomCode);
    }
    final routeName = _normalizeRouteName(routeSettings.name);

    switch (routeName) {
      case splash:
        return MaterialPageRoute<void>(
          settings: routeSettings,
          builder: (_) => SplashPage(
            controller: SplashController(
              initializeAppUseCase: InitializeAppUseCase(
                repository: SplashRepositoryImpl(sessionStore: session),
              ),
            ),
          ),
        );
      case landing:
        return _fadeRoute(
          settings: routeSettings,
          child: LandingPage(
            controller: LandingController(
              enterAsGuestUseCase: const EnterAsGuestUseCase(
                repository: LandingRepositoryImpl(),
              ),
            ),
          ),
        );
      case profileSetup:
        final profileRepository = ProfileSetupRepositoryImpl(
          sessionStore: session,
        );
        return _fadeRoute(
          settings: routeSettings,
          child: ProfileSetupPage(
            controller: ProfileSetupController(
              getAvatarOptionsUseCase: GetAvatarOptionsUseCase(
                repository: profileRepository,
              ),
              saveUserProfileUseCase: SaveUserProfileUseCase(
                repository: profileRepository,
              ),
            ),
          ),
        );
      case home:
        return _fadeRoute(
          settings: routeSettings,
          child: _buildHomePage(session),
        );
      case gameTable:
        final tableConfig = routeSettings.arguments is GameTableConfig
            ? routeSettings.arguments as GameTableConfig
            : null;
        final GameTableRepository gameTableRepository =
            tableConfig != null && tableConfig.isOnline
                ? OnlineGameTableRepository(
                    config: tableConfig,
                    sessionStore: session,
                  )
                : GameTableRepositoryImpl(
                    config: tableConfig,
                    sessionStore: session,
                  );
        return _slideFadeRoute(
          settings: routeSettings,
          child: GameTablePage(
            controller: GameTableController.forRepository(
              repository: gameTableRepository,
            ),
            autoNextRound: tableConfig?.autoNextRound ?? false,
          ),
        );
      case settings:
        return _slideFadeRoute(
          settings: routeSettings,
          child: SettingsPage(
            controller: SettingsController(
              getSettingsUseCase: GetSettingsUseCase(
                repository: SettingsRepositoryImpl(sessionStore: session),
              ),
              sessionStore: session,
            ),
          ),
        );
      case wallet:
        return _slideFadeRoute(
          settings: routeSettings,
          child: WalletPage(
            controller: WalletController(
              getWalletDataUseCase: GetWalletDataUseCase(
                repository: WalletRepositoryImpl(sessionStore: session),
              ),
              sessionStore: session,
            ),
          ),
        );
      case profile:
        return _slideFadeRoute(
          settings: routeSettings,
          child: ProfilePage(
            controller: ProfileController(
              getPlayerProfileUseCase: GetPlayerProfileUseCase(
                repository: ProfileRepositoryImpl(sessionStore: session),
              ),
              sessionStore: session,
            ),
          ),
        );
      case dailyRewards:
        return _slideFadeRoute(
          settings: routeSettings,
          child: DailyRewardsPage(
            controller: DailyRewardsController(
              getDailyRewardsUseCase: GetDailyRewardsUseCase(
                repository: DailyRewardsRepositoryImpl(sessionStore: session),
              ),
              sessionStore: session,
            ),
          ),
        );
      case privateRoom:
        final roomCodeArg = routeSettings.arguments is String
            ? routeSettings.arguments as String
            : session.consumePendingRoomCode();
        return _slideFadeRoute(
          settings: routeSettings,
          child: PrivateRoomPage(
            sessionStore: session,
            controller: PrivateRoomController(
              getPrivateRoomUseCase: GetPrivateRoomUseCase(
                repository: PrivateRoomRepositoryImpl(sessionStore: session),
              ),
              initialRoomCode: roomCodeArg,
            ),
          ),
        );
      case friends:
        return _fadeRoute(
          settings: routeSettings,
          child: FriendsPage(
            embedded: false,
            controller: FriendsController(
              getFriendsDataUseCase: GetFriendsDataUseCase(
                repository: FriendsRepositoryImpl(sessionStore: session),
              ),
              sessionStore: session,
            ),
          ),
        );
      default:
        return MaterialPageRoute<void>(
          settings: routeSettings,
          builder: (_) => _buildHomePage(session),
        );
    }
  }

  static HomePage _buildHomePage(AppSessionStore session) {
    final homeRepository = HomeRepositoryImpl(sessionStore: session);
    return HomePage(
      sessionStore: session,
      controller: HomeController(
        getDashboardUseCase: GetHomeDashboardUseCase(
          repository: homeRepository,
        ),
        claimDailyRewardUseCase: ClaimDailyRewardUseCase(
          repository: homeRepository,
        ),
        sessionListenable: session,
      ),
    );
  }

  static PageRouteBuilder<void> _fadeRoute({
    required RouteSettings settings,
    required Widget child,
  }) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: (_, animation, _, page) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: page,
        );
      },
    );
  }

  static PageRouteBuilder<void> _slideFadeRoute({
    required RouteSettings settings,
    required Widget child,
  }) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: (_, animation, _, page) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: offsetAnimation,
            child: page,
          ),
        );
      },
    );
  }
}
