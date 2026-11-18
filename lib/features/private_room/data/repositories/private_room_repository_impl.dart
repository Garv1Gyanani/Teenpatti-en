import '../../../../core/constants/app_assets.dart';
import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/private_room_state.dart';
import '../../domain/repositories/private_room_repository.dart';

/// Default [PrivateRoomRepository] supplying the initial 6-seat private table.
class PrivateRoomRepositoryImpl implements PrivateRoomRepository {
  const PrivateRoomRepositoryImpl({this.sessionStore});

  final AppSessionStore? sessionStore;

  @override
  Future<PrivateRoomState> getInitialRoom() async {
    final store = sessionStore;
    final hostName = store?.displayName ?? 'Garv';
    final hostAvatar = store?.avatarAsset ?? AppAssets.avatar2;

    return PrivateRoomState(
      roomCode: '9F7K2D',
      bootAmount: 100,
      maxPlayers: 6,
      gameVariant: 'Classic',
      isRoomLocked: true,
      allowSpectators: false,
      autoNextRound: true,
      isLocalReady: false,
      seats: [
        PrivateRoomSeat(
          seatIndex: 0,
          playerName: hostName,
          avatarAsset: hostAvatar,
          isHost: true,
        ),
        const PrivateRoomSeat(
          seatIndex: 1,
          playerName: 'Sneha',
          avatarAsset: AppAssets.avatar4,
        ),
        const PrivateRoomSeat(
          seatIndex: 2,
          playerName: 'Rohit',
          avatarAsset: AppAssets.avatar3,
        ),
        const PrivateRoomSeat(
          seatIndex: 3,
          playerName: 'Aryan',
          avatarAsset: AppAssets.avatar2,
        ),
        const PrivateRoomSeat(seatIndex: 4),
        const PrivateRoomSeat(seatIndex: 5),
      ],
    );
  }
}
