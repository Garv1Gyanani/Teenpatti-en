import '../entities/table_state.dart';

/// Contract for fetching and updating Teen Patti table state.
abstract interface class GameTableRepository {
  Future<TableState> getInitialTableState();
  Future<TableState> performAction({
    required TableState currentState,
    required PlayerTableAction action,
  });
}

