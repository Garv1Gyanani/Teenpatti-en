import 'table_player.dart';

/// Card hand details revealed at showdown for an active contender.
class ShowdownHandSummary {
  const ShowdownHandSummary({
    required this.player,
    required this.handLabel,
    required this.isWinner,
  });

  final TablePlayer player;
  final String handLabel;
  final bool isWinner;
}

/// Outcome of a completed Teen Patti round.
class RoundResult {
  const RoundResult({
    required this.wonAmount,
    required this.previousBalance,
    required this.newBalance,
    required this.handLabel,
    required this.winner,
    required this.packedOpponents,
    this.showdownHands = const [],
    this.winReason = 'Won by Showdown',
  });

  final int wonAmount;
  final int previousBalance;
  final int newBalance;
  final String handLabel;
  final TablePlayer winner;
  final List<TablePlayer> packedOpponents;
  final List<ShowdownHandSummary> showdownHands;
  final String winReason;

  bool get isLocalWinner => winner.isLocalPlayer;
}
