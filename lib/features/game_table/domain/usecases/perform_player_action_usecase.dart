import '../entities/table_state.dart';
import '../repositories/game_table_repository.dart';

/// Executes a Teen Patti player action (Pack, Side Show, Blind, Chaal, Show).
class PerformPlayerActionUseCase {
  const PerformPlayerActionUseCase({
    required GameTableRepository repository,
  }) : _repository = repository;

  final GameTableRepository _repository;

  Future<TableState> call({
    required TableState currentState,
    required PlayerTableAction action,
  }) {
    return _repository.performAction(
      currentState: currentState,
      action: action,
    );
  }
}

