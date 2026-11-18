import '../../../../core/constants/app_assets.dart';
import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/friend_member.dart';
import '../../domain/repositories/friends_repository.dart';

/// [FriendsRepository] backed by [AppSessionStore] and Supabase `tp_friendships`
/// / `tp_room_invites` when provided, or baseline club defaults for standalone
/// unit tests.
class FriendsRepositoryImpl implements FriendsRepository {
  const FriendsRepositoryImpl({this.sessionStore});

  final AppSessionStore? sessionStore;

  static const List<FriendMember> _defaultFriends = <FriendMember>[
    FriendMember(
      id: 'fr_aryan',
      playerCode: 'TP901241',
      name: 'Aryan',
      avatarAsset: AppAssets.avatar2,
      isOnline: true,
      statusText: 'Online',
      isRecentlyPlayed: true,
    ),
    FriendMember(
      id: 'fr_sneha',
      playerCode: 'TP901242',
      name: 'Sneha',
      avatarAsset: AppAssets.avatar4,
      isOnline: true,
      statusText: 'Online',
      isRecentlyPlayed: true,
    ),
    FriendMember(
      id: 'fr_rohit',
      playerCode: 'TP901243',
      name: 'Rohit',
      avatarAsset: AppAssets.avatar3,
      isOnline: false,
      statusText: 'Last seen 30 min ago',
      isRecentlyPlayed: true,
    ),
    FriendMember(
      id: 'fr_meera',
      playerCode: 'TP901244',
      name: 'Meera',
      avatarAsset: AppAssets.splashCharacter,
      isOnline: false,
      statusText: 'Last seen 2 hr ago',
    ),
    FriendMember(
      id: 'fr_kabir',
      playerCode: 'TP901245',
      name: 'Kabir',
      avatarAsset: AppAssets.avatar5,
      isOnline: true,
      statusText: 'Online',
    ),
  ];

  @override
  Future<FriendsDirectory> getFriendsDirectory() async {
    final store = sessionStore;
    if (store != null) {
      await store.syncFriendsAndInvitesFromServer();
      final list = store.friends;
      final onlineCount = list.where((f) => f.isOnline).length;
      return FriendsDirectory(
        inviteCode: store.playerId,
        totalCount: list.length,
        onlineCount: onlineCount,
        friends: list,
        pendingInvites: store.pendingRoomInvites,
      );
    }

    return const FriendsDirectory(
      inviteCode: 'A7K9D4',
      totalCount: 12,
      onlineCount: 5,
      friends: _defaultFriends,
    );
  }
}
