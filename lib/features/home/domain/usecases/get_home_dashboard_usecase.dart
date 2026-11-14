import '../entities/player_dashboard.dart';
import '../repositories/home_repository.dart';

/// Loads the player's Home dashboard data.
class GetHomeDashboardUseCase {
  const GetHomeDashboardUseCase({
    required HomeRepository repository,
  }) : _repository = repository;

  final HomeRepository _repository;

  Future<PlayerDashboard> call() => _repository.getDashboard();
}

