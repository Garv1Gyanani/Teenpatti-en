import '../entities/friend_member.dart';

/// Contract for loading the player's friends directory and invite code.
abstract interface class FriendsRepository {
  Future<FriendsDirectory> getFriendsDirectory();
}
