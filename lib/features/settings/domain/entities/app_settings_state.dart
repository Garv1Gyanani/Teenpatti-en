/// Domain entity holding player settings & profile summary for Settings & Help.
class AppSettingsState {
  const AppSettingsState({
    required this.soundEffects,
    required this.backgroundMusic,
    required this.vibration,
    this.musicVolume = 0.25,
    this.sfxVolume = 0.85,
    required this.playerName,
    required this.playerId,
    required this.avatarAsset,
    this.linkedProvider,
  });

  final bool soundEffects;
  final bool backgroundMusic;
  final bool vibration;
  final double musicVolume;
  final double sfxVolume;
  final String playerName;
  final String playerId;
  final String avatarAsset;
  final String? linkedProvider;

  bool get isAccountLinked =>
      linkedProvider != null && linkedProvider!.trim().isNotEmpty;

  AppSettingsState copyWith({
    bool? soundEffects,
    bool? backgroundMusic,
    bool? vibration,
    double? musicVolume,
    double? sfxVolume,
    String? linkedProvider,
  }) {
    return AppSettingsState(
      soundEffects: soundEffects ?? this.soundEffects,
      backgroundMusic: backgroundMusic ?? this.backgroundMusic,
      vibration: vibration ?? this.vibration,
      musicVolume: musicVolume ?? this.musicVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      playerName: playerName,
      playerId: playerId,
      avatarAsset: avatarAsset,
      linkedProvider: linkedProvider ?? this.linkedProvider,
    );
  }
}
