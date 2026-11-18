import '../entities/table_state.dart';
import '../repositories/game_table_repository.dart';

/// Accepts or declines an active Side Show request.
class ResolveSideShowUseCase {
  const ResolveSideShowUseCase({
    required GameTableRepository repository,
  }) : _repository = repository;

  final GameTableRepository _repository;

  Future<TableState> call({
    required TableState currentState,
    required bool accepted,
  }) {
    return _repository.resolveSideShow(
      currentState: currentState,
      accepted: accepted,
    );
  }
}
