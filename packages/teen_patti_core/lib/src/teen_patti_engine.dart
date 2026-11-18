import 'dart:math';

import 'formatters.dart';
import 'playing_card.dart';
import 'round_result.dart';
import 'table_player.dart';
import 'table_state.dart';
import 'teen_patti_hand_evaluator.dart';

/// Pure Teen Patti rules and round-transition engine supporting Classic,
/// Muflis, AK47, and Joker variants, 2x stake raises, and 4-blind turn caps.
class TeenPattiEngine {
  TeenPattiEngine({
    Random? random,
    Duration turnTimeout = const Duration(seconds: 25),
    DateTime Function()? nowUtc,
  }) : _random = random ?? Random.secure(),
       _turnTimeout = turnTimeout,
       _nowUtc = nowUtc ?? _defaultNowUtc;

  static DateTime _defaultNowUtc() => DateTime.now().toUtc();

  final Random _random;
  final Duration _turnTimeout;
  final DateTime Function() _nowUtc;

  DateTime _nextDeadline() => _nowUtc().add(_turnTimeout);

  /// Deals a fresh round, rotates dealer, collects boot stakes, draws a Joker
  /// card when [variant] is [TeenPattiVariant.joker], and sets the first
  /// active player clockwise after the dealer.
  TableState startNewRound({
    required String tableName,
    required int minStake,
    required int maxStake,
    required List<TablePlayer> players,
    required int roundNumber,
    required int dealerIndex,
    TeenPattiVariant variant = TeenPattiVariant.classic,
    int maxBlindTurns = 4,
    PlayingCard? fixedJokerCard,
    int? potLimit,
  }) {
    if (players.length < 2) {
      throw ArgumentError('At least 2 players are required for Teen Patti.');
    }

    final normalizedDealer = dealerIndex % players.length;
    final deck = PlayingCard.standardDeck()..shuffle(_random);

    final updatedPlayers = <TablePlayer>[];
    var totalBoot = 0;

    for (var i = 0; i < players.length; i++) {
      final seat = players[i];
      final startingChips =
          (!seat.isLocalPlayer && seat.isClientBot && seat.chips < minStake)
          ? maxStake * 5
          : seat.chips;
      final bootPaid = min(startingChips, minStake);
      totalBoot += bootPaid;
      final dealtCards = deck.sublist(i * 3, (i + 1) * 3);

      updatedPlayers.add(
        seat.copyWith(
          chips: startingChips - bootPaid,
          isDealer: i == normalizedDealer,
          isActiveTurn: false,
          hasPacked: false,
          hasSeenCards: false,
          cards: dealtCards,
          totalBet: bootPaid,
          lastBetAmount: bootPaid,
          blindTurnsTaken: 0,
          lastActionText: 'Boot ₹${formatIndianNumber(bootPaid)}',
        ),
      );
    }

    final jokerCard = variant == TeenPattiVariant.joker
        ? (fixedJokerCard ?? deck[players.length * 3])
        : null;

    final firstTurnIndex = (normalizedDealer + 1) % updatedPlayers.length;
    updatedPlayers[firstTurnIndex] = updatedPlayers[firstTurnIndex].copyWith(
      isActiveTurn: true,
    );

    TablePlayer? localSeat;
    for (final seat in updatedPlayers) {
      if (seat.isLocalPlayer) {
        localSeat = seat;
        break;
      }
    }
    final localBeforeBoot = localSeat == null
        ? null
        : (localSeat.chips + localSeat.totalBet);

    final startLine = jokerCard != null
        ? 'Round $roundNumber (${variant.displayName} • ${jokerCard.label} Wild) • Boot ₹${formatIndianNumber(minStake)}'
        : (variant == TeenPattiVariant.classic
              ? 'Round $roundNumber started • Boot ₹${formatIndianNumber(minStake)}'
              : 'Round $roundNumber (${variant.shortBadge}) • Boot ₹${formatIndianNumber(minStake)}');

    return TableState(
      tableName: tableName,
      minStake: minStake,
      maxStake: maxStake,
      potAmount: totalBoot,
      blindAmount: minStake,
      chaalAmount: minStake * 2,
      players: updatedPlayers,
      variant: variant,
      jokerCard: jokerCard,
      maxBlindTurns: maxBlindTurns,
      roundNumber: roundNumber,
      turnCount: 0,
      dealerIndex: normalizedDealer,
      activeTurnIndex: firstTurnIndex,
      potLimit: potLimit ?? maxStake * 2,
      localRoundStartChips: localBeforeBoot,
      turnDeadline: _nextDeadline(),
      lastActionLabel: startLine,
      roundActionLog: [startLine],
    );
  }

