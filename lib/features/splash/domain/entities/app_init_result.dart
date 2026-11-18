/// Represents the outcome of initial application bootstrap during splash.
class AppInitResult {
  const AppInitResult({
    required this.isReady,
    this.hasActiveProfile = false,
  });

  final bool isReady;
  final bool hasActiveProfile;
}
