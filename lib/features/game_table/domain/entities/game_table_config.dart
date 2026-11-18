import '../../../../core/models/game_user.dart';

/// Launch configuration passed into `AppRoutes.gameTable` from Lobby, Private
/// Room, or Home quick-play modes.
class GameTableConfig {
  const GameTableConfig({
    this.tableName = 'Teen Patti',
    this.minStake = 100,
    this.maxStake = 3200,
    this.maxPlayers = 7,
    this.entryChips = 100,
    this.variant = 'Classic',
    this.autoNextRound = false,
    this.customOpponents,
    this.isPractice = false,
    this.isOnline = false,
    this.roomId,
    this.roomCode,
    this.fillWithAi = true,
  });

  final String tableName;
  final int minStake;
  final int maxStake;
  final int maxPlayers;
  final int entryChips;
  final String variant;
  final bool autoNextRound;

  /// Optional pre-seated opponents (e.g. friends from a Private Room).
  final List<GameUser>? customOpponents;

  /// True for local free-chip Practice / offline tables.
  final bool isPractice;

  /// True when backed by a Supabase Realtime room and authoritative server.
  final bool isOnline;

  /// Remote room identifier when [isOnline] is true.
  final String? roomId;

  /// Shareable 6-character code for private rooms.
  final String? roomCode;

  /// Whether AI bots may join open seats while waiting.
  final bool fillWithAi;

  bool get usesPracticeWallet =>
      isPractice || variant.trim().toLowerCase() == 'practice';
}
