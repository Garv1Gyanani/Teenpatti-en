import '../../../../core/constants/app_assets.dart';
import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/avatar_option.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_setup_repository.dart';

/// [ProfileSetupRepository] supplying curated avatars and persisting into
/// [AppSessionStore] (local storage + Supabase sync).
class ProfileSetupRepositoryImpl implements ProfileSetupRepository {
  const ProfileSetupRepositoryImpl({this.sessionStore});

  final AppSessionStore? sessionStore;

  static const List<AvatarOption> _options = [
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

  @override
  List<AvatarOption> getAvatarOptions() => _options;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final store = sessionStore;
    if (store == null) return;

    final matched = _options.firstWhere(
      (a) => a.id == profile.avatarId,
      orElse: () => _options.first,
    );

    await store.completeProfileSetup(
      nickname: profile.nickname,
      avatarAsset: matched.assetPath,
      linkedProvider: profile.linkedProvider,
    );
  }
}
