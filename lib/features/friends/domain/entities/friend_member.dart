enum FriendsFilterTab { all, online, recentlyPlayed }

/// Represents a friend in the player's Ace Society circle.
class FriendMember {
  const FriendMember({
    required this.id,
    required this.name,
    required this.avatarAsset,
    required this.isOnline,
    required this.statusText,
    this.isRecentlyPlayed = false,
  });

  final String id;
  final String name;
  final String avatarAsset;
  final bool isOnline;
  final String statusText;
  final bool isRecentlyPlayed;
}

/// Aggregated Friends screen data including invite code and friend list.
class FriendsDirectory {
  const FriendsDirectory({
    required this.inviteCode,
    required this.totalCount,
    required this.onlineCount,
    required this.friends,
  });

  final String inviteCode;
  final int totalCount;
  final int onlineCount;
  final List<FriendMember> friends;
}
