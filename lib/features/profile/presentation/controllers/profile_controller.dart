import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/session/app_session_store.dart';
import '../../../../core/utils/formatters.dart';
import '../../../wallet/domain/entities/wallet_data.dart';
import '../../domain/entities/player_profile_data.dart';
import '../../domain/usecases/get_player_profile_usecase.dart';

/// Presentation controller for the My Profile screen.
class ProfileController extends ChangeNotifier {
  ProfileController({
    required GetPlayerProfileUseCase getPlayerProfileUseCase,
    AppSessionStore? sessionStore,
  })  : _getPlayerProfileUseCase = getPlayerProfileUseCase,
        _sessionStore = sessionStore {
    _sessionStore?.addListener(_onSessionChanged);
  }

  final GetPlayerProfileUseCase _getPlayerProfileUseCase;
  final AppSessionStore? _sessionStore;

  PlayerProfileData? _profile;
  PlayerProfileData? get profile => _profile;

  PerformanceMetric _selectedMetric = PerformanceMetric.gamesWon;
  PerformanceMetric get selectedMetric => _selectedMetric;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isDisposed = false;

  static const List<String> _avatarCycle = [
    AppAssets.avatar2,
    AppAssets.avatar3,
    AppAssets.avatar4,
    AppAssets.avatar5,
    AppAssets.splashCharacter,
  ];

  static const List<String> _fallbackHistoryLines = [
    'Table #4521 • Teen Patti Classic • Won +₹8,000',
    'Table #4478 • Teen Patti Classic • Won +₹12,000',
    'Private Room #9F7K2D • 6 Players • Won +₹4,800',
    'Table #4410 • Royal Room • 2nd Place',
  ];

  void _onSessionChanged() {
    final store = _sessionStore;
    if (_isDisposed || _isLoading || store == null) return;
    _profile = store.toPlayerProfileData();
    _notifySafely();
  }

  Future<void> loadProfile() async {
    _isLoading = true;
    _notifySafely();

    try {
      _profile = await _getPlayerProfileUseCase();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void selectMetric(PerformanceMetric metric) {
    if (_selectedMetric == metric) return;
    _selectedMetric = metric;
    _notifySafely();
  }

  void updateProfile({String? name, String? avatarAsset}) {
    final current = _profile;
    if (current == null) return;

    final store = _sessionStore;
    if (store != null) {
      unawaited(
        store.updateProfileIdentity(name: name, avatarAsset: avatarAsset),
      );
      _profile = store.toPlayerProfileData();
      _notifySafely();
      return;
    }

    _profile = current.copyWith(
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : null,
      avatarAsset: avatarAsset,
    );
    _notifySafely();
  }

  List<String> get recentHistoryLines {
    final store = _sessionStore;
    if (store == null) return _fallbackHistoryLines;

    final gameEntries = store.transactions
        .where(
          (tx) =>
              tx.type == ChipTransactionType.gameWin ||
              tx.type == ChipTransactionType.gameEntry,
        )
        .take(5)
        .map((tx) {
          final sign = tx.amount >= 0 ? '+₹' : '-₹';
          return '${tx.subtitle} • ${tx.title} $sign${formatIndianNumber(tx.amount.abs())}';
        })
        .toList(growable: false);

    return gameEntries.isEmpty
        ? const ['No Teen Patti hands played yet — join a table to start!']
        : gameEntries;
  }

  List<String> get availableAvatars => _avatarCycle;

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
