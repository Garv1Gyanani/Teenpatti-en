import 'playing_card.dart';

/// Represents a seated player around the Teen Patti table.
class TablePlayer {
  const TablePlayer({
    required this.id,
    required this.name,
    required this.chips,
    required this.avatarAsset,
    this.isLocalPlayer = false,
    this.isDealer = false,
    this.isActiveTurn = false,
    this.hasPacked = false,
    this.hasGiftBadge = false,
    this.cards = const [],
  });

  final String id;
  final String name;
  final int chips;
  final String avatarAsset;
  final bool isLocalPlayer;
  final bool isDealer;
  final bool isActiveTurn;
  final bool hasPacked;
  final bool hasGiftBadge;
  final List<PlayingCard> cards;

  TablePlayer copyWith({
    int? chips,
    bool? isActiveTurn,
    bool? hasPacked,
  }) {
    return TablePlayer(
      id: id,
      name: name,
      chips: chips ?? this.chips,
      avatarAsset: avatarAsset,
      isLocalPlayer: isLocalPlayer,
      isDealer: isDealer,
      isActiveTurn: isActiveTurn ?? this.isActiveTurn,
      hasPacked: hasPacked ?? this.hasPacked,
      hasGiftBadge: hasGiftBadge,
      cards: cards,
    );
  }
}

