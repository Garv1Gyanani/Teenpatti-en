import '../entities/avatar_option.dart';
import '../entities/user_profile.dart';

/// Contract for loading avatar choices and persisting initial player profile.
abstract interface class ProfileSetupRepository {
  List<AvatarOption> getAvatarOptions();
  Future<void> saveProfile(UserProfile profile);
}

