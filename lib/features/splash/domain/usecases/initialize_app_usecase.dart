import '../entities/app_init_result.dart';
import '../repositories/splash_repository.dart';

/// Orchestrates app startup initialization while honoring a minimum display
/// duration so the splash screen transitions smoothly.
class InitializeAppUseCase {
  const InitializeAppUseCase({
    required SplashRepository repository,
    this.minimumDuration = const Duration(milliseconds: 2400),
  }) : _repository = repository;

  final SplashRepository _repository;
  final Duration minimumDuration;

  Future<AppInitResult> call() async {
    final results = await Future.wait<dynamic>([
      _repository.initializeApp(),
      Future<void>.delayed(minimumDuration),
    ]);
    return results.first as AppInitResult;
  }
}