  /// Forces [playerId] to pack cleanly (used on timeouts, disconnects, or exit).
  TableState forfeitPlayer(
    TableState state, {
    required String playerId,
    String reasonLabel = 'Packed',
  }) {
    if (state.isRoundOver) return state;
    final actorIndex = state.players.indexWhere((p) => p.id == playerId);
    if (actorIndex < 0) return state;
    final actor = state.players[actorIndex];
    if (actor.hasPacked) return state;

    final pending = state.pendingSideShow;
    final clearsSideShow =
        pending != null &&
        (pending.requesterId == playerId || pending.targetId == playerId);
    final requesterIdx = pending == null
        ? -1
        : state.players.indexWhere((p) => p.id == pending.requesterId);

    return _packAtIndex(
      state,
      actorIndex,
      lastActionText: reasonLabel,
      actionLine: '${actor.name} packed ($reasonLabel)',
      clearPendingSideShow: clearsSideShow,
      advanceFromIndex: clearsSideShow && requesterIdx >= 0
          ? requesterIdx
          : (actor.isActiveTurn ? actorIndex : null),
    );
  }

  /// Marks [playerId] as having seen their dealt cards.
  TableState seeCards(TableState state, {required String playerId}) {
    if (state.isRoundOver) return state;

    final index = state.players.indexWhere((p) => p.id == playerId);
    if (index < 0) return state;
    final player = state.players[index];
    if (player.hasPacked || player.hasSeenCards) return state;

    final updated = [...state.players];
    updated[index] = player.copyWith(
      hasSeenCards: true,
      lastActionText: 'Seen',
    );
    final label = '${player.name} looked at their cards';

    return state.copyWith(
      players: updated,
      lastActionLabel: label,
      roundActionLog: [...state.roundActionLog, label],
    );
  }

  /// Returns the previous non-packed player in turn order before [playerId],
  /// or `null` if fewer than 2 active players exist.
  TablePlayer? previousActivePlayer(TableState state, String playerId) {
    final currentIndex = state.players.indexWhere((p) => p.id == playerId);
    if (currentIndex < 0 || state.activePlayers.length < 2) return null;

    for (var offset = 1; offset < state.players.length; offset++) {
      final idx =
          (currentIndex - offset + state.players.length) % state.players.length;
      final candidate = state.players[idx];
      if (!candidate.hasPacked && candidate.id != playerId) {
        return candidate;
      }
    }
    return null;
  }

  bool canBlind(TableState state, String playerId) {
    final player = state.findPlayerById(playerId);
    return !state.isRoundOver &&
        state.pendingSideShow == null &&
        player != null &&
        player.isActiveTurn &&
        !player.hasPacked &&
        !player.hasSeenCards &&
        player.blindTurnsTaken < state.maxBlindTurns;
  }

  bool canChaal(TableState state, String playerId) {
    final player = state.findPlayerById(playerId);
    return !state.isRoundOver &&
        state.pendingSideShow == null &&
        player != null &&
        player.isActiveTurn &&
        !player.hasPacked &&
        player.hasSeenCards;
  }

  bool canSideShow(TableState state, String playerId) {
    final player = state.findPlayerById(playerId);
    if (state.isRoundOver ||
        state.pendingSideShow != null ||
        player == null ||
        !player.isActiveTurn ||
        player.hasPacked ||
        !player.hasSeenCards ||
        state.activePlayers.length < 3) {
      return false;
    }
    final prev = previousActivePlayer(state, playerId);
    return prev != null && prev.hasSeenCards;
  }

