import 'package:flutter/foundation.dart';

import '../../domain/entities/landing_entry_mode.dart';
import '../../domain/usecases/enter_as_guest_usecase.dart';

enum LandingStatus { idle, loading, navigate, error }

/// Presentation controller for the landing screen.
class LandingController extends ChangeNotifier {
  LandingController({
    required EnterAsGuestUseCase enterAsGuestUseCase,
  }) : _enterAsGuestUseCase = enterAsGuestUseCase;

  final EnterAsGuestUseCase _enterAsGuestUseCase;

  LandingStatus _status = LandingStatus.idle;
  LandingStatus get status => _status;

  LandingEntryMode? _selectedMode;
  LandingEntryMode? get selectedMode => _selectedMode;

  bool _isDisposed = false;

  Future<void> playAsGuest() async {
    if (_status == LandingStatus.loading) return;

    _selectedMode = LandingEntryMode.guest;
    _setStatus(LandingStatus.loading);

    try {
      await _enterAsGuestUseCase();
      _setStatus(LandingStatus.navigate);
    } catch (_) {
      _setStatus(LandingStatus.error);
    }
  }

  void requestSignIn() {
    if (_status == LandingStatus.loading) return;

    _selectedMode = LandingEntryMode.signIn;
    _setStatus(LandingStatus.navigate);
  }

  void resetNavigation() {
    if (_status == LandingStatus.navigate || _status == LandingStatus.error) {
      _selectedMode = null;
      _setStatus(LandingStatus.idle);
    }
  }

  void _setStatus(LandingStatus next) {
    if (_isDisposed || _status == next) return;
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

