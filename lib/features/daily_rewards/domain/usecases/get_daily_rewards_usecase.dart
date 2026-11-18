import '../entities/daily_rewards_data.dart';
import '../repositories/daily_rewards_repository.dart';

class GetDailyRewardsUseCase {
  const GetDailyRewardsUseCase({required DailyRewardsRepository repository})
      : _repository = repository;

  final DailyRewardsRepository _repository;

  Future<DailyRewardsData> call() => _repository.getDailyRewards();
}
