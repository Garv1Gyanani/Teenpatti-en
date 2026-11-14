import '../entities/player_dashboard.dart';

/// Contract for loading Home dashboard data and claiming daily rewards.
abstract interface class HomeRepository {
  Future<PlayerDashboard> getDashboard();
  Future<int> claimDailyReward();
}

