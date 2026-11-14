import '../entities/table_state.dart';
import '../repositories/game_table_repository.dart';

/// Loads the initial Teen Patti table state.
class GetTableStateUseCase {
  const GetTableStateUseCase({
    required GameTableRepository repository,
  }) : _repository = repository;

  final GameTableRepository _repository;

  Future<TableState> call() => _repository.getInitialTableState();
}

