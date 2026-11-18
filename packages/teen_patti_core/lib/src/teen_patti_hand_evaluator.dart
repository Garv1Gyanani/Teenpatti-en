import 'game_variant.dart';
import 'playing_card.dart';

/// Teen Patti 3-card hand ranks ordered from weakest to strongest in Classic.
enum TeenPattiHandCategory {
  highCard,
  pair,
  color,
  sequence,
  pureSequence,
  trail,
}

/// Evaluated 3-card Teen Patti hand with deterministic comparison and label.
class EvaluatedHand implements Comparable<EvaluatedHand> {
  const EvaluatedHand({
    required this.category,
    required this.tieBreakers,
    required this.label,
    required this.shortCategoryName,
    required this.normalizedStrength,
    this.isLowball = false,
  });

  final TeenPattiHandCategory category;
  final List<int> tieBreakers;
  final String label;
  final String shortCategoryName;

  /// Normalized strength between `0.0` (worst hand in active variant) and
  /// `1.0` (strongest hand in active variant).
  final double normalizedStrength;

  /// `true` when evaluated under [TeenPattiVariant.muflis] (lowest hand wins).
  final bool isLowball;

  int _compareClassicOrder(EvaluatedHand other) {
    final categoryCmp = category.index.compareTo(other.category.index);
    if (categoryCmp != 0) return categoryCmp;

    final len = tieBreakers.length < other.tieBreakers.length
        ? tieBreakers.length
        : other.tieBreakers.length;
    for (var i = 0; i < len; i++) {
      final cmp = tieBreakers[i].compareTo(other.tieBreakers[i]);
      if (cmp != 0) return cmp;
    }
    return tieBreakers.length.compareTo(other.tieBreakers.length);
  }

  @override
  int compareTo(EvaluatedHand other) {
    final classicCmp = _compareClassicOrder(other);
    if (isLowball && other.isLowball) {
      return -classicCmp;
    }
    return classicCmp;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EvaluatedHand &&
          isLowball == other.isLowball &&
          compareTo(other) == 0);

  @override
  int get hashCode =>
      Object.hash(category, isLowball, Object.hashAll(tieBreakers));
}

/// Evaluates and compares 3-card hands under Classic, Muflis, AK47, and Joker
/// Teen Patti rules.
class TeenPattiHandEvaluator {
  const TeenPattiHandEvaluator._();

  static final List<PlayingCard> _allStandardCards =
      PlayingCard.standardDeck();

  /// Returns whether [card] acts as a wild card under [variant] / [jokerCard].
  static bool isWildCard(
    PlayingCard card, {
    required TeenPattiVariant variant,
    PlayingCard? jokerCard,
  }) {
    return switch (variant) {
      TeenPattiVariant.classic || TeenPattiVariant.muflis => false,
      TeenPattiVariant.ak47 =>
        card.rank == 'A' ||
            card.rank == 'K' ||
            card.rank == '4' ||
            card.rank == '7',
      TeenPattiVariant.joker =>
        jokerCard != null && card.rank == jokerCard.rank,
    };
  }

  /// Evaluates a 3-card Teen Patti hand under [variant].
  ///
  /// Throws an [ArgumentError] if [cards] does not contain exactly 3 cards.
  static EvaluatedHand evaluate(
    List<PlayingCard> cards, {
    TeenPattiVariant variant = TeenPattiVariant.classic,
    PlayingCard? jokerCard,
  }) {
    if (cards.length != 3) {
      throw ArgumentError.value(
        cards.length,
        'cards',
        'Teen Patti hands must contain exactly 3 cards.',
      );
    }

    switch (variant) {
      case TeenPattiVariant.classic:
        return _evaluateClassic(cards);

      case TeenPattiVariant.muflis:
        final base = _evaluateClassic(cards);
        final sorted = [...cards]
          ..sort((a, b) => b.numericRank.compareTo(a.numericRank));
        final lowLabel = base.category == TeenPattiHandCategory.highCard
            ? 'Muflis Low (${sorted[0].rank}-${sorted[1].rank}-${sorted[2].rank})'
            : '${base.label} • Muflis';
        return EvaluatedHand(
          category: base.category,
          tieBreakers: base.tieBreakers,
          label: lowLabel,
          shortCategoryName: base.shortCategoryName,
          normalizedStrength: (1.0 - base.normalizedStrength).clamp(0.02, 0.99),
          isLowball: true,
        );

      case TeenPattiVariant.ak47:
      case TeenPattiVariant.joker:
        return _evaluateWithWilds(
          cards,
          variant: variant,
          jokerCard: jokerCard,
        );
    }
  }