  bool canShow(TableState state, String playerId) {
    final player = state.findPlayerById(playerId);
    return !state.isRoundOver &&
        state.pendingSideShow == null &&
        player != null &&
        player.isActiveTurn &&
        !player.hasPacked &&
        state.activePlayers.length == 2;
  }

  bool canRaiseStake(TableState state) =>
      state.chaalAmount * 2 <= state.maxStake;

  EvaluatedHand _evaluateForState(TableState state, List<PlayingCard> cards) {
    return TeenPattiHandEvaluator.evaluate(
      cards,
      variant: state.variant,
      jokerCard: state.jokerCard,
    );
  }

  /// Applies [action] for [playerId] and returns the resulting [TableState].
  TableState applyAction(
    TableState state, {
    required String playerId,
    required PlayerTableAction action,
    bool raiseStake = false,
  }) {
    if (state.isRoundOver) {
      throw StateError('Cannot perform $action after round has ended.');
    }
    if (state.pendingSideShow != null) {
      throw StateError('Resolve pending Side Show before taking another turn.');
    }

    final actorIndex = state.players.indexWhere((p) => p.id == playerId);
    if (actorIndex < 0) {
      throw ArgumentError('Player $playerId not found on table.');
    }
    final actor = state.players[actorIndex];
    if (!actor.isActiveTurn || actor.hasPacked) {
      throw StateError('It is not ${actor.name}\'s turn to act.');
    }

    switch (action) {
      case PlayerTableAction.pack:
        return _handlePack(state, actorIndex);

      case PlayerTableAction.blind:
        if (actor.hasSeenCards) {
          throw StateError(
            '${actor.name} has already seen cards and must Chaal.',
          );
        }
        if (actor.blindTurnsTaken >= state.maxBlindTurns) {
          throw StateError(
            '${actor.name} reached the ${state.maxBlindTurns}-Blind cap and must play Seen.',
          );
        }
        return _handleBet(
          state,
          actorIndex,
          isBlindBet: true,
          raiseStake: raiseStake,
        );

      case PlayerTableAction.chaal:
        return _handleBet(
          state,
          actorIndex,
          isBlindBet: false,
          raiseStake: raiseStake,
        );

      case PlayerTableAction.sideShow:
        if (!canSideShow(state, playerId)) {
          throw StateError('Side Show is not available right now.');
        }
        return _handleSideShowRequest(state, actorIndex);

      case PlayerTableAction.show:
        if (!canShow(state, playerId)) {
          throw StateError(
            'Show is only available when 2 active players remain.',
          );
        }
        return _handleShow(state, actorIndex);
    }
  }

  /// Resolves a pending Side Show once the target accepts or declines.
  TableState resolveSideShow(TableState state, {required bool accepted}) {
    final pending = state.pendingSideShow;
    if (pending == null) return state;

    final requesterIndex = state.players.indexWhere(
      (p) => p.id == pending.requesterId,
    );
    final targetIndex = state.players.indexWhere(
      (p) => p.id == pending.targetId,
    );
    if (requesterIndex < 0 || targetIndex < 0) {
      return state.copyWith(clearPendingSideShow: true);
    }

    final players = [...state.players];
    final requester = players[requesterIndex];
    final target = players[targetIndex];
    late String summaryLabel;

    if (!accepted) {
      players[targetIndex] = target.copyWith(lastActionText: 'Declined Show');
      summaryLabel = '${target.name} declined ${requester.name}\'s Side Show';
    } else {
      final cmp = TeenPattiHandEvaluator.compare(
        requester.cards,
        target.cards,
        variant: state.variant,
        jokerCard: state.jokerCard,
      );
      if (cmp > 0) {
        players[targetIndex] = target.copyWith(
          hasPacked: true,
          isActiveTurn: false,
          lastActionText: 'Side Show Lost',
        );
        players[requesterIndex] = requester.copyWith(
          lastActionText: 'Side Show Won',
        );
        summaryLabel =
            '${requester.name} won Side Show — ${target.name} packed';
      } else {
        // Under Teen Patti rules, challenger loses on exact ties too.
        players[requesterIndex] = requester.copyWith(
          hasPacked: true,
          isActiveTurn: false,
          lastActionText: 'Side Show Lost',
        );
        players[targetIndex] = target.copyWith(lastActionText: 'Side Show Won');
        summaryLabel =
            '${target.name} won Side Show — ${requester.name} packed';
      }
    }

    final cleared = state.copyWith(
      players: players,
      clearPendingSideShow: true,
      lastActionLabel: summaryLabel,
      roundActionLog: [...state.roundActionLog, summaryLabel],
    );

    if (cleared.activePlayers.length == 1) {
      return _finalizeSingleSurvivor(
        cleared,
        winReason: 'All other players packed',
      );
    }

    return _advanceTurnFrom(cleared, requesterIndex);
  }

