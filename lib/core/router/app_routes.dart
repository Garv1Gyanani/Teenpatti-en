import 'package:flutter/material.dart';

import '../../features/game_table/data/repositories/game_table_repository_impl.dart';
import '../../features/game_table/domain/usecases/get_table_state_usecase.dart';
import '../../features/game_table/domain/usecases/perform_player_action_usecase.dart';
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
import '../../features/profile_setup/data/repositories/profile_setup_repository_impl.dart';
import '../../features/profile_setup/domain/usecases/get_avatar_options_usecase.dart';
import '../../features/profile_setup/domain/usecases/save_user_profile_usecase.dart';
import '../../features/profile_setup/presentation/controllers/profile_setup_controller.dart';
import '../../features/profile_setup/presentation/pages/profile_setup_page.dart';
import '../../features/splash/data/repositories/splash_repository_impl.dart';
import '../../features/splash/domain/usecases/initialize_app_usecase.dart';
import '../../features/splash/presentation/controllers/splash_controller.dart';
import '../../features/splash/presentation/pages/splash_page.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String landing = '/landing';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String gameTable = '/game-table';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SplashPage(
            controller: SplashController(
              initializeAppUseCase: const InitializeAppUseCase(
                repository: SplashRepositoryImpl(),
              ),
            ),
          ),
        );
      case landing:
        return _fadeRoute(
          settings: settings,
          child: LandingPage(
            controller: LandingController(
              enterAsGuestUseCase: const EnterAsGuestUseCase(
                repository: LandingRepositoryImpl(),
              ),
            ),
          ),
        );
      case profileSetup:
        const profileRepository = ProfileSetupRepositoryImpl();
        return _fadeRoute(
          settings: settings,
          child: ProfileSetupPage(
            controller: ProfileSetupController(
              getAvatarOptionsUseCase: const GetAvatarOptionsUseCase(
                repository: profileRepository,
              ),
              saveUserProfileUseCase: const SaveUserProfileUseCase(
                repository: profileRepository,
              ),
            ),
          ),
        );
      case home:
        return _fadeRoute(
          settings: settings,
          child: _buildHomePage(),
        );
      case gameTable:
        const gameTableRepository = GameTableRepositoryImpl();
        return _fadeRoute(
          settings: settings,
          child: GameTablePage(
            controller: GameTableController(
              getTableStateUseCase: const GetTableStateUseCase(
                repository: gameTableRepository,
              ),
              performPlayerActionUseCase: const PerformPlayerActionUseCase(
                repository: gameTableRepository,
              ),
            ),
          ),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _buildHomePage(),
        );
    }
  }

  static HomePage _buildHomePage() {
    const homeRepository = HomeRepositoryImpl();
    return HomePage(
      controller: HomeController(
        getDashboardUseCase: const GetHomeDashboardUseCase(
          repository: homeRepository,
        ),
        claimDailyRewardUseCase: const ClaimDailyRewardUseCase(
          repository: homeRepository,
        ),
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
}
