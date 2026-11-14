import '../entities/friend_member.dart';
import '../repositories/friends_repository.dart';

/// Loads the player's friends list and invite code.
class GetFriendsDataUseCase {
  const GetFriendsDataUseCase({
    required FriendsRepository repository,
  }) : _repository = repository;

  final FriendsRepository _repository;

  Future<FriendsDirectory> call() => _repository.getFriendsDirectory();
}
