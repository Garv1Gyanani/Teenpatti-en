enum PerformanceMetric {
  gamesWon('Games Won'),
  chipsWon('Chips (k)'),
  winRate('Win Rate %');

  const PerformanceMetric(this.label);
  final String label;
}

class PlayerProfileData {
  const PlayerProfileData({
    required this.name,
    required this.playerId,
    required this.avatarAsset,
    required this.tierLabel,
    required this.chipBalance,
    required this.gamesPlayed,
    required this.wins,
    required this.winRatePercent,
    required this.bestStreak,
    required this.weeklyPerformance,
  });

  final String name;
  final String playerId;
  final String avatarAsset;
  final String tierLabel;
  final int chipBalance;
  final int gamesPlayed;
  final int wins;
  final double winRatePercent;
  final int bestStreak;
  final Map<PerformanceMetric, List<double>> weeklyPerformance;

  PlayerProfileData copyWith({
    String? name,
    String? avatarAsset,
  }) {
    return PlayerProfileData(
      name: name ?? this.name,
      playerId: playerId,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      tierLabel: tierLabel,
      chipBalance: chipBalance,
      gamesPlayed: gamesPlayed,
      wins: wins,
      winRatePercent: winRatePercent,
      bestStreak: bestStreak,
      weeklyPerformance: weeklyPerformance,
    );
  }
}
