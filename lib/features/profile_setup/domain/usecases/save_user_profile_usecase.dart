import '../entities/user_profile.dart';
import '../repositories/profile_setup_repository.dart';

/// Validates and persists the player's initial profile.
class SaveUserProfileUseCase {
  const SaveUserProfileUseCase({
    required ProfileSetupRepository repository,
  }) : _repository = repository;

  final ProfileSetupRepository _repository;

  Future<void> call(UserProfile profile) {
    final trimmed = profile.nickname.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nickname cannot be empty.');
    }
    return _repository.saveProfile(
      UserProfile(
        nickname: trimmed,
        avatarId: profile.avatarId,
        linkedProvider: profile.linkedProvider,
      ),
    );
  }
}

