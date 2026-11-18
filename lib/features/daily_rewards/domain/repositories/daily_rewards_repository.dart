import '../entities/daily_rewards_data.dart';

abstract interface class DailyRewardsRepository {
  Future<DailyRewardsData> getDailyRewards();
}