  TableState _handlePack(TableState state, int actorIndex) {
    final actor = state.players[actorIndex];
    return _packAtIndex(
      state,
      actorIndex,
      lastActionText: 'Packed',
      actionLine: '${actor.name} packed',
      advanceFromIndex: actorIndex,
    );
  }

  TableState _packAtIndex(
    TableState state,
    int actorIndex, {
    required String lastActionText,
    required String actionLine,
    bool clearPendingSideShow = false,
    int? advanceFromIndex,
  }) {
    final players = [...state.players];
    final actor = players[actorIndex];
    players[actorIndex] = actor.copyWith(
      hasPacked: true,
      isActiveTurn: false,
      lastActionText: lastActionText,
    );

    final nextState = state.copyWith(
      players: players,
      turnCount: state.turnCount + 1,
      clearPendingSideShow: clearPendingSideShow,
      lastActionLabel: actionLine,
      roundActionLog: [...state.roundActionLog, actionLine],
    );

    if (nextState.activePlayers.length == 1) {
      return _finalizeSingleSurvivor(
        nextState,
        winReason: 'All opponents packed',
      );
    }

    if (advanceFromIndex != null) {
      return _advanceTurnFrom(nextState, advanceFromIndex);
    }
    return nextState;
  }

  TableState _handleBet(
    TableState state,
    int actorIndex, {
    required bool isBlindBet,
    required bool raiseStake,
  }) {
    var nextBlind = state.blindAmount;
    var nextChaal = state.chaalAmount;
    final didRaise = raiseStake && canRaiseStake(state);
    if (didRaise) {
      nextBlind = state.blindAmount * 2;
      nextChaal = state.chaalAmount * 2;
    }

    final players = [...state.players];
    final actor = players[actorIndex];
    final requiredStake = isBlindBet ? nextBlind : nextChaal;
    final paid = min(actor.chips, requiredStake);
    final baseVerb = isBlindBet ? 'Blind' : 'Chaal';
    final verb = didRaise ? '$baseVerb 2x' : baseVerb;
    final formattedPaid = formatIndianNumber(paid);

    players[actorIndex] = actor.copyWith(
      chips: actor.chips - paid,
      hasSeenCards: isBlindBet ? actor.hasSeenCards : true,
      isActiveTurn: false,
      totalBet: actor.totalBet + paid,
      lastBetAmount: paid,
      blindTurnsTaken: isBlindBet
          ? actor.blindTurnsTaken + 1
          : actor.blindTurnsTaken,
      lastActionText: '$verb ₹$formattedPaid',
    );

    final updatedPot = state.potAmount + paid;
    final nextTurnCount = state.turnCount + 1;
    final actionLine = '${actor.name} played $verb ₹$formattedPaid';
    final updatedState = state.copyWith(
      potAmount: updatedPot,
      blindAmount: nextBlind,
      chaalAmount: nextChaal,
      players: players,
      turnCount: nextTurnCount,
      lastActionLabel: actionLine,
      roundActionLog: [...state.roundActionLog, actionLine],
    );

    // Trigger an automatic pot-limit showdown if the table cap is reached.
    if (updatedPot >= state.potLimit || nextTurnCount >= players.length * 6) {
      return _finalizeShowdown(
        updatedState,
        challengerIndex: null,
        winReason: 'Pot Limit Showdown',
      );
    }

    return _advanceTurnFrom(updatedState, actorIndex);
  }

