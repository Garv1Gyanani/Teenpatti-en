import 'playing_card.dart';
import 'table_state.dart';

/// Public view of a single seat visible to every participant at the table.
///
/// Crucially omits [ParticipantKind] and never contains opponent hole cards
/// while a hand is live.
class ObservedSeat {
  const ObservedSeat({
    required this.id,
    required this.name,
    required this.chips,
    required this.avatarAsset,
    required this.seatIndex,
    this.rating = 1000,
    this.isDealer = false,
    this.isActiveTurn = false,
    this.hasPacked = false,
    this.hasSeenCards = false,
    this.totalBet = 0,
    this.lastBetAmount = 0,
    this.blindTurnsTaken = 0,
    this.lastActionText,
    this.hasGiftBadge = false,
    this.revealedCards = const [],
  });

  final String id;
  final String name;
  final int chips;
  final String avatarAsset;
  final int seatIndex;
  final int rating;
  final bool isDealer;
  final bool isActiveTurn;
  final bool hasPacked;
  final bool hasSeenCards;
  final int totalBet;
  final int lastBetAmount;
  final int blindTurnsTaken;
  final String? lastActionText;
  final bool hasGiftBadge;

  /// Populated only for non-packed contenders after an actual showdown ends.
  final List<PlayingCard> revealedCards;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'chips': chips,
    'avatarAsset': avatarAsset,
    'seatIndex': seatIndex,
    'rating': rating,
    'isDealer': isDealer,
    'isActiveTurn': isActiveTurn,
    'hasPacked': hasPacked,
    'hasSeenCards': hasSeenCards,
    'totalBet': totalBet,
    'lastBetAmount': lastBetAmount,
    'blindTurnsTaken': blindTurnsTaken,
    if (lastActionText != null) 'lastActionText': lastActionText,
    'hasGiftBadge': hasGiftBadge,
    if (revealedCards.isNotEmpty)
      'revealedCards': revealedCards.map((c) => c.toJson()).toList(),
  };

  factory ObservedSeat.fromJson(Map<String, dynamic> json) {
    final rawRevealed = json['revealedCards'] as List<dynamic>? ?? const [];
    return ObservedSeat(
      id: json['id'] as String,
      name: json['name'] as String,
      chips: (json['chips'] as num).toInt(),
      avatarAsset: json['avatarAsset'] as String,
      seatIndex: (json['seatIndex'] as num).toInt(),
      rating: (json['rating'] as num?)?.toInt() ?? 1000,
      isDealer: json['isDealer'] as bool? ?? false,
      isActiveTurn: json['isActiveTurn'] as bool? ?? false,
      hasPacked: json['hasPacked'] as bool? ?? false,
      hasSeenCards: json['hasSeenCards'] as bool? ?? false,
      totalBet: (json['totalBet'] as num?)?.toInt() ?? 0,
      lastBetAmount: (json['lastBetAmount'] as num?)?.toInt() ?? 0,
      blindTurnsTaken: (json['blindTurnsTaken'] as num?)?.toInt() ?? 0,
      lastActionText: json['lastActionText'] as String?,
      hasGiftBadge: json['hasGiftBadge'] as bool? ?? false,
      revealedCards: List.unmodifiable(
        rawRevealed.whereType<Map<String, dynamic>>().map(PlayingCard.fromJson),
      ),
    );
  }
}

/// Information-hiding projection of an authoritative [TableState] tailored for
/// a single seat ([viewerId]).
///
/// Opponents' unrevealed hole cards never exist in this object, and [myCards] is
/// empty (`const []`) whenever the viewer is still Blind and the round is live.
class SeatObservation {
  const SeatObservation({
    required this.tableName,
    required this.viewerId,
    required this.minStake,
    required this.maxStake,
    required this.potAmount,
    required this.blindAmount,
    required this.chaalAmount,
    required this.seats,
    this.myCards = const [],
    this.variant = TeenPattiVariant.classic,
    this.jokerCard,
    this.maxBlindTurns = 4,
    this.roundNumber = 1,
    this.turnCount = 0,
    this.dealerIndex = 0,
    this.activeTurnIndex = 0,
    this.potLimit = 6400,
    this.turnDeadline,
    this.pendingSideShow,
    this.lastActionLabel,
    this.roundActionLog = const [],
    this.isRoundOver = false,
    this.winnerId,
    this.winReason,
  });

  /// Constructs a sanitized [SeatObservation] for [viewerId] from full
  /// authoritative state [state]. Throws [ArgumentError] if [viewerId] is not
  /// seated at the table.
  factory SeatObservation.fromTableState(
    AuthoritativeTableState state, {
    required String viewerId,
  }) {
    final viewerIndex = state.players.indexWhere((p) => p.id == viewerId);
    if (viewerIndex < 0) {
      throw ArgumentError('Viewer $viewerId is not seated at table.');
    }

    final viewer = state.players[viewerIndex];
    final canViewOwnCards =
        viewer.hasSeenCards || (state.isRoundOver && !viewer.hasPacked);

    return SeatObservation._fromAuthoritative(
      state,
      viewerId: viewerId,
      myCards: canViewOwnCards
          ? List<PlayingCard>.unmodifiable(viewer.cards)
          : const <PlayingCard>[],
    );
  }

