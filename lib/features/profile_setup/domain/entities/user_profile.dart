/// Represents a player's configured profile before entering the game table.
class UserProfile {
  const UserProfile({
    required this.nickname,
    required this.avatarId,
    this.linkedProvider,
  });

  final String nickname;
  final String avatarId;
  final String? linkedProvider;
}

