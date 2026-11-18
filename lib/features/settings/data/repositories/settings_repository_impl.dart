import '../../../../core/constants/app_assets.dart';
import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/app_settings_state.dart';
import '../../domain/repositories/settings_repository.dart';

/// Default [SettingsRepository] supplying Ace Society preferences.
class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl({this.sessionStore});

  final AppSessionStore? sessionStore;

  @override
  Future<AppSettingsState> getSettings() async {
    final store = sessionStore;
    if (store != null) {
      return store.toSettingsState();
    }

    return const AppSettingsState(
      soundEffects: true,
      backgroundMusic: true,
      vibration: true,
      playerName: 'Garv Gyanani',
      playerId: 'TP458732',
      avatarAsset: AppAssets.avatar2,
    );
  }
}
