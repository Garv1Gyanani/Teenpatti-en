import '../entities/game_table_room.dart';

/// Contract for fetching available Teen Patti table rooms.
abstract interface class TableLobbyRepository {
  Future<List<GameTableRoom>> getAvailableTables();
}

