import 'package:flutter/foundation.dart';

import '../../domain/usecases/initialize_app_usecase.dart';

enum SplashStatus { initial, loading, completed, error }

/// Presentation controller for the splash screen.
///
/// Depends only on [InitializeAppUseCase] from the domain layer.
class SplashController extends ChangeNotifier {
  SplashController({
    required InitializeAppUseCase initializeAppUseCase,
  }) : _initializeAppUseCase = initializeAppUseCase;

  final InitializeAppUseCase _initializeAppUseCase;

  SplashStatus _status = SplashStatus.initial;
  SplashStatus get status => _status;

  bool _isDisposed = false;

  Future<void> initialize() async {
    if (_status == SplashStatus.loading || _status == SplashStatus.completed) {
      return;
    }

    _setStatus(SplashStatus.loading);
    try {
      final result = await _initializeAppUseCase();
      _setStatus(result.isReady ? SplashStatus.completed : SplashStatus.error);
    } catch (_) {
      _setStatus(SplashStatus.error);
    }
  }

  void _setStatus(SplashStatus next) {
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