  /// Constructs a broadcast-safe public [SeatObservation] from [state] with an
  /// empty [viewerId] and no private [myCards].
  factory SeatObservation.publicFromTableState(AuthoritativeTableState state) {
    return SeatObservation._fromAuthoritative(
      state,
      viewerId: '',
      myCards: const <PlayingCard>[],
    );
  }

  factory SeatObservation._fromAuthoritative(
    AuthoritativeTableState state, {
    required String viewerId,
    required List<PlayingCard> myCards,
  }) {
    final result = state.roundResult;
    final showdownRevealedIds =
        result != null && result.showdownHands.length > 1
        ? {for (final hand in result.showdownHands) hand.player.id}
        : const <String>{};

    final seats = <ObservedSeat>[];
    for (var i = 0; i < state.players.length; i++) {
      final p = state.players[i];
      final revealAtShowdown =
          state.isRoundOver && showdownRevealedIds.contains(p.id);
      seats.add(
        ObservedSeat(
          id: p.id,
          name: p.name,
          chips: p.chips,
          avatarAsset: p.avatarAsset,
          seatIndex: i,
          rating: p.rating,
          isDealer: p.isDealer,
          isActiveTurn: p.isActiveTurn,
          hasPacked: p.hasPacked,
          hasSeenCards: p.hasSeenCards,
          totalBet: p.totalBet,
          lastBetAmount: p.lastBetAmount,
          blindTurnsTaken: p.blindTurnsTaken,
          lastActionText: p.lastActionText,
          hasGiftBadge: p.hasGiftBadge,
          revealedCards: revealAtShowdown
              ? List<PlayingCard>.unmodifiable(p.cards)
              : const <PlayingCard>[],
        ),
      );
    }

    return SeatObservation(
      tableName: state.tableName,
      viewerId: viewerId,
      minStake: state.minStake,
      maxStake: state.maxStake,
      potAmount: state.potAmount,
      blindAmount: state.blindAmount,
      chaalAmount: state.chaalAmount,
      seats: List<ObservedSeat>.unmodifiable(seats),
      myCards: myCards,
      variant: state.variant,
      jokerCard: state.jokerCard,
      maxBlindTurns: state.maxBlindTurns,
      roundNumber: state.roundNumber,
      turnCount: state.turnCount,
      dealerIndex: state.dealerIndex,
      activeTurnIndex: state.activeTurnIndex,
      potLimit: state.potLimit,
      turnDeadline: state.turnDeadline,
      pendingSideShow: state.pendingSideShow,
      lastActionLabel: state.lastActionLabel,
      roundActionLog: List<String>.unmodifiable(state.roundActionLog),
      isRoundOver: state.isRoundOver,
      winnerId: result?.winner.id,
      winReason: result?.winReason,
    );
  }

  /// Reassembles a viewer-specific [SeatObservation] on the client from the
  /// public `room:{id}:public` payload and private `room:{id}:seat:{uid}` cards.
  factory SeatObservation.fromPublicAndPrivateJson({
    required Map<String, dynamic> publicJson,
    required String viewerId,
    List<PlayingCard> myCards = const [],
  }) {
    final rawSeats = publicJson['seats'] as List<dynamic>? ?? const [];
    final seats = rawSeats
        .whereType<Map<String, dynamic>>()
        .map(ObservedSeat.fromJson)
        .toList(growable: false);

    final pendingJson = publicJson['pendingSideShow'] as Map<String, dynamic>?;
    final pendingSideShow = pendingJson == null
        ? null
        : PendingSideShow(
            requesterId: pendingJson['requesterId'] as String,
            targetId: pendingJson['targetId'] as String,
            stakePaid: (pendingJson['stakePaid'] as num).toInt(),
          );

    final jokerJson = publicJson['jokerCard'] as Map<String, dynamic>?;
    final deadlineIso = publicJson['turnDeadline'] as String?;

    return SeatObservation(
      tableName: publicJson['tableName'] as String,
      viewerId: viewerId,
      minStake: (publicJson['minStake'] as num).toInt(),
      maxStake: (publicJson['maxStake'] as num).toInt(),
      potAmount: (publicJson['potAmount'] as num).toInt(),
      blindAmount: (publicJson['blindAmount'] as num).toInt(),
      chaalAmount: (publicJson['chaalAmount'] as num).toInt(),
      seats: List<ObservedSeat>.unmodifiable(seats),
      myCards: List<PlayingCard>.unmodifiable(myCards),
      variant: TeenPattiVariant.fromLabel(publicJson['variant'] as String?),
      jokerCard: jokerJson == null ? null : PlayingCard.fromJson(jokerJson),
      maxBlindTurns: (publicJson['maxBlindTurns'] as num?)?.toInt() ?? 4,
      roundNumber: (publicJson['roundNumber'] as num?)?.toInt() ?? 1,
      turnCount: (publicJson['turnCount'] as num?)?.toInt() ?? 0,
      dealerIndex: (publicJson['dealerIndex'] as num?)?.toInt() ?? 0,
      activeTurnIndex: (publicJson['activeTurnIndex'] as num?)?.toInt() ?? 0,
      potLimit: (publicJson['potLimit'] as num?)?.toInt() ?? 6400,
      turnDeadline: deadlineIso == null
          ? null
          : DateTime.parse(deadlineIso).toUtc(),
      pendingSideShow: pendingSideShow,
      lastActionLabel: publicJson['lastActionLabel'] as String?,
      roundActionLog: List<String>.unmodifiable(
        (publicJson['roundActionLog'] as List<dynamic>? ?? const [])
            .whereType<String>(),
      ),
      isRoundOver: publicJson['isRoundOver'] as bool? ?? false,
      winnerId: publicJson['winnerId'] as String?,
      winReason: publicJson['winReason'] as String?,
    );
  }

