import '../entities/avatar_option.dart';
import '../repositories/profile_setup_repository.dart';

/// Returns the list of available player avatar options.
class GetAvatarOptionsUseCase {
  const GetAvatarOptionsUseCase({
    required ProfileSetupRepository repository,
  }) : _repository = repository;

  final ProfileSetupRepository _repository;

  List<AvatarOption> call() => _repository.getAvatarOptions();
}

