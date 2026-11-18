import '../../../../core/constants/app_assets.dart';
import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/friend_preview.dart';
import '../../domain/entities/game_mode_item.dart';
import '../../domain/entities/player_dashboard.dart';
import '../../domain/repositories/home_repository.dart';

/// [HomeRepository] backed by [AppSessionStore] when provided, or baseline
/// club defaults for standalone unit tests.
class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl({this.sessionStore});

  final AppSessionStore? sessionStore;

  static const int _fallbackDailyRewardAmount = 2500;

  static const List<GameModeItem> _gameModes = [
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
  ];

  static const List<FriendPreview> _friends = [
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
  ];

  @override
  Future<PlayerDashboard> getDashboard() async {
    final store = sessionStore;
    if (store != null) {
      final friendPreviews = store.friends.isNotEmpty
          ? store.friends
              .take(4)
              .map(
                (f) => FriendPreview(
                  id: f.id,
                  name: f.name,
                  avatarAsset: f.avatarAsset,
                  isOnline: f.isOnline,
                ),
              )
              .toList(growable: false)
          : _friends;
      return PlayerDashboard(
        playerName: store.displayName,
        avatarAsset: store.avatarAsset,
        level: store.level,
        levelProgress: store.levelProgress,
        chips: store.chips,
        hasUnreadNotifications: true,
        isDailyRewardClaimed: store.isDailyRewardClaimedToday(),
        dailyRewardAmount: store.todayDailyRewardAmount,
        gameModes: _gameModes,
        friends: friendPreviews,
      );
    }

    return const PlayerDashboard(
      playerName: 'Garv',
      avatarAsset: AppAssets.splashCharacter,
      level: 12,
      levelProgress: 0.62,
      chips: 25000,
      hasUnreadNotifications: true,
      isDailyRewardClaimed: false,
      dailyRewardAmount: _fallbackDailyRewardAmount,
      gameModes: _gameModes,
      friends: _friends,
    );
  }

  @override
  Future<int> claimDailyReward() async {
    final store = sessionStore;
    if (store != null) {
      final claimed = await store.claimDailyReward();
      return claimed ?? 0;
    }
    return _fallbackDailyRewardAmount;
  }
}
