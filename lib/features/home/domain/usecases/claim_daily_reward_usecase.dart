import '../repositories/home_repository.dart';

/// Claims the player's daily chip reward and returns the awarded chip amount.
class ClaimDailyRewardUseCase {
  const ClaimDailyRewardUseCase({
    required HomeRepository repository,
  }) : _repository = repository;

  final HomeRepository _repository;

  Future<int> call() => _repository.claimDailyReward();
}

