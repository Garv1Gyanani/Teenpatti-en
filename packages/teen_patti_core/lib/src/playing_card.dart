/// Card suits used across the Teen Patti deck and UI card widgets.
enum CardSuit { spades, hearts, clubs, diamonds }

/// Represents a single playing card in Teen Patti.
class PlayingCard {
  const PlayingCard({
    required this.rank,
    required this.suit,
  });

  /// Canonical card rank labels ordered from lowest (`2`) to highest (`A`).
  static const List<String> orderedRanks = [
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K',
    'A',
  ];

  final String rank;
  final CardSuit suit;

  bool get isRed => suit == CardSuit.hearts || suit == CardSuit.diamonds;

  String get suitSymbol => switch (suit) {
        CardSuit.spades => '♠',
        CardSuit.hearts => '♥',
        CardSuit.clubs => '♣',
        CardSuit.diamonds => '♦',
      };

  /// Numeric value of [rank] (`2`..`14` where Ace = `14`).
  int get numericRank => switch (rank) {
        'A' => 14,
        'K' => 13,
        'Q' => 12,
        'J' => 11,
        _ => int.parse(rank),
      };

  /// Short display string such as `A♠` or `10♥`.
  String get label => '$rank$suitSymbol';

  /// Serializes this card to a compact JSON map for Realtime payloads.
  Map<String, dynamic> toJson() => {'rank': rank, 'suit': suit.name};

  /// Deserializes a [PlayingCard] from a Realtime JSON map.
  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    final rank = json['rank'] as String;
    final suitName = json['suit'] as String;
    final suit = CardSuit.values.firstWhere(
      (s) => s.name == suitName,
      orElse: () => CardSuit.spades,
    );
    return PlayingCard(rank: rank, suit: suit);
  }

  /// Generates a fresh, ordered 52-card standard deck.
  static List<PlayingCard> standardDeck() {
    return [
      for (final suit in CardSuit.values)
        for (final rank in orderedRanks) PlayingCard(rank: rank, suit: suit),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PlayingCard && other.rank == rank && other.suit == suit);
  }

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => label;
}
