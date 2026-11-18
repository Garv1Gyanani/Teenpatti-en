import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/daily_rewards_data.dart';
import '../../domain/repositories/daily_rewards_repository.dart';

/// Default [DailyRewardsRepository] supplying the 7-day reward streak state.
class DailyRewardsRepositoryImpl implements DailyRewardsRepository {
  const DailyRewardsRepositoryImpl({this.sessionStore});

  final AppSessionStore? sessionStore;

  @override
  Future<DailyRewardsData> getDailyRewards() async {
    final store = sessionStore;
    if (store != null) {
      return store.toDailyRewardsData();
    }

    return const DailyRewardsData(
      currentStreakDays: 5,
      nextRewardDay: 6,
      nextRewardAmount: 2000,
      totalRewardsEarned: 6200,
      streakRecordDays: 12,
      isTodayClaimed: false,
      days: [
        DailyRewardDay(
          dayNumber: 1,
          amount: 500,
          status: DailyRewardCardStatus.claimed,
        ),
        DailyRewardDay(
          dayNumber: 2,
          amount: 800,
          status: DailyRewardCardStatus.claimed,
        ),
        DailyRewardDay(
          dayNumber: 3,
          amount: 1000,
          status: DailyRewardCardStatus.claimed,
        ),
        DailyRewardDay(
          dayNumber: 4,
          amount: 1200,
          status: DailyRewardCardStatus.claimed,
        ),
        DailyRewardDay(
          dayNumber: 5,
          amount: 1500,
          status: DailyRewardCardStatus.current,
        ),
        DailyRewardDay(
          dayNumber: 6,
          amount: 2000,
          status: DailyRewardCardStatus.locked,
        ),
        DailyRewardDay(
          dayNumber: 7,
          amount: 3000,
          status: DailyRewardCardStatus.locked,
          isGrandBonus: true,
        ),
      ],
    );
  }
}
