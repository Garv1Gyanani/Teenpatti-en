/// Parameterized behavioral profile driving both offline AI difficulty tiers
/// and online bot archetypes.
class BotProfileParams {
  const BotProfileParams({
    required this.archetype,
    required this.blindPlayRate,
    required this.raiseAggression,
    required this.bluffRate,
    required this.foldThreshold,
    required this.sideShowAppetite,
    this.betSizingBias = 0.0,
    this.mistakeRate = 0.04,
    this.opponentReadWeight = 0.5,
    this.maxPreferredBlindTurns = 2,
  });

  final String archetype;

  /// Tendency (`0..1`) to remain Blind rather than seeing cards immediately.
  final double blindPlayRate;

  /// Tendency (`0..1`) to escalate Chaal/Blind stakes by 2x when legal.
  final double raiseAggression;

  /// Frequency (`0..1`) of bluffing with weak hands or pressuring blind.
  final double bluffRate;

  /// Baseline seen-hand percentile (`0..1`) below which the bot leans toward Pack.
  final double foldThreshold;

  /// Willingness (`0..1`) to initiate and accept Side Show challenges.
  final double sideShowAppetite;

  /// Comfort level (`-0.5..+0.5`) when stakes multiply; negative tightens faster.
  final double betSizingBias;

  /// Probability (`0..1`) of taking a human-like suboptimal action slip.
  final double mistakeRate;

  /// Sensitivity (`0..1`) to opponent raises, pot growth, and remaining active seats.
  final double opponentReadWeight;

  /// Soft cap on how many blind turns the bot prefers before checking cards.
  final int maxPreferredBlindTurns;

  BotProfileParams copyWith({
    String? archetype,
    double? blindPlayRate,
    double? raiseAggression,
    double? bluffRate,
    double? foldThreshold,
    double? sideShowAppetite,
    double? betSizingBias,
    double? mistakeRate,
    double? opponentReadWeight,
    int? maxPreferredBlindTurns,
  }) {
    return BotProfileParams(
      archetype: archetype ?? this.archetype,
      blindPlayRate: blindPlayRate ?? this.blindPlayRate,
      raiseAggression: raiseAggression ?? this.raiseAggression,
      bluffRate: bluffRate ?? this.bluffRate,
      foldThreshold: foldThreshold ?? this.foldThreshold,
      sideShowAppetite: sideShowAppetite ?? this.sideShowAppetite,
      betSizingBias: betSizingBias ?? this.betSizingBias,
      mistakeRate: mistakeRate ?? this.mistakeRate,
      opponentReadWeight: opponentReadWeight ?? this.opponentReadWeight,
      maxPreferredBlindTurns:
          maxPreferredBlindTurns ?? this.maxPreferredBlindTurns,
    );
  }

  Map<String, dynamic> toJson() => {
        'archetype': archetype,
        'blind_play_rate': blindPlayRate,
        'raise_aggression': raiseAggression,
        'bluff_rate': bluffRate,
        'fold_threshold': foldThreshold,
        'side_show_appetite': sideShowAppetite,
        'bet_sizing_bias': betSizingBias,
        'mistake_rate': mistakeRate,
        'opponent_read_weight': opponentReadWeight,
        'max_preferred_blind_turns': maxPreferredBlindTurns,
      };

  factory BotProfileParams.fromJson(Map<String, dynamic> json) {
    return BotProfileParams(
      archetype: (json['archetype'] as String?) ?? 'balanced',
      blindPlayRate: _num(json['blind_play_rate'], 0.45),
      raiseAggression: _num(json['raise_aggression'], 0.22),
      bluffRate: _num(json['bluff_rate'], 0.14),
      foldThreshold: _num(json['fold_threshold'], 0.44),
      sideShowAppetite: _num(json['side_show_appetite'], 0.45),
      betSizingBias: _num(json['bet_sizing_bias'], 0.0),
      mistakeRate: _num(json['mistake_rate'], 0.04),
      opponentReadWeight: _num(json['opponent_read_weight'], 0.5),
      maxPreferredBlindTurns:
          (json['max_preferred_blind_turns'] as num?)?.toInt() ?? 2,
    );
  }

