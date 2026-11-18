import '../entities/app_settings_state.dart';
import '../repositories/settings_repository.dart';

class GetSettingsUseCase {
  const GetSettingsUseCase({required SettingsRepository repository})
      : _repository = repository;

  final SettingsRepository _repository;

  Future<AppSettingsState> call() => _repository.getSettings();
}
