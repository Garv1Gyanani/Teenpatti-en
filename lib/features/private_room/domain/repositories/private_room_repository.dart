import '../entities/private_room_state.dart';

abstract interface class PrivateRoomRepository {
  Future<PrivateRoomState> getInitialRoom();
}
