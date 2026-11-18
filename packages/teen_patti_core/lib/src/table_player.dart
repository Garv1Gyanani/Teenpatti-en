import 'game_user.dart';
import 'playing_card.dart';

/// Represents a seated participant at a Teen Patti table backed by [GameUser].
class TablePlayer {
  const TablePlayer({
    required this.id,
    required this.name,
    required this.chips,
    required this.avatarAsset,
    this.participantKind = ParticipantKind.clientBot,
    this.personaTag,
    this.rating = 1000,
    this.isLocalPlayer = false,
    this.isDealer = false,
    this.isActiveTurn = false,
    this.hasPacked = false,
    this.hasSeenCards = false,
    this.hasGiftBadge = false,
    this.cards = const [],
    this.totalBet = 0,
    this.lastBetAmount = 0,
    this.blindTurnsTaken = 0,
    this.lastActionText,
  });

  /// Adapts a unified [GameUser] (human, offline bot, or online AI agent) to a seat.
  factory TablePlayer.fromUser(
    GameUser user, {
    bool isLocalPlayer = false,
    bool isDealer = false,
    bool isActiveTurn = false,
    bool hasPacked = false,
    bool hasSeenCards = false,
    bool hasGiftBadge = false,
    List<PlayingCard> cards = const [],
    int totalBet = 0,
    int lastBetAmount = 0,
    int blindTurnsTaken = 0,
    String? lastActionText,
  }) {
    return TablePlayer(
      id: user.id,
      name: user.name,
      chips: user.chips,
      avatarAsset: user.avatarAsset,
      participantKind: user.kind,
      personaTag: user.personaTag,
      rating: user.rating,
      isLocalPlayer: isLocalPlayer,
      isDealer: isDealer,
      isActiveTurn: isActiveTurn,
      hasPacked: hasPacked,
      hasSeenCards: hasSeenCards,
      hasGiftBadge: hasGiftBadge,
      cards: cards,
      totalBet: totalBet,
      lastBetAmount: lastBetAmount,
      blindTurnsTaken: blindTurnsTaken,
      lastActionText: lastActionText,
    );
  }

  final String id;
  final String name;
  final int chips;
  final String avatarAsset;
  final ParticipantKind participantKind;
  final String? personaTag;
  final int rating;
  final bool isLocalPlayer;
  final bool isDealer;
  final bool isActiveTurn;
  final bool hasPacked;
  final bool hasSeenCards;
  final bool hasGiftBadge;
  final List<PlayingCard> cards;
  final int totalBet;
  final int lastBetAmount;
  final int blindTurnsTaken;
  final String? lastActionText;

  bool get isClientBot => participantKind == ParticipantKind.clientBot;
  bool get isOnlineAgent => participantKind == ParticipantKind.onlineAgent;
  bool get isAutomated => participantKind != ParticipantKind.human;

  /// Projects this table seat back into the shared [GameUser] model.
  GameUser toUser() {
    return GameUser(
      id: id,
      name: name,
      chips: chips,
      avatarAsset: avatarAsset,
      kind: participantKind,
      personaTag: personaTag,
      rating: rating,
    );
  }

  TablePlayer copyWith({
    String? name,
    String? avatarAsset,
    int? chips,
    bool? isDealer,
    bool? isActiveTurn,
    bool? hasPacked,
    bool? hasSeenCards,
    bool? hasGiftBadge,
    List<PlayingCard>? cards,
    int? totalBet,
    int? lastBetAmount,
    int? blindTurnsTaken,
    String? lastActionText,
    bool clearLastActionText = false,
  }) {
    return TablePlayer(
      id: id,
      name: name ?? this.name,
      chips: chips ?? this.chips,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      participantKind: participantKind,
      personaTag: personaTag,
      rating: rating,
      isLocalPlayer: isLocalPlayer,
      isDealer: isDealer ?? this.isDealer,
      isActiveTurn: isActiveTurn ?? this.isActiveTurn,
      hasPacked: hasPacked ?? this.hasPacked,
      hasSeenCards: hasSeenCards ?? this.hasSeenCards,
      hasGiftBadge: hasGiftBadge ?? this.hasGiftBadge,
      cards: cards ?? this.cards,
      totalBet: totalBet ?? this.totalBet,
      lastBetAmount: lastBetAmount ?? this.lastBetAmount,
      blindTurnsTaken: blindTurnsTaken ?? this.blindTurnsTaken,
      lastActionText: clearLastActionText
          ? null
          : (lastActionText ?? this.lastActionText),
    );
  }
}
