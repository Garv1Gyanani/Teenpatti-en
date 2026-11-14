import '../../../../core/constants/app_assets.dart';
import '../../domain/entities/friend_member.dart';
import '../../domain/repositories/friends_repository.dart';

/// Default [FriendsRepository] supplying the player's invite code and circle.
class FriendsRepositoryImpl implements FriendsRepository {
  const FriendsRepositoryImpl();

  @override
  Future<FriendsDirectory> getFriendsDirectory() async {
    return const FriendsDirectory(
      inviteCode: 'A7K9D4',
      totalCount: 12,
      onlineCount: 5,
      friends: [
        FriendMember(
          id: 'fr_aryan',
          name: 'Aryan',
          avatarAsset: AppAssets.avatar2,
          isOnline: true,
          statusText: 'Online',
          isRecentlyPlayed: true,
        ),
        FriendMember(
          id: 'fr_sneha',
          name: 'Sneha',
          avatarAsset: AppAssets.avatar4,
          isOnline: true,
          statusText: 'Online',
          isRecentlyPlayed: true,
        ),
        FriendMember(
          id: 'fr_rohit',
          name: 'Rohit',
          avatarAsset: AppAssets.avatar3,
          isOnline: false,
          statusText: 'Last seen 30 min ago',
          isRecentlyPlayed: true,
        ),
        FriendMember(
          id: 'fr_meera',
          name: 'Meera',
          avatarAsset: AppAssets.splashCharacter,
          isOnline: false,
          statusText: 'Last seen 2 hr ago',
        ),
        FriendMember(
          id: 'fr_kabir',
          name: 'Kabir',
          avatarAsset: AppAssets.avatar5,
          isOnline: true,
          statusText: 'Online',
        ),
      ],
    );
  }
}
