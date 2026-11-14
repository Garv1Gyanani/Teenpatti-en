/// Represents a friend avatar shown in the Home screen Friends strip.
class FriendPreview {
  const FriendPreview({
    required this.id,
    required this.name,
    required this.avatarAsset,
    required this.isOnline,
  });

  final String id;
  final String name;
  final String avatarAsset;
  final bool isOnline;
}

