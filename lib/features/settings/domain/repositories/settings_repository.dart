import '../entities/app_settings_state.dart';

abstract interface class SettingsRepository {
  Future<AppSettingsState> getSettings();
}