  final String tableName;
  final String viewerId;
  final int minStake;
  final int maxStake;
  final int potAmount;
  final int blindAmount;
  final int chaalAmount;
  final List<ObservedSeat> seats;
  final List<PlayingCard> myCards;
  final TeenPattiVariant variant;
  final PlayingCard? jokerCard;
  final int maxBlindTurns;
  final int roundNumber;
  final int turnCount;
  final int dealerIndex;
  final int activeTurnIndex;
  final int potLimit;
  final DateTime? turnDeadline;
  final PendingSideShow? pendingSideShow;
  final String? lastActionLabel;
  final List<String> roundActionLog;
  final bool isRoundOver;
  final String? winnerId;
  final String? winReason;

  ObservedSeat get self => seats.firstWhere((seat) => seat.id == viewerId);

  List<ObservedSeat> get activeSeats =>
      seats.where((seat) => !seat.hasPacked).toList(growable: false);

  ObservedSeat? get activeTurnSeat {
    for (final seat in seats) {
      if (seat.isActiveTurn && !seat.hasPacked) return seat;
    }
    return null;
  }

  ObservedSeat? get previousActiveSeat {
    final currentIndex = seats.indexWhere((s) => s.id == viewerId);
    if (currentIndex < 0 || activeSeats.length < 2) return null;

    for (var offset = 1; offset < seats.length; offset++) {
      final idx = (currentIndex - offset + seats.length) % seats.length;
      final candidate = seats[idx];
      if (!candidate.hasPacked && candidate.id != viewerId) {
        return candidate;
      }
    }
    return null;
  }

  bool get isMyTurn =>
      !isRoundOver &&
      pendingSideShow == null &&
      self.isActiveTurn &&
      !self.hasPacked;

  bool get canBlind =>
      isMyTurn && !self.hasSeenCards && self.blindTurnsTaken < maxBlindTurns;

  bool get canChaal => isMyTurn && self.hasSeenCards;

  bool get canSideShow {
    if (!canChaal || activeSeats.length < 3) return false;
    final prev = previousActiveSeat;
    return prev != null && prev.hasSeenCards;
  }

  bool get canShow => isMyTurn && activeSeats.length == 2;

  bool get canRaiseStake => chaalAmount * 2 <= maxStake;

  /// Serializes strictly public table state (never includes [myCards]).
  Map<String, dynamic> toPublicJson() => {
    'tableName': tableName,
    'minStake': minStake,
    'maxStake': maxStake,
    'potAmount': potAmount,
    'blindAmount': blindAmount,
    'chaalAmount': chaalAmount,
    'seats': seats.map((s) => s.toJson()).toList(growable: false),
    'variant': variant.name,
    if (jokerCard != null) 'jokerCard': jokerCard!.toJson(),
    'maxBlindTurns': maxBlindTurns,
    'roundNumber': roundNumber,
    'turnCount': turnCount,
    'dealerIndex': dealerIndex,
    'activeTurnIndex': activeTurnIndex,
    'potLimit': potLimit,
    if (turnDeadline != null)
      'turnDeadline': turnDeadline!.toUtc().toIso8601String(),
    if (pendingSideShow != null)
      'pendingSideShow': {
        'requesterId': pendingSideShow!.requesterId,
        'targetId': pendingSideShow!.targetId,
        'stakePaid': pendingSideShow!.stakePaid,
      },
    if (lastActionLabel != null) 'lastActionLabel': lastActionLabel,
    'roundActionLog': roundActionLog,
    'isRoundOver': isRoundOver,
    if (winnerId != null) 'winnerId': winnerId,
    if (winReason != null) 'winReason': winReason,
  };
}
