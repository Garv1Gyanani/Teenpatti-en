import '../../domain/repositories/landing_repository.dart';

/// Default [LandingRepository] implementation for guest session entry.
class LandingRepositoryImpl implements LandingRepository {
  const LandingRepositoryImpl();

  @override
  Future<void> enterAsGuest() async {
    // Hook guest profile/session creation here when backend/local storage is added.
  }
}

