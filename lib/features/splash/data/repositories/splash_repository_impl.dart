import '../../domain/entities/app_init_result.dart';
import '../../domain/repositories/splash_repository.dart';

/// Default implementation of [SplashRepository] for bootstrapping app state.
class SplashRepositoryImpl implements SplashRepository {
  const SplashRepositoryImpl();

  @override
  Future<AppInitResult> initializeApp() async {
    // Hook future startup tasks here (e.g., local storage, session check, remote config).
    return const AppInitResult(isReady: true);
  }
}

