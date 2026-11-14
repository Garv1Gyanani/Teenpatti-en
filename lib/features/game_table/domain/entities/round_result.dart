import 'table_player.dart';

/// Represents the outcome of a completed Teen Patti hand.
class RoundResult {
  const RoundResult({
    required this.wonAmount,
    required this.previousBalance,
    required this.newBalance,
    required this.handLabel,
    required this.winner,
    required this.packedOpponents,
  });

  final int wonAmount;
  final int previousBalance;
  final int newBalance;
  final String handLabel;
  final TablePlayer winner;
  final List<TablePlayer> packedOpponents;
}

