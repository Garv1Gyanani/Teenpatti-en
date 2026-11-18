/// Official Teen Patti game variants supported by the rules & hand engine.
enum TeenPattiVariant {
  classic(
    displayName: 'Classic',
    shortBadge: 'Classic',
    ruleSummary: 'Highest 3-card Teen Patti hand wins.',
  ),
  muflis(
    displayName: 'Muflis',
    shortBadge: 'Muflis • Lowball',
    ruleSummary: 'Lowest hand wins — 5-3-2 off-suit is unbeatable!',
  ),
  ak47(
    displayName: 'AK47',
    shortBadge: 'AK47 • Wild',
    ruleSummary: 'All A, K, 4, and 7 cards act as Wild Jokers.',
  ),
  joker(
    displayName: 'Joker',
    shortBadge: 'Joker • Wild',
    ruleSummary: 'One face-up Joker card makes all matching ranks Wild.',
  );

  const TeenPattiVariant({
    required this.displayName,
    required this.shortBadge,
    required this.ruleSummary,
  });

  final String displayName;
  final String shortBadge;
  final String ruleSummary;

  /// Parses a configuration string (such as `'Muflis'`, `'AK47'`, `'Joker'`)
  /// into a [TeenPattiVariant], defaulting to [TeenPattiVariant.classic].
  static TeenPattiVariant fromLabel(String? raw) {
    if (raw == null) return TeenPattiVariant.classic;
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'muflis' || 'lowball' => TeenPattiVariant.muflis,
      'ak47' || 'ak-47' => TeenPattiVariant.ak47,
      'joker' => TeenPattiVariant.joker,
      _ => TeenPattiVariant.classic,
    };
  }
}
