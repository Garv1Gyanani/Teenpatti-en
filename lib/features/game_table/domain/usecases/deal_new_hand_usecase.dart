import '../entities/table_state.dart';
import '../repositories/game_table_repository.dart';

/// Deals a new Teen Patti hand while preserving player balances and rotating dealer.
class DealNewHandUseCase {
  const DealNewHandUseCase({
    required GameTableRepository repository,
  }) : _repository = repository;

  final GameTableRepository _repository;

  Future<TableState> call({required TableState currentState}) {
    return _repository.dealNewHand(currentState: currentState);
  }
}
