import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/app_init_result.dart';
import '../../domain/repositories/splash_repository.dart';

/// Bootstraps local & remote session state during app startup.
class SplashRepositoryImpl implements SplashRepository {
  const SplashRepositoryImpl({this.sessionStore});

  final AppSessionStore? sessionStore;

  @override
  Future<AppInitResult> initializeApp() async {
    final store = sessionStore;
    if (store != null) {
      if (!store.isHydrated) {
        await store.hydrate();
      }
      return AppInitResult(
        isReady: true,
        hasActiveProfile: store.hasCompletedOnboarding,
      );
    }
    return const AppInitResult(isReady: true);
  }
}
