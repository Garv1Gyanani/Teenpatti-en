import 'package:flutter/foundation.dart';

import '../../domain/entities/game_mode_item.dart';
import '../../domain/entities/player_dashboard.dart';
import '../../domain/usecases/claim_daily_reward_usecase.dart';
import '../../domain/usecases/get_home_dashboard_usecase.dart';

/// Presentation controller for the Ace Society Home dashboard.
class HomeController extends ChangeNotifier {
  HomeController({
    required GetHomeDashboardUseCase getDashboardUseCase,
    required ClaimDailyRewardUseCase claimDailyRewardUseCase,
  })  : _getDashboardUseCase = getDashboardUseCase,
        _claimDailyRewardUseCase = claimDailyRewardUseCase;

  final GetHomeDashboardUseCase _getDashboardUseCase;
  final ClaimDailyRewardUseCase _claimDailyRewardUseCase;

  PlayerDashboard? _dashboard;
  PlayerDashboard? get dashboard => _dashboard;

  GameModeType _selectedMode = GameModeType.classic;
  GameModeType get selectedMode => _selectedMode;

  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isClaimingReward = false;
  bool get isClaimingReward => _isClaimingReward;

  bool _isDisposed = false;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _notifySafely();

    try {
      _dashboard = await _getDashboardUseCase();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void selectGameMode(GameModeType mode) {
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    _notifySafely();
  }

  void selectTab(int index) {
    if (_currentTabIndex == index) return;
    _currentTabIndex = index;
    _notifySafely();
  }

  void clearNotifications() {
    final current = _dashboard;
    if (current == null || !current.hasUnreadNotifications) return;
    _dashboard = current.copyWith(hasUnreadNotifications: false);
    _notifySafely();
  }

  Future<int?> claimDailyReward() async {
    final current = _dashboard;
    if (current == null || current.isDailyRewardClaimed || _isClaimingReward) {
      return null;
    }

    _isClaimingReward = true;
    _notifySafely();

    try {
      final reward = await _claimDailyRewardUseCase();
      _dashboard = current.copyWith(
        chips: current.chips + reward,
        isDailyRewardClaimed: true,
      );
      return reward;
    } finally {
      _isClaimingReward = false;
      _notifySafely();
    }
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

