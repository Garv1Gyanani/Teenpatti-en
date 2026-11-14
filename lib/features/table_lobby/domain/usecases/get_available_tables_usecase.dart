import '../entities/game_table_room.dart';
import '../repositories/table_lobby_repository.dart';

/// Loads available Teen Patti tables for the lobby.
class GetAvailableTablesUseCase {
  const GetAvailableTablesUseCase({
    required TableLobbyRepository repository,
  }) : _repository = repository;

  final TableLobbyRepository _repository;

  Future<List<GameTableRoom>> call() => _repository.getAvailableTables();
}

