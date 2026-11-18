import '../entities/private_room_state.dart';
import '../repositories/private_room_repository.dart';

class GetPrivateRoomUseCase {
  const GetPrivateRoomUseCase({required PrivateRoomRepository repository})
      : _repository = repository;

  final PrivateRoomRepository _repository;

  Future<PrivateRoomState> call() => _repository.getInitialRoom();
}
