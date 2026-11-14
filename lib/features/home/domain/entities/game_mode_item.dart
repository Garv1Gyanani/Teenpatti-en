/// Identifies the available Teen Patti game modes on the Home dashboard.
enum GameModeType { classic, privateTable, practice, variants }

/// Represents a selectable game mode card on the Home screen.
class GameModeItem {
  const GameModeItem({
    required this.type,
    required this.title,
    this.subtitle,
  });

  final GameModeType type;
  final String title;
  final String? subtitle;
}

