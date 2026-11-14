import '../entities/app_init_result.dart';

/// Contract for initializing application dependencies and startup checks.
abstract interface class SplashRepository {
  Future<AppInitResult> initializeApp();
}

