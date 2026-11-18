import '../entities/player_profile_data.dart';

abstract interface class ProfileRepository {
  Future<PlayerProfileData> getPlayerProfile();
}
