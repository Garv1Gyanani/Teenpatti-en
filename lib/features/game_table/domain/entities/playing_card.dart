enum CardSuit { spades, hearts, clubs, diamonds }

/// Represents a playing card held by a player at the Teen Patti table.
class PlayingCard {
  const PlayingCard({
    required this.rank,
    required this.suit,
  });

  final String rank;
  final CardSuit suit;

  bool get isRed => suit == CardSuit.hearts || suit == CardSuit.diamonds;

  String get suitSymbol => switch (suit) {
        CardSuit.spades => '♠',
        CardSuit.hearts => '♥',
        CardSuit.clubs => '♣',
        CardSuit.diamonds => '♦',
      };
}

