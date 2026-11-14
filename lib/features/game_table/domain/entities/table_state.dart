import 'round_result.dart';
import 'table_player.dart';

enum PlayerTableAction { pack, sideShow, blind, chaal, show }

/// Snapshot of the active Teen Patti table state.
class TableState {
  const TableState({
    required this.tableName,
    required this.minStake,
    required this.maxStake,
    required this.potAmount,
    required this.blindAmount,
    required this.chaalAmount,
    required this.players,
    this.lastActionLabel,
    this.roundResult,
  });

  final String tableName;
  final int minStake;
  final int maxStake;
  final int potAmount;
  final int blindAmount;
  final int chaalAmount;
  final List<TablePlayer> players;
  final String? lastActionLabel;
  final RoundResult? roundResult;

  TablePlayer get localPlayer =>
      players.firstWhere((p) => p.isLocalPlayer, orElse: () => players.first);

  TableState copyWith({
    int? potAmount,
    List<TablePlayer>? players,
    String? lastActionLabel,
    RoundResult? roundResult,
  }) {
    return TableState(
      tableName: tableName,
      minStake: minStake,
      maxStake: maxStake,
      potAmount: potAmount ?? this.potAmount,
      blindAmount: blindAmount,
      chaalAmount: chaalAmount,
      players: players ?? this.players,
      lastActionLabel: lastActionLabel ?? this.lastActionLabel,
      roundResult: roundResult ?? this.roundResult,
    );
  }
}

