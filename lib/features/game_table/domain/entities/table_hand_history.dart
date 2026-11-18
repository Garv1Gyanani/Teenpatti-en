import 'game_variant.dart';
import 'playing_card.dart';
import 'round_result.dart';

/// Immutable summary of a completed Teen Patti round for the in-table
/// Hand History drawer/sheet.
class TableHandHistoryEntry {
  const TableHandHistoryEntry({
    required this.roundNumber,
    required this.variant,
    this.jokerCard,
    required this.winnerName,
    required this.winnerAvatar,
    required this.isLocalWinner,
    required this.potAmount,
    required this.localNetChips,
    required this.winningHandLabel,
    required this.winReason,
    required this.showdownHands,
    required this.actionLog,
  });

  final int roundNumber;
  final TeenPattiVariant variant;
  final PlayingCard? jokerCard;
  final String winnerName;
  final String winnerAvatar;
  final bool isLocalWinner;
  final int potAmount;
  final int localNetChips;
  final String winningHandLabel;
  final String winReason;
  final List<ShowdownHandSummary> showdownHands;
  final List<String> actionLog;
}
