import '../entities/table_state.dart';
import '../repositories/game_table_repository.dart';

/// Advances the current automated participant's turn via [GameTableRepository].
class AdvanceAiTurnUseCase {
  const AdvanceAiTurnUseCase({
    required GameTableRepository repository,
  }) : _repository = repository;

  final GameTableRepository _repository;

  Future<TableState> call({required TableState currentState}) {
    return _repository.performAutomatedTurn(currentState: currentState);
  }
}
