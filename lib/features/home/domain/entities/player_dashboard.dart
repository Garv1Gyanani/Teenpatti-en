import 'friend_preview.dart';
import 'game_mode_item.dart';

/// Aggregated dashboard state for the Ace Society Home screen.
class PlayerDashboard {
  const PlayerDashboard({
    required this.playerName,
    required this.avatarAsset,
    required this.level,
    required this.levelProgress,
    required this.chips,
    required this.hasUnreadNotifications,
    required this.isDailyRewardClaimed,
    required this.dailyRewardAmount,
    required this.gameModes,
    required this.friends,
  });

  final String playerName;
  final String avatarAsset;
  final int level;
  final double levelProgress;
  final int chips;
  final bool hasUnreadNotifications;
  final bool isDailyRewardClaimed;
  final int dailyRewardAmount;
  final List<GameModeItem> gameModes;
  final List<FriendPreview> friends;

  PlayerDashboard copyWith({
    int? chips,
    bool? isDailyRewardClaimed,
    bool? hasUnreadNotifications,
  }) {
    return PlayerDashboard(
      playerName: playerName,
      avatarAsset: avatarAsset,
      level: level,
      levelProgress: levelProgress,
      chips: chips ?? this.chips,
      hasUnreadNotifications:
          hasUnreadNotifications ?? this.hasUnreadNotifications,
      isDailyRewardClaimed: isDailyRewardClaimed ?? this.isDailyRewardClaimed,
      dailyRewardAmount: dailyRewardAmount,
      gameModes: gameModes,
      friends: friends,
    );
  }
}