  static EvaluatedHand _evaluateWithWilds(
    List<PlayingCard> cards, {
    required TeenPattiVariant variant,
    PlayingCard? jokerCard,
  }) {
    final naturals = <PlayingCard>[];
    var wildCount = 0;
    for (final c in cards) {
      if (isWildCard(c, variant: variant, jokerCard: jokerCard)) {
        wildCount++;
      } else {
        naturals.add(c);
      }
    }

    if (wildCount == 0) {
      return _evaluateClassic(cards);
    }

    if (wildCount == 3) {
      final best = _evaluateClassic(const [
        PlayingCard(rank: 'A', suit: CardSuit.spades),
        PlayingCard(rank: 'A', suit: CardSuit.hearts),
        PlayingCard(rank: 'A', suit: CardSuit.clubs),
      ]);
      return _appendWildTag(best);
    }

    if (wildCount == 2) {
      // With 1 natural card R and 2 wilds, forming Trail of R strictly beats
      // every Pure Sequence, Sequence, Color, Pair, and High Card.
      final nat = naturals.first;
      final otherSuits = CardSuit.values
          .where((s) => s != nat.suit)
          .take(2)
          .toList(growable: false);
      final best = _evaluateClassic([
        nat,
        PlayingCard(rank: nat.rank, suit: otherSuits[0]),
        PlayingCard(rank: nat.rank, suit: otherSuits[1]),
      ]);
      return _appendWildTag(best);
    }

    // Exactly 1 wild card + 2 natural cards: check all 50 remaining standard
    // deck cards to find the provably strongest legal 3-card Teen Patti hand.
    EvaluatedHand? bestEval;
    for (final candidate in _allStandardCards) {
      if (candidate == naturals[0] || candidate == naturals[1]) continue;
      final eval = _evaluateClassic([naturals[0], naturals[1], candidate]);
      if (bestEval == null || eval.compareTo(bestEval) > 0) {
        bestEval = eval;
      }
    }
    return _appendWildTag(bestEval!);
  }

  static EvaluatedHand _appendWildTag(EvaluatedHand base) {
    return EvaluatedHand(
      category: base.category,
      tieBreakers: base.tieBreakers,
      label: '${base.label} (Wild)',
      shortCategoryName: base.shortCategoryName,
      normalizedStrength: base.normalizedStrength,
    );
  }