  TableState _handleSideShowRequest(TableState state, int actorIndex) {
    final actor = state.players[actorIndex];
    final target = previousActivePlayer(state, actor.id)!;
    final paid = min(actor.chips, state.chaalAmount);

    final players = [...state.players];
    players[actorIndex] = actor.copyWith(
      chips: actor.chips - paid,
      isActiveTurn: false,
      totalBet: actor.totalBet + paid,
      lastBetAmount: paid,
      lastActionText: 'Side Show',
    );
    final actionLine = '${actor.name} requested Side Show with ${target.name}';

    return state.copyWith(
      potAmount: state.potAmount + paid,
      players: players,
      turnCount: state.turnCount + 1,
      turnDeadline: _nextDeadline(),
      pendingSideShow: PendingSideShow(
        requesterId: actor.id,
        targetId: target.id,
        stakePaid: paid,
      ),
      lastActionLabel: actionLine,
      roundActionLog: [...state.roundActionLog, actionLine],
    );
  }

  TableState _handleShow(TableState state, int actorIndex) {
    final actor = state.players[actorIndex];
    final requiredStake = actor.hasSeenCards
        ? state.chaalAmount
        : state.blindAmount;
    final paid = min(actor.chips, requiredStake);

    final players = [...state.players];
    players[actorIndex] = actor.copyWith(
      chips: actor.chips - paid,
      isActiveTurn: false,
      totalBet: actor.totalBet + paid,
      lastBetAmount: paid,
      lastActionText: 'Show',
    );
    final showLine = '${actor.name} called Show (₹${formatIndianNumber(paid)})';

    final updated = state.copyWith(
      potAmount: state.potAmount + paid,
      players: players,
      turnCount: state.turnCount + 1,
      roundActionLog: [...state.roundActionLog, showLine],
    );

    return _finalizeShowdown(
      updated,
      challengerIndex: actorIndex,
      winReason: 'Won by Showdown',
    );
  }

  TableState _finalizeSingleSurvivor(
    TableState state, {
    required String winReason,
  }) {
    final winner = state.activePlayers.first;
    final players = state.players
        .map((player) {
          if (player.id == winner.id) {
            return player.copyWith(
              chips: player.chips + state.potAmount,
              isActiveTurn: false,
              lastActionText: 'Winner',
            );
          }
          return player.copyWith(isActiveTurn: false);
        })
        .toList(growable: false);

    final finalWinner = players.firstWhere((p) => p.id == winner.id);
    TablePlayer? finalLocalSeat;
    for (final player in players) {
      if (player.isLocalPlayer) {
        finalLocalSeat = player;
        break;
      }
    }
    final finalLocal = finalLocalSeat ?? finalWinner;
    final packedOpponents = players
        .where((p) => p.hasPacked && !p.isLocalPlayer)
        .toList(growable: false);

    final handLabel = finalWinner.hasSeenCards || finalWinner.isLocalPlayer
        ? _evaluateForState(state, finalWinner.cards).label
        : 'Uncontested Pot';
    final winLine =
        '${finalWinner.name} won ₹${formatIndianNumber(state.potAmount)} ($winReason)';

    return state.copyWith(
      players: players,
      clearTurnDeadline: true,
      clearPendingSideShow: true,
      lastActionLabel: winLine,
      roundActionLog: [...state.roundActionLog, winLine],
      roundResult: RoundResult(
        wonAmount: state.potAmount,
        previousBalance:
            state.localRoundStartChips ??
            (finalLocal.chips + finalLocal.totalBet),
        newBalance: finalLocal.chips,
        handLabel: handLabel,
        winner: finalWinner,
        packedOpponents: packedOpponents,
        showdownHands: [
          ShowdownHandSummary(
            player: finalWinner,
            handLabel: handLabel,
            isWinner: true,
          ),
        ],
        winReason: winReason,
      ),
    );
  }

