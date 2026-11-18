enum FriendsFilterTab { all, online, recentlyPlayed }

/// Represents a friend in the player's Ace Society circle.
class FriendMember {
  const FriendMember({
    required this.id,
    required this.name,
    required this.avatarAsset,
    required this.isOnline,
    required this.statusText,
    this.playerCode,
    this.rating = 1000,
    this.isRecentlyPlayed = false,
    this.activeRoomCode,
  });

  factory FriendMember.fromJson(Map<String, dynamic> json) {
    final id = (json['friend_id'] as String?) ??
        (json['id'] as String?) ??
        'friend_unknown';
    final isOnline = (json['is_online'] as bool?) ??
        (json['isOnline'] as bool?) ??
        false;
    return FriendMember(
      id: id,
      playerCode:
          (json['player_code'] as String?) ?? (json['playerCode'] as String?),
      name: (json['display_name'] as String?) ??
          (json['name'] as String?) ??
          'Club Player',
      avatarAsset: (json['avatar_asset'] as String?) ??
          (json['avatarAsset'] as String?) ??
          'assets/images/avatar_2.png',
      rating: (json['rating'] as num?)?.toInt() ?? 1000,
      isOnline: isOnline,
      statusText: (json['status_text'] as String?) ??
          (json['statusText'] as String?) ??
          (isOnline ? 'Online' : 'Offline'),
      isRecentlyPlayed: (json['is_recently_played'] as bool?) ??
          (json['isRecentlyPlayed'] as bool?) ??
          false,
      activeRoomCode: (json['active_room_code'] as String?) ??
          (json['activeRoomCode'] as String?),
    );
  }

  final String id;
  final String? playerCode;
  final String name;
  final String avatarAsset;
  final int rating;
  final bool isOnline;
  final String statusText;
  final bool isRecentlyPlayed;
  final String? activeRoomCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        if (playerCode != null) 'playerCode': playerCode,
        'name': name,
        'avatarAsset': avatarAsset,
        'rating': rating,
        'isOnline': isOnline,
        'statusText': statusText,
        'isRecentlyPlayed': isRecentlyPlayed,
        if (activeRoomCode != null) 'activeRoomCode': activeRoomCode,
      };
}

/// Represents a live in-app table invite sent by a friend.
class TableRoomInvite {
  const TableRoomInvite({
    required this.id,
    required this.roomCode,
    required this.tableName,
    required this.variant,
    required this.minStake,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.createdAt,
    this.roomId,
  });

  factory TableRoomInvite.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'] as String?;
    return TableRoomInvite(
      id: (json['invite_id'] as String?) ??
          (json['id'] as String?) ??
          'inv_0',
      roomId: (json['room_id'] as String?) ?? (json['roomId'] as String?),
      roomCode: (json['room_code'] as String?) ??
          (json['roomCode'] as String?) ??
          '',
      tableName: (json['table_name'] as String?) ??
          (json['tableName'] as String?) ??
          'Private Club',
      variant: (json['variant'] as String?) ?? 'Classic',
      minStake: (json['min_stake'] as num?)?.toInt() ??
          (json['minStake'] as num?)?.toInt() ??
          100,
      senderId:
          (json['sender_id'] as String?) ?? (json['senderId'] as String?) ?? '',
      senderName: (json['sender_name'] as String?) ??
          (json['senderName'] as String?) ??
          'Club Friend',
      senderAvatar: (json['sender_avatar'] as String?) ??
          (json['senderAvatar'] as String?) ??
          'assets/images/avatar_2.png',
      createdAt: createdRaw != null
          ? DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String id;
  final String? roomId;
  final String roomCode;
  final String tableName;
  final String variant;
  final int minStake;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final DateTime createdAt;
}

/// Aggregated Friends screen data including invite code, friend list, and
/// pending table invitations.
class FriendsDirectory {
  const FriendsDirectory({
    required this.inviteCode,
    required this.totalCount,
    required this.onlineCount,
    required this.friends,
    this.pendingInvites = const <TableRoomInvite>[],
  });

  final String inviteCode;
  final int totalCount;
  final int onlineCount;
  final List<FriendMember> friends;
  final List<TableRoomInvite> pendingInvites;
}
