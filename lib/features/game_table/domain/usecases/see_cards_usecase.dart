import '../entities/table_state.dart';
import '../repositories/game_table_repository.dart';

/// Marks a blind player as having viewed their dealt cards.
class SeeCardsUseCase {
  const SeeCardsUseCase({
    required GameTableRepository repository,
  }) : _repository = repository;

  final GameTableRepository _repository;

  Future<TableState> call({
    required TableState currentState,
    required String playerId,
  }) {
    return _repository.seeCards(
      currentState: currentState,
      playerId: playerId,
    );
  }
}
