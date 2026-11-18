enum DailyRewardCardStatus {
  claimed,
  current,
  locked,
}

class DailyRewardDay {
  const DailyRewardDay({
    required this.dayNumber,
    required this.amount,
    required this.status,
    this.isGrandBonus = false,
  });

  final int dayNumber;
  final int amount;
  final DailyRewardCardStatus status;
  final bool isGrandBonus;

  DailyRewardDay copyWith({DailyRewardCardStatus? status}) {
    return DailyRewardDay(
      dayNumber: dayNumber,
      amount: amount,
      status: status ?? this.status,
      isGrandBonus: isGrandBonus,
    );
  }
}

class DailyRewardsData {
  const DailyRewardsData({
    required this.currentStreakDays,
    required this.nextRewardDay,
    required this.nextRewardAmount,
    required this.totalRewardsEarned,
    required this.streakRecordDays,
    required this.isTodayClaimed,
    required this.days,
  });

  final int currentStreakDays;
  final int nextRewardDay;
  final int nextRewardAmount;
  final int totalRewardsEarned;
  final int streakRecordDays;
  final bool isTodayClaimed;
  final List<DailyRewardDay> days;

  DailyRewardsData copyWith({
    int? currentStreakDays,
    int? totalRewardsEarned,
    bool? isTodayClaimed,
    List<DailyRewardDay>? days,
  }) {
    return DailyRewardsData(
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      nextRewardDay: nextRewardDay,
      nextRewardAmount: nextRewardAmount,
      totalRewardsEarned: totalRewardsEarned ?? this.totalRewardsEarned,
      streakRecordDays: streakRecordDays,
      isTodayClaimed: isTodayClaimed ?? this.isTodayClaimed,
      days: days ?? this.days,
    );
  }
}
