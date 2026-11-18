import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/daily_rewards_data.dart';
import '../../domain/usecases/get_daily_rewards_usecase.dart';

/// Presentation controller for Daily Rewards streak & claiming.
class DailyRewardsController extends ChangeNotifier {
  DailyRewardsController({
    required GetDailyRewardsUseCase getDailyRewardsUseCase,
    AppSessionStore? sessionStore,
  })  : _getDailyRewardsUseCase = getDailyRewardsUseCase,
        _sessionStore = sessionStore {
    _sessionStore?.addListener(_onSessionChanged);
  }

  final GetDailyRewardsUseCase _getDailyRewardsUseCase;
  final AppSessionStore? _sessionStore;

  DailyRewardsData? _data;
  DailyRewardsData? get data => _data;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isDisposed = false;

  void _onSessionChanged() {
    final store = _sessionStore;
    if (_isDisposed || _isLoading || store == null) return;
    _data = store.toDailyRewardsData();
    _notifySafely();
  }

  Future<void> loadRewards() async {
    _isLoading = true;
    _notifySafely();

    try {
      _data = await _getDailyRewardsUseCase();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  /// Returns the 4 visible cards (Day 4 through Day 7) matching the layout.
  List<DailyRewardDay> get featuredDays {
    final all = _data?.days ?? const [];
    if (all.length <= 4) return all;
    return all.sublist(all.length - 4);
  }

  int? claimTodayReward() {
    final current = _data;
    if (current == null || current.isTodayClaimed) return null;

    final store = _sessionStore;
    if (store != null) {
      if (store.isDailyRewardClaimedToday()) return null;
      final amount = store.todayDailyRewardAmount;
      unawaited(store.claimDailyReward());
      _data = store.toDailyRewardsData();
      _notifySafely();
      return amount;
    }

    final todayReward = current.days.firstWhere(
      (d) => d.status == DailyRewardCardStatus.current,
      orElse: () => current.days[4],
    );

    _data = current.copyWith(
      isTodayClaimed: true,
      totalRewardsEarned: current.totalRewardsEarned + todayReward.amount,
    );
    _notifySafely();
    return todayReward.amount;
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
