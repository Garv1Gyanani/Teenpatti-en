import '../entities/table_state.dart';
import '../repositories/game_table_repository.dart';

/// Executes a player's Teen Patti turn action against [GameTableRepository].
class PerformPlayerActionUseCase {
  const PerformPlayerActionUseCase({
    required GameTableRepository repository,
  }) : _repository = repository;

  final GameTableRepository _repository;

  Future<TableState> call({
    required TableState currentState,
    required PlayerTableAction action,
    String? playerId,
    bool raiseStake = false,
  }) {
    return _repository.performAction(
      currentState: currentState,
      action: action,
      playerId: playerId,
      raiseStake: raiseStake,
    );
  }
}