  static EvaluatedHand _evaluateClassic(List<PlayingCard> cards) {
    final sorted = [...cards]
      ..sort((a, b) => b.numericRank.compareTo(a.numericRank));
    final ranks = sorted.map((c) => c.numericRank).toList(growable: false);
    final r1 = ranks[0];
    final r2 = ranks[1];
    final r3 = ranks[2];

    final isSameSuit =
        cards[0].suit == cards[1].suit && cards[1].suit == cards[2].suit;
    final sequenceTier = _sequenceTier(r1, r2, r3);
    final isSequence = sequenceTier != null;

    // 1. Trail / Trio (three of a kind)
    if (r1 == r2 && r2 == r3) {
      final strength = 0.95 + ((r1 - 2) / 12.0) * 0.05;
      return EvaluatedHand(
        category: TeenPattiHandCategory.trail,
        tieBreakers: [r1],
        label: 'Trail (${_pluralRankName(r1)})',
        shortCategoryName: 'Trail',
        normalizedStrength: strength,
      );
    }

    // 2. Pure Sequence (straight flush)
    if (isSameSuit && isSequence) {
      final strength = 0.87 + ((sequenceTier - 4) / 11.0) * 0.07;
      return EvaluatedHand(
        category: TeenPattiHandCategory.pureSequence,
        tieBreakers: [sequenceTier],
        label: 'Pure Sequence (${_sequenceDisplay(r1, r2, r3)})',
        shortCategoryName: 'Pure Sequence',
        normalizedStrength: strength,
      );
    }

    // 3. Sequence (straight)
    if (isSequence) {
      final strength = 0.75 + ((sequenceTier - 4) / 11.0) * 0.10;
      return EvaluatedHand(
        category: TeenPattiHandCategory.sequence,
        tieBreakers: [sequenceTier],
        label: 'Sequence (${_sequenceDisplay(r1, r2, r3)})',
        shortCategoryName: 'Sequence',
        normalizedStrength: strength,
      );
    }

    // 4. Color (flush)
    if (isSameSuit) {
      final score = _highCardCompositeScore(r1, r2, r3);
      final strength = 0.58 + score * 0.14;
      return EvaluatedHand(
        category: TeenPattiHandCategory.color,
        tieBreakers: [r1, r2, r3],
        label: 'Color (${_rankLabel(r1)} High)',
        shortCategoryName: 'Color',
        normalizedStrength: strength,
      );
    }

    // 5. Pair
    if (r1 == r2 || r2 == r3) {
      final pairRank = r2;
      final kicker = r1 == r2 ? r3 : r1;
      final normalizedPair =
          ((pairRank * 15 + kicker) - 33) / (223 - 33).toDouble();
      final strength = 0.33 + normalizedPair.clamp(0.0, 1.0) * 0.22;
      return EvaluatedHand(
        category: TeenPattiHandCategory.pair,
        tieBreakers: [pairRank, kicker],
        label: 'Pair (${_pluralRankName(pairRank)})',
        shortCategoryName: 'Pair',
        normalizedStrength: strength,
      );
    }

    // 6. High Card
    final score = _highCardCompositeScore(r1, r2, r3);
    final strength = 0.04 + score * 0.26;
    return EvaluatedHand(
      category: TeenPattiHandCategory.highCard,
      tieBreakers: [r1, r2, r3],
      label: 'High Card (${_rankLabel(r1)})',
      shortCategoryName: 'High Card',
      normalizedStrength: strength,
    );
  }

  /// Returns `> 0` if [handA] beats [handB], `< 0` if [handB] beats [handA],
  /// or `0` if both hands tie under [variant].
  static int compare(
    List<PlayingCard> handA,
    List<PlayingCard> handB, {
    TeenPattiVariant variant = TeenPattiVariant.classic,
    PlayingCard? jokerCard,
  }) {
    final evalA = evaluate(handA, variant: variant, jokerCard: jokerCard);
    final evalB = evaluate(handB, variant: variant, jokerCard: jokerCard);
    return evalA.compareTo(evalB);
  }

  /// Official Teen Patti straight hierarchy:
  /// `A-K-Q` (15) > `A-2-3` (14) > `K-Q-J` (13) > ... > `4-3-2` (4).
  /// `K-A-2` is NOT a valid sequence.
  static int? _sequenceTier(int r1, int r2, int r3) {
    if (r1 == 14 && r2 == 13 && r3 == 12) return 15;
    if (r1 == 14 && r2 == 3 && r3 == 2) return 14;
    if (r1 - r2 == 1 && r2 - r3 == 1) return r1;
    return null;
  }

  static double _highCardCompositeScore(int r1, int r2, int r3) {
    // Smallest non-sequence high card is 5-3-2 (1172); largest is A-K-J (3356).
    final raw = r1 * 225 + r2 * 15 + r3;
    return ((raw - 1172) / (3356 - 1172)).clamp(0.0, 1.0);
  }

  static String _sequenceDisplay(int r1, int r2, int r3) {
    if (r1 == 14 && r2 == 3 && r3 == 2) return 'A-2-3';
    return '${_rankLabel(r1)}-${_rankLabel(r2)}-${_rankLabel(r3)}';
  }

  static String _rankLabel(int rank) => switch (rank) {
        14 => 'A',
        13 => 'K',
        12 => 'Q',
        11 => 'J',
        _ => '$rank',
      };

  static String _pluralRankName(int rank) => switch (rank) {
        14 => 'Aces',
        13 => 'Kings',
        12 => 'Queens',
        11 => 'Jacks',
        10 => 'Tens',
        9 => 'Nines',
        8 => 'Eights',
        7 => 'Sevens',
        6 => 'Sixes',
        5 => 'Fives',
        4 => 'Fours',
        3 => 'Threes',
        _ => 'Twos',
      };
}
