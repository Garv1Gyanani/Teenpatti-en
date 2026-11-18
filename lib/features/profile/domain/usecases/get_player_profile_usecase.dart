import '../entities/player_profile_data.dart';
import '../repositories/profile_repository.dart';

class GetPlayerProfileUseCase {
  const GetPlayerProfileUseCase({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  Future<PlayerProfileData> call() => _repository.getPlayerProfile();
}
