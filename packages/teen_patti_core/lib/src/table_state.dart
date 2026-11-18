import 'game_variant.dart';
import 'playing_card.dart';
import 'round_result.dart';
import 'table_player.dart';

export 'game_variant.dart';

/// Actions a seated player can execute on their turn in Teen Patti.
enum PlayerTableAction { pack, sideShow, blind, chaal, show }

/// Represents an unanswered Side Show request between two seen players.
class PendingSideShow {
  const PendingSideShow({
    required this.requesterId,
    required this.targetId,
    required this.stakePaid,
  });

  final String requesterId;
  final String targetId;
  final int stakePaid;
}

/// Complete snapshot of a Teen Patti table and current hand state.
class TableState {
  const TableState({
    required this.tableName,
    required this.minStake,
    required this.maxStake,
    required this.potAmount,
    required this.blindAmount,
    required this.chaalAmount,
    required this.players,
    this.variant = TeenPattiVariant.classic,
    this.jokerCard,
    this.maxBlindTurns = 4,
    this.roundNumber = 1,
    this.turnCount = 0,
    this.dealerIndex = 0,
    this.activeTurnIndex = 0,
    this.potLimit = 6400,
    this.localRoundStartChips,
    this.turnDeadline,
    this.pendingSideShow,
    this.lastActionLabel,
    this.roundActionLog = const [],
    this.roundResult,
  });

  final String tableName;
  final int minStake;
  final int maxStake;
  final int potAmount;
  final int blindAmount;
  final int chaalAmount;
  final List<TablePlayer> players;
  final TeenPattiVariant variant;
  final PlayingCard? jokerCard;
  final int maxBlindTurns;
  final int roundNumber;
  final int turnCount;
  final int dealerIndex;
  final int activeTurnIndex;
  final int potLimit;
  final int? localRoundStartChips;

  /// Server-authoritative UTC deadline for the current turn or pending Side Show.
  final DateTime? turnDeadline;
  final PendingSideShow? pendingSideShow;
  final String? lastActionLabel;
  final List<String> roundActionLog;
  final RoundResult? roundResult;

  TablePlayer? get localPlayerOrNull {
    for (final player in players) {
      if (player.isLocalPlayer) return player;
    }
    return null;
  }

  TablePlayer get localPlayer =>
      players.firstWhere((player) => player.isLocalPlayer);

  List<TablePlayer> get activePlayers =>
      players.where((player) => !player.hasPacked).toList(growable: false);

  TablePlayer? get activeTurnPlayer {
    for (final player in players) {
      if (player.isActiveTurn && !player.hasPacked) return player;
    }
    return null;
  }

  bool get isRoundOver => roundResult != null;

  bool get isLocalPlayersTurn =>
      !isRoundOver &&
      pendingSideShow == null &&
      localPlayer.isActiveTurn &&
      !localPlayer.hasPacked;

  TablePlayer? findPlayerById(String id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  TableState copyWith({
    int? potAmount,
    int? blindAmount,
    int? chaalAmount,
    List<TablePlayer>? players,
    TeenPattiVariant? variant,
    PlayingCard? jokerCard,
    bool clearJokerCard = false,
    int? maxBlindTurns,
    int? roundNumber,
    int? turnCount,
    int? dealerIndex,
    int? activeTurnIndex,
    int? potLimit,
    int? localRoundStartChips,
    DateTime? turnDeadline,
    bool clearTurnDeadline = false,
    PendingSideShow? pendingSideShow,
    bool clearPendingSideShow = false,
    String? lastActionLabel,
    bool clearLastActionLabel = false,
    List<String>? roundActionLog,
    RoundResult? roundResult,
    bool clearRoundResult = false,
  }) {
    return TableState(
      tableName: tableName,
      minStake: minStake,
      maxStake: maxStake,
      potAmount: potAmount ?? this.potAmount,
      blindAmount: blindAmount ?? this.blindAmount,
      chaalAmount: chaalAmount ?? this.chaalAmount,
      players: players ?? this.players,
      variant: variant ?? this.variant,
      jokerCard: clearJokerCard ? null : (jokerCard ?? this.jokerCard),
      maxBlindTurns: maxBlindTurns ?? this.maxBlindTurns,
      roundNumber: roundNumber ?? this.roundNumber,
      turnCount: turnCount ?? this.turnCount,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      activeTurnIndex: activeTurnIndex ?? this.activeTurnIndex,
      potLimit: potLimit ?? this.potLimit,
      localRoundStartChips:
          localRoundStartChips ?? this.localRoundStartChips,
      turnDeadline:
          clearTurnDeadline ? null : (turnDeadline ?? this.turnDeadline),
      pendingSideShow: clearPendingSideShow
          ? null
          : (pendingSideShow ?? this.pendingSideShow),
      lastActionLabel: clearLastActionLabel
          ? null
          : (lastActionLabel ?? this.lastActionLabel),
      roundActionLog: roundActionLog ?? this.roundActionLog,
      roundResult:
          clearRoundResult ? null : (roundResult ?? this.roundResult),
    );
  }
}

/// Semantic alias emphasizing full deck & all-seat card visibility held
/// exclusively by the authoritative server worker or local offline dealer.
typedef AuthoritativeTableState = TableState;
