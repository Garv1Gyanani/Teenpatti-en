import '../../../../core/constants/app_assets.dart';
import '../../domain/entities/friend_preview.dart';
import '../../domain/entities/game_mode_item.dart';
import '../../domain/entities/player_dashboard.dart';
import '../../domain/repositories/home_repository.dart';

/// Default [HomeRepository] supplying initial Ace Society dashboard data.
class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl();

  static const int _dailyRewardAmount = 2500;

  @override
  Future<PlayerDashboard> getDashboard() async {
    return const PlayerDashboard(
      playerName: 'Garv',
      avatarAsset: AppAssets.splashCharacter,
      level: 12,
      levelProgress: 0.62,
      chips: 25000,
      hasUnreadNotifications: true,
      isDailyRewardClaimed: false,
      dailyRewardAmount: _dailyRewardAmount,
      gameModes: [
        GameModeItem(
          type: GameModeType.classic,
          title: 'Teen Patti\nClassic',
        ),
        GameModeItem(
          type: GameModeType.privateTable,
          title: 'Private\nTable',
        ),
        GameModeItem(
          type: GameModeType.practice,
          title: 'Practice\nMode',
        ),
        GameModeItem(
          type: GameModeType.variants,
          title: 'Variants',
          subtitle: '(Muflis, AK47)',
        ),
      ],
      friends: [
        FriendPreview(
          id: 'f1',
          name: 'Aarav',
          avatarAsset: AppAssets.avatar2,
          isOnline: true,
        ),
        FriendPreview(
          id: 'f2',
          name: 'Meera',
          avatarAsset: AppAssets.avatar4,
          isOnline: true,
        ),
        FriendPreview(
          id: 'f3',
          name: 'Kabir',
          avatarAsset: AppAssets.avatar3,
          isOnline: true,
        ),
        FriendPreview(
          id: 'f4',
          name: 'Rohan',
          avatarAsset: AppAssets.avatar5,
          isOnline: true,
        ),
      ],
    );
  }

  @override
  Future<int> claimDailyReward() async {
    return _dailyRewardAmount;
  }
}

