import '../entities/table_state.dart';

/// Abstraction for offline and online Teen Patti table engines.
abstract interface class GameTableRepository {
  /// Deals the initial Teen Patti hand and returns the starting [TableState].
  Future<TableState> getInitialTableState();

  /// Deals a fresh round carrying forward player stacks and rotating dealer.
  Future<TableState> dealNewHand({
    required TableState currentState,
  });

  /// Reveals [playerId]'s dealt cards to them (transitions from Blind to Seen).
  Future<TableState> seeCards({
    required TableState currentState,
    required String playerId,
  });

  /// Executes [action] for [playerId] and updates table pot/turns/winner.
  Future<TableState> performAction({
    required TableState currentState,
    required PlayerTableAction action,
    String? playerId,
    bool raiseStake = false,
  });

  /// Resolves a pending Side Show request with [accepted].
  Future<TableState> resolveSideShow({
    required TableState currentState,
    required bool accepted,
  });

  /// Runs one turn for the currently active automated participant
  /// ([ParticipantKind.clientBot] or [ParticipantKind.onlineAgent]).
  Future<TableState> performAutomatedTurn({
    required TableState currentState,
  });
}
