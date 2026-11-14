import '../../../../core/constants/app_assets.dart';
import '../../domain/entities/avatar_option.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_setup_repository.dart';

/// Default [ProfileSetupRepository] supplying curated avatars and local save.
class ProfileSetupRepositoryImpl implements ProfileSetupRepository {
  const ProfileSetupRepositoryImpl();

  @override
  List<AvatarOption> getAvatarOptions() {
    return const [
      AvatarOption(
        id: 'avatar_1',
        assetPath: AppAssets.splashCharacter,
        label: 'Ace Queen',
      ),
      AvatarOption(
        id: 'avatar_2',
        assetPath: AppAssets.avatar2,
        label: 'Cool Maverick',
      ),
      AvatarOption(
        id: 'avatar_3',
        assetPath: AppAssets.avatar3,
        label: 'Cap Strategist',
      ),
      AvatarOption(
        id: 'avatar_4',
        assetPath: AppAssets.avatar4,
        label: 'Velvet Ace',
      ),
      AvatarOption(
        id: 'avatar_5',
        assetPath: AppAssets.avatar5,
        label: 'Gentleman Shark',
      ),
    ];
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    // Hook local storage or backend profile sync here.
  }
}

