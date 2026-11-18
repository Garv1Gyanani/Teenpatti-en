class PrivateRoomSeat {
  const PrivateRoomSeat({
    required this.seatIndex,
    this.playerName,
    this.avatarAsset,
    this.isHost = false,
    this.isOnline = true,
  });

  final int seatIndex;
  final String? playerName;
  final String? avatarAsset;
  final bool isHost;
  final bool isOnline;

  bool get isOccupied => playerName != null && avatarAsset != null;
}

class PrivateRoomState {
  const PrivateRoomState({
    required this.roomCode,
    required this.bootAmount,
    required this.maxPlayers,
    required this.gameVariant,
    required this.isRoomLocked,
    required this.allowSpectators,
    required this.autoNextRound,
    required this.isLocalReady,
    required this.seats,
    this.fillWithAi = false,
  });

  final String roomCode;
  final int bootAmount;
  final int maxPlayers;
  final String gameVariant;
  final bool isRoomLocked;
  final bool allowSpectators;
  final bool autoNextRound;
  final bool isLocalReady;
  final List<PrivateRoomSeat> seats;
  final bool fillWithAi;

  PrivateRoomState copyWith({
    String? roomCode,
    int? bootAmount,
    int? maxPlayers,
    String? gameVariant,
    bool? isRoomLocked,
    bool? allowSpectators,
    bool? autoNextRound,
    bool? isLocalReady,
    List<PrivateRoomSeat>? seats,
    bool? fillWithAi,
  }) {
    return PrivateRoomState(
      roomCode: roomCode ?? this.roomCode,
      bootAmount: bootAmount ?? this.bootAmount,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      gameVariant: gameVariant ?? this.gameVariant,
      isRoomLocked: isRoomLocked ?? this.isRoomLocked,
      allowSpectators: allowSpectators ?? this.allowSpectators,
      autoNextRound: autoNextRound ?? this.autoNextRound,
      isLocalReady: isLocalReady ?? this.isLocalReady,
      seats: seats ?? this.seats,
      fillWithAi: fillWithAi ?? this.fillWithAi,
    );
  }
}
