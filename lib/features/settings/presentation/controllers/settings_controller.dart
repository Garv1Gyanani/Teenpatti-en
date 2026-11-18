import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/session/app_session_store.dart';
import '../../../../core/session/supabase_sync_client.dart';
import '../../domain/entities/app_settings_state.dart';
import '../../domain/usecases/get_settings_usecase.dart';

/// Presentation controller for Settings & Help preferences.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required GetSettingsUseCase getSettingsUseCase,
    AppSessionStore? sessionStore,
  })  : _getSettingsUseCase = getSettingsUseCase,
        _sessionStore = sessionStore {
    _sessionStore?.addListener(_onSessionChanged);
  }

  final GetSettingsUseCase _getSettingsUseCase;
  final AppSessionStore? _sessionStore;

  AppSettingsState? _state;
  AppSettingsState? get state => _state;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isDisposed = false;

  void _onSessionChanged() {
    final store = _sessionStore;
    if (_isDisposed || _isLoading || store == null) return;
    _state = store.toSettingsState();
    _notifySafely();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _notifySafely();

    try {
      _state = await _getSettingsUseCase();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void toggleSoundEffects(bool value) {
    final current = _state;
    if (current == null) return;
    final store = _sessionStore;
    if (store != null) {
      unawaited(store.updateSettings(soundEffects: value));
      _state = store.toSettingsState();
      _notifySafely();
      return;
    }
    _state = current.copyWith(soundEffects: value);
    _notifySafely();
  }

  void toggleBackgroundMusic(bool value) {
    final current = _state;
    if (current == null) return;
    final store = _sessionStore;
    if (store != null) {
      unawaited(store.updateSettings(backgroundMusic: value));
      _state = store.toSettingsState();
      _notifySafely();
      return;
    }
    _state = current.copyWith(backgroundMusic: value);
    _notifySafely();
  }

  void toggleVibration(bool value) {
    final current = _state;
    if (current == null) return;
    final store = _sessionStore;
    if (store != null) {
      unawaited(store.updateSettings(vibration: value));
      _state = store.toSettingsState();
      _notifySafely();
      return;
    }
    _state = current.copyWith(vibration: value);
    _notifySafely();
  }

  /// Updates background music volume (`0.0..1.0`); pass `persist: true` on slider commit.
  void setMusicVolume(double value, {bool persist = false}) {
    final current = _state;
    if (current == null) return;
    final clamped = value.clamp(0.0, 1.0);
    final store = _sessionStore;
    if (store != null) {
      if (persist) {
        unawaited(store.updateSettings(musicVolume: clamped));
      } else {
        store.previewAudioVolumes(musicVolume: clamped);
      }
      _state = store.toSettingsState();
      _notifySafely();
      return;
    }
    _state = current.copyWith(musicVolume: clamped);
    _notifySafely();
  }

  /// Updates sound effects volume (`0.0..1.0`); pass `persist: true` on slider commit.
  void setSfxVolume(double value, {bool persist = false}) {
    final current = _state;
    if (current == null) return;
    final clamped = value.clamp(0.0, 1.0);
    final store = _sessionStore;
    if (store != null) {
      if (persist) {
        unawaited(store.updateSettings(sfxVolume: clamped));
      } else {
        store.previewAudioVolumes(sfxVolume: clamped);
      }
      _state = store.toSettingsState();
      _notifySafely();
      return;
    }
    _state = current.copyWith(sfxVolume: clamped);
    _notifySafely();
  }

  Future<void> logout() async {
    await _sessionStore?.logout();
  }

  /// Links the current Guest session to a permanent Email & Password account.
  Future<SupabaseAuthResult> linkAccount({
    required String email,
    required String password,
  }) async {
    final store = _sessionStore;
    if (store == null) {
      final normalized = email.trim().toLowerCase();
      _state = _state?.copyWith(linkedProvider: 'Email ($normalized)');
      _notifySafely();
      return SupabaseAuthResult.success(userId: 'local', email: normalized);
    }
    final result = await store.linkGuestAccountWithEmail(
      email: email,
      password: password,
    );
    _state = store.toSettingsState();
    _notifySafely();
    return result;
  }

  /// Signs in to an existing Email & Password account from Settings.
  Future<SupabaseAuthResult> signInExistingAccount({
    required String email,
    required String password,
  }) async {
    final store = _sessionStore;
    if (store == null) {
      final normalized = email.trim().toLowerCase();
      _state = _state?.copyWith(linkedProvider: 'Email ($normalized)');
      _notifySafely();
      return SupabaseAuthResult.success(userId: 'local', email: normalized);
    }
    final result = await store.signInWithEmail(
      email: email,
      password: password,
    );
    _state = store.toSettingsState();
    _notifySafely();
    return result;
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionStore?.removeListener(_onSessionChanged);
    super.dispose();
  }
}