  TableState _finalizeShowdown(
    TableState state, {
    required int? challengerIndex,
    required String winReason,
  }) {
    final contenders = state.activePlayers;
    TablePlayer winner = contenders.first;
    var winnerEval = _evaluateForState(state, winner.cards);
    var tiedShow = false;

    for (var i = 1; i < contenders.length; i++) {
      final candidate = contenders[i];
      final candidateEval = _evaluateForState(state, candidate.cards);
      final cmp = candidateEval.compareTo(winnerEval);

      if (cmp > 0) {
        winner = candidate;
        winnerEval = candidateEval;
        tiedShow = false;
      } else if (cmp == 0) {
        tiedShow = true;
        // Under Teen Patti rules, if the challenger ties in a Show,
        // the non-challenger takes precedence.
        if (challengerIndex != null &&
            winner.id == state.players[challengerIndex].id) {
          winner = candidate;
          winnerEval = candidateEval;
        }
      }
    }

    final players = state.players
        .map((player) {
          final isWinner = player.id == winner.id;
          return player.copyWith(
            chips: isWinner ? player.chips + state.potAmount : player.chips,
            isActiveTurn: false,
            hasSeenCards: !player.hasPacked ? true : player.hasSeenCards,
            lastActionText: isWinner
                ? 'Winner'
                : (player.hasPacked ? player.lastActionText : 'Lost Show'),
          );
        })
        .toList(growable: false);

    final finalWinner = players.firstWhere((p) => p.id == winner.id);
    TablePlayer? finalLocalSeat;
    for (final player in players) {
      if (player.isLocalPlayer) {
        finalLocalSeat = player;
        break;
      }
    }
    final finalLocal = finalLocalSeat ?? finalWinner;
    final packedOpponents = players
        .where((p) => p.hasPacked && !p.isLocalPlayer)
        .toList(growable: false);

    final showdownHands =
        players
            .where((p) => !p.hasPacked)
            .map(
              (p) => ShowdownHandSummary(
                player: p,
                handLabel: _evaluateForState(state, p.cards).label,
                isWinner: p.id == finalWinner.id,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.isWinner ? -1 : (b.isWinner ? 1 : 0));

    final effectiveReason = tiedShow
        ? 'Tie-breaker Win ($winReason)'
        : winReason;
    final winLine =
        '${finalWinner.name} won ₹${formatIndianNumber(state.potAmount)} with ${winnerEval.label}';

    return state.copyWith(
      players: players,
      clearTurnDeadline: true,
      clearPendingSideShow: true,
      lastActionLabel: winLine,
      roundActionLog: [...state.roundActionLog, winLine],
      roundResult: RoundResult(
        wonAmount: state.potAmount,
        previousBalance:
            state.localRoundStartChips ??
            (finalLocal.chips + finalLocal.totalBet),
        newBalance: finalLocal.chips,
        handLabel: winnerEval.label,
        winner: finalWinner,
        packedOpponents: packedOpponents,
        showdownHands: showdownHands,
        winReason: effectiveReason,
      ),
    );
  }

  TableState _advanceTurnFrom(TableState state, int fromIndex) {
    final total = state.players.length;
    var nextIndex = fromIndex;

    for (var offset = 1; offset <= total; offset++) {
      final idx = (fromIndex + offset) % total;
      if (!state.players[idx].hasPacked) {
        nextIndex = idx;
        break;
      }
    }

    final nextSeat = state.players[nextIndex];
    final reachedBlindCap =
        !nextSeat.hasSeenCards &&
        nextSeat.blindTurnsTaken >= state.maxBlindTurns;

    final updated = [
      for (var i = 0; i < total; i++)
        if (i == nextIndex && reachedBlindCap)
          state.players[i].copyWith(
            isActiveTurn: true,
            hasSeenCards: true,
            lastActionText: 'Seen (${state.maxBlindTurns}-Blind Cap)',
          )
        else
          state.players[i].copyWith(isActiveTurn: i == nextIndex),
    ];

    if (reachedBlindCap) {
      final capNote =
          '${nextSeat.name} reached ${state.maxBlindTurns}-Blind limit — cards seen';
      return state.copyWith(
        players: updated,
        activeTurnIndex: nextIndex,
        turnDeadline: _nextDeadline(),
        lastActionLabel: capNote,
        roundActionLog: [...state.roundActionLog, capNote],
      );
    }

    return state.copyWith(
      players: updated,
      activeTurnIndex: nextIndex,
      turnDeadline: _nextDeadline(),
    );
  }
}
