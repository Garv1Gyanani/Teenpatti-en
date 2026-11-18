import 'bot_profile_params.dart';
import 'seat_observation.dart';
import 'table_player.dart';
import 'table_state.dart';

/// Decision output from an automated participant (offline bot or online AI agent).
class AgentTurnDecision {
  const AgentTurnDecision({
    required this.action,
    this.raiseStake = false,
  });

  final PlayerTableAction action;
  final bool raiseStake;
}

/// Pure observation-isolated decision contract requiring a viewer-masked
/// [SeatObservation] and [BotProfileParams], preventing card peeking/collusion.
abstract interface class SeatAgent {
  /// Returns `true` if a currently blind participant chooses to look at their
  /// cards before taking this turn.
  Future<bool> shouldSeeCardsForObservation({
    required SeatObservation observation,
    required BotProfileParams profile,
  });

  /// Picks a legal [PlayerTableAction] (and optional stake raise) strictly from
  /// [observation].
  Future<AgentTurnDecision> decideActionForObservation({
    required SeatObservation observation,
    required BotProfileParams profile,
  });

  /// Returns `true` to accept an incoming Side Show, or `false` to decline.
  Future<bool> decideSideShowResponseForObservation({
    required SeatObservation observation,
    required BotProfileParams profile,
  });
}

/// Legacy adapter contract used by local offline table orchestration.
abstract interface class TablePlayerAgent {
  /// Returns `true` if a currently blind participant [self] chooses to look at
  /// their cards before taking this turn.
  Future<bool> shouldSeeCards({
    required TableState state,
    required TablePlayer self,
  });

  /// Picks a legal [PlayerTableAction] (and optional stake raise) for [self].
  Future<AgentTurnDecision> decideAction({
    required TableState state,
    required TablePlayer self,
  });

  /// Returns `true` to accept an incoming Side Show from [requester], or
  /// `false` to decline.
  Future<bool> decideSideShowResponse({
    required TableState state,
    required TablePlayer self,
    required TablePlayer requester,
  });
}
