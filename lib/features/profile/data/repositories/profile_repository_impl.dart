import '../../../../core/constants/app_assets.dart';
import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/player_profile_data.dart';
import '../../domain/repositories/profile_repository.dart';

/// Default [ProfileRepository] supplying player club stats & chart data.
class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({this.sessionStore});

  final AppSessionStore? sessionStore;

  @override
  Future<PlayerProfileData> getPlayerProfile() async {
    final store = sessionStore;
    if (store != null) {
      return store.toPlayerProfileData();
    }

    return const PlayerProfileData(
      name: 'Garv Gyanani',
      playerId: 'TP458732',
      avatarAsset: AppAssets.avatar2,
      tierLabel: 'Club Member',
      chipBalance: 124500,
      gamesPlayed: 1248,
      wins: 732,
      winRatePercent: 58.7,
      bestStreak: 12,
      weeklyPerformance: {
        PerformanceMetric.gamesWon: [5, 13, 8, 17, 12, 17, 25],
        PerformanceMetric.chipsWon: [8, 18, 11, 22, 16, 21, 28],
        PerformanceMetric.winRate: [45, 58, 52, 64, 55, 61, 72],
      },
    );
  }
}
