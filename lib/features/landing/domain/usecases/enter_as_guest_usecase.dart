import '../repositories/landing_repository.dart';

/// Starts a guest session so the player can enter the table immediately.
class EnterAsGuestUseCase {
  const EnterAsGuestUseCase({
    required LandingRepository repository,
  }) : _repository = repository;

  final LandingRepository _repository;

  Future<void> call() => _repository.enterAsGuest();
}

