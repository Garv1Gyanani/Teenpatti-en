enum TableTier { beginner, classic, highStakes }

enum RoomThemeStyle { emerald, ivory, clubLounge, royal, aceChamber }

/// Represents a joinable Teen Patti table room in the lobby.
class GameTableRoom {
  const GameTableRoom({
    required this.id,
    required this.name,
    required this.entryChips,
    required this.smallBlind,
    required this.bigBlind,
    required this.seatedCount,
    required this.maxSeats,
    required this.tier,
    required this.themeStyle,
    required this.seatedAvatars,
  });

  final String id;
  final String name;
  final int entryChips;
  final int smallBlind;
  final int bigBlind;
  final int seatedCount;
  final int maxSeats;
  final TableTier tier;
  final RoomThemeStyle themeStyle;
  final List<String> seatedAvatars;

  int get availableSeats => (maxSeats - seatedCount).clamp(0, maxSeats);
  bool get isFull => availableSeats == 0;
}

