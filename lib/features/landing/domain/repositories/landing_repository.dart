/// Contract for starting a guest session from the landing screen.
abstract interface class LandingRepository {
  Future<void> enterAsGuest();
}

