import 'dart:async';

import '../session/app_session_store.dart';
import 'app_audio_cue.dart';
import 'audio_backend.dart';

/// App-wide audio engine synchronized with [AppSessionStore] toggles
/// (`soundEffects`, `backgroundMusic`) and live volume controls.
class AppAudioService {
  AppAudioService({
    AppSessionStore? sessionStore,
    AudioBackend? backend,
  })  : _sessionStore = sessionStore ?? AppSessionStore.instance,
        _backend = backend ?? createDefaultAudioBackend() {
    _sessionStore.addListener(_onSessionChanged);
    _lastMusicEnabled = _sessionStore.backgroundMusic;
    _lastMusicVolume = _sessionStore.musicVolume;
  }

  /// Upper gain cap applied to mastered MP3 background loops so lounge music
  /// stays comfortable underneath game SFX even at 100% slider position.
  static const double maxAmbientGain = 0.45;
  static const double _duckScale = 0.30;

  static final AppAudioService instance = AppAudioService();

  AppSessionStore _sessionStore;
  AudioBackend _backend;
  bool _userInteracted = false;
  bool _lastMusicEnabled = true;
  double _lastMusicVolume = 0.25;
  bool _isDucked = false;
  Timer? _duckTimer;

  /// Effective Web/Native gain currently applied to the ambient loop.
  double get effectiveAmbientGain {
    final base = _sessionStore.musicVolume.clamp(0.0, 1.0) * maxAmbientGain;
    return (_isDucked ? base * _duckScale : base).clamp(0.0, 1.0);
  }

  /// Rebinds the singleton in unit/widget tests to observe calls or silence I/O.
  void configureForTest({
    required AppSessionStore sessionStore,
    required AudioBackend backend,
  }) {
    _sessionStore.removeListener(_onSessionChanged);
    _duckTimer?.cancel();
    _sessionStore = sessionStore;
    _backend = backend;
    _userInteracted = true;
    _isDucked = false;
    _lastMusicEnabled = _sessionStore.backgroundMusic;
    _lastMusicVolume = _sessionStore.musicVolume;
    _sessionStore.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    final musicEnabled = _sessionStore.backgroundMusic;
    final musicVolume = _sessionStore.musicVolume;
    final toggleChanged = musicEnabled != _lastMusicEnabled;
    final volumeChanged = musicVolume != _lastMusicVolume;
    if (!toggleChanged && !volumeChanged) return;

    _lastMusicEnabled = musicEnabled;
    _lastMusicVolume = musicVolume;

    if (toggleChanged) {
      if (musicEnabled) {
        if (_userInteracted) {
          unawaited(
            _backend.startLoop(
              AppAudioCue.ambientLoopAsset,
              volume: effectiveAmbientGain,
            ),
          );
        }
      } else {
        unawaited(_backend.stopLoop());
      }
      return;
    }

    if (musicEnabled && _userInteracted) {
      unawaited(_backend.setLoopVolume(effectiveAmbientGain));
    }
  }

  /// Signals that the user tapped/interacted so Web Audio autoplay restrictions
  /// unlock and ambient club music begins cleanly if enabled.
  void markUserInteracted() {
    final firstGesture = !_userInteracted;
    _userInteracted = true;
    _backend.notifyUserGesture();
    if (firstGesture && _sessionStore.backgroundMusic) {
      unawaited(
        _backend.startLoop(
          AppAudioCue.ambientLoopAsset,
          volume: effectiveAmbientGain,
        ),
      );
    }
  }

  /// Plays a single sound effect if `soundEffects` is enabled in settings,
  /// scaled by the user's [AppSessionStore.sfxVolume].
  void play(AppAudioCue cue) {
    if (!_sessionStore.soundEffects) return;
    final volume = (cue.defaultVolume * _sessionStore.sfxVolume).clamp(0.0, 1.0);
    if (volume <= 0) return;
    markUserInteracted();
    unawaited(_backend.playSfx(cue.assetPath, volume: volume));
  }

  /// Temporarily lowers ambient music volume during showdown win flourishes.
  void duckAmbientForShowdown() {
    if (!_sessionStore.backgroundMusic) return;
    _duckTimer?.cancel();
    _isDucked = true;
    unawaited(_backend.setLoopVolume(effectiveAmbientGain));
    _duckTimer = Timer(const Duration(milliseconds: 950), () {
      _isDucked = false;
      if (_sessionStore.backgroundMusic) {
        unawaited(_backend.setLoopVolume(effectiveAmbientGain));
      }
    });
  }

  void dispose() {
    _duckTimer?.cancel();
    _sessionStore.removeListener(_onSessionChanged);
    _backend.dispose();
  }
}