  static double _num(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;

  // --- Offline Difficulty Presets ---

  static const offlineEasy = BotProfileParams(
    archetype: 'offline_easy',
    blindPlayRate: 0.35,
    raiseAggression: 0.12,
    bluffRate: 0.08,
    foldThreshold: 0.28,
    sideShowAppetite: 0.30,
    betSizingBias: -0.10,
    mistakeRate: 0.14,
    opponentReadWeight: 0.15,
    maxPreferredBlindTurns: 1,
  );

  static const offlineMedium = BotProfileParams(
    archetype: 'offline_medium',
    blindPlayRate: 0.45,
    raiseAggression: 0.24,
    bluffRate: 0.12,
    foldThreshold: 0.44,
    sideShowAppetite: 0.48,
    betSizingBias: 0.0,
    mistakeRate: 0.05,
    opponentReadWeight: 0.45,
    maxPreferredBlindTurns: 2,
  );

  static const offlineHard = BotProfileParams(
    archetype: 'offline_hard',
    blindPlayRate: 0.52,
    raiseAggression: 0.34,
    bluffRate: 0.20,
    foldThreshold: 0.50,
    sideShowAppetite: 0.62,
    betSizingBias: 0.12,
    mistakeRate: 0.02,
    opponentReadWeight: 0.85,
    maxPreferredBlindTurns: 3,
  );

  // --- Online Archetype Presets (8 Distinct Archetypes + Human Baseline) ---

  static const cautious = BotProfileParams(
    archetype: 'cautious',
    blindPlayRate: 0.34,
    raiseAggression: 0.16,
    bluffRate: 0.08,
    foldThreshold: 0.46,
    sideShowAppetite: 0.42,
    betSizingBias: -0.02,
    mistakeRate: 0.045,
    opponentReadWeight: 0.60,
    maxPreferredBlindTurns: 1,
  );

  static const tightAggressive = BotProfileParams(
    archetype: 'tight_aggressive',
    blindPlayRate: 0.42,
    raiseAggression: 0.30,
    bluffRate: 0.14,
    foldThreshold: 0.47,
    sideShowAppetite: 0.55,
    betSizingBias: 0.05,
    mistakeRate: 0.04,
    opponentReadWeight: 0.68,
    maxPreferredBlindTurns: 2,
  );

  static const loosePassive = BotProfileParams(
    archetype: 'loose_passive',
    blindPlayRate: 0.48,
    raiseAggression: 0.14,
    bluffRate: 0.10,
    foldThreshold: 0.38,
    sideShowAppetite: 0.42,
    betSizingBias: -0.04,
    mistakeRate: 0.05,
    opponentReadWeight: 0.35,
    maxPreferredBlindTurns: 2,
  );

  static const blindBluffer = BotProfileParams(
    archetype: 'blind_bluffer',
    blindPlayRate: 0.72,
    raiseAggression: 0.32,
    bluffRate: 0.24,
    foldThreshold: 0.41,
    sideShowAppetite: 0.52,
    betSizingBias: 0.08,
    mistakeRate: 0.04,
    opponentReadWeight: 0.48,
    maxPreferredBlindTurns: 3,
  );

  static const shark = BotProfileParams(
    archetype: 'shark',
    blindPlayRate: 0.46,
    raiseAggression: 0.30,
    bluffRate: 0.17,
    foldThreshold: 0.47,
    sideShowAppetite: 0.60,
    betSizingBias: 0.10,
    mistakeRate: 0.03,
    opponentReadWeight: 0.85,
    maxPreferredBlindTurns: 2,
  );

  static const balanced = BotProfileParams(
    archetype: 'balanced',
    blindPlayRate: 0.48,
    raiseAggression: 0.24,
    bluffRate: 0.14,
    foldThreshold: 0.44,
    sideShowAppetite: 0.50,
    betSizingBias: 0.02,
    mistakeRate: 0.04,
    opponentReadWeight: 0.58,
    maxPreferredBlindTurns: 2,
  );

  static const chaotic = BotProfileParams(
    archetype: 'chaotic',
    blindPlayRate: 0.56,
    raiseAggression: 0.32,
    bluffRate: 0.18,
    foldThreshold: 0.42,
    sideShowAppetite: 0.56,
    betSizingBias: 0.04,
    mistakeRate: 0.04,
    opponentReadWeight: 0.42,
    maxPreferredBlindTurns: 3,
  );

  static const opportunist = BotProfileParams(
    archetype: 'opportunist',
    blindPlayRate: 0.44,
    raiseAggression: 0.27,
    bluffRate: 0.16,
    foldThreshold: 0.45,
    sideShowAppetite: 0.64,
    betSizingBias: 0.04,
    mistakeRate: 0.035,
    opponentReadWeight: 0.70,
    maxPreferredBlindTurns: 2,
  );

  /// Average recreational human player model used in the headless simulator.
  static const humanBaseline = BotProfileParams(
    archetype: 'human_baseline',
    blindPlayRate: 0.46,
    raiseAggression: 0.25,
    bluffRate: 0.15,
    foldThreshold: 0.44,
    sideShowAppetite: 0.50,
    betSizingBias: 0.02,
    mistakeRate: 0.04,
    opponentReadWeight: 0.60,
    maxPreferredBlindTurns: 2,
  );

  /// Resolves legacy offline `personaTag` / archetype identifiers cleanly.
  static BotProfileParams fromTag(String? tag) {
    final key = (tag ?? '').trim().toLowerCase();
    return switch (key) {
      'easy' || 'offline_easy' => offlineEasy,
      'hard' || 'offline_hard' => offlineHard,
      'medium' || 'offline_medium' => offlineMedium,
      'tight' || 'cautious' => cautious,
      'aggressive' || 'tight_aggressive' => tightAggressive,
      'loose_passive' => loosePassive,
      'bluffer' || 'blind_bluffer' => blindBluffer,
      'shark' => shark,
      'chaotic' => chaotic,
      'opportunist' => opportunist,
      'human_baseline' => humanBaseline,
      _ => balanced,
    };
  }
}
