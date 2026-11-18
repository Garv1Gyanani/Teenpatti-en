import 'package:flutter/foundation.dart';

import '../../domain/entities/private_room_state.dart';
import '../../domain/usecases/get_private_room_usecase.dart';

/// Presentation controller for the Private Room lobby & table configuration.
class PrivateRoomController extends ChangeNotifier {
  PrivateRoomController({
    required GetPrivateRoomUseCase getPrivateRoomUseCase,
    this.initialRoomCode,
  }) : _getPrivateRoomUseCase = getPrivateRoomUseCase;

  final GetPrivateRoomUseCase _getPrivateRoomUseCase;
  final String? initialRoomCode;

  PrivateRoomState? _state;
  PrivateRoomState? get state => _state;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSettingsExpanded = true;
  bool get isSettingsExpanded => _isSettingsExpanded;

  bool _isDisposed = false;

  Future<void> loadRoom() async {
    _isLoading = true;
    _notifySafely();

    try {
      final loaded = await _getPrivateRoomUseCase();
      final overrideCode = initialRoomCode?.trim().toUpperCase();
      _state = (overrideCode != null && overrideCode.isNotEmpty)
          ? loaded.copyWith(roomCode: overrideCode)
          : loaded;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void setRoomCode(String code) {
    final current = _state;
    final cleaned = code.trim().toUpperCase();
    if (current == null || cleaned.isEmpty || current.roomCode == cleaned) {
      return;
    }
    _state = current.copyWith(roomCode: cleaned);
    _notifySafely();
  }

  void toggleSettingsExpanded() {
    _isSettingsExpanded = !_isSettingsExpanded;
    _notifySafely();
  }

  void setBootAmount(int amount) {
    final current = _state;
    if (current == null || current.bootAmount == amount) return;
    _state = current.copyWith(bootAmount: amount);
    _notifySafely();
  }

  void setMaxPlayers(int count) {
    final current = _state;
    if (current == null || current.maxPlayers == count) return;
    _state = current.copyWith(maxPlayers: count);
    _notifySafely();
  }

  void setGameVariant(String variant) {
    final current = _state;
    if (current == null || current.gameVariant == variant) return;
    _state = current.copyWith(gameVariant: variant);
    _notifySafely();
  }

  void toggleLockRoom(bool value) {
    final current = _state;
    if (current == null) return;
    _state = current.copyWith(isRoomLocked: value);
    _notifySafely();
  }

  void toggleSpectators(bool value) {
    final current = _state;
    if (current == null) return;
    _state = current.copyWith(allowSpectators: value);
    _notifySafely();
  }

  void toggleAutoNextRound(bool value) {
    final current = _state;
    if (current == null) return;
    _state = current.copyWith(autoNextRound: value);
    _notifySafely();
  }

  void toggleFillWithAi(bool value) {
    final current = _state;
    if (current == null) return;
    _state = current.copyWith(fillWithAi: value);
    _notifySafely();
  }

  void toggleReady() {
    final current = _state;
    if (current == null) return;
    _state = current.copyWith(isLocalReady: !current.isLocalReady);
    _notifySafely();
  }

  void seatFriend({
    required int seatIndex,
    required String name,
    required String avatarAsset,
  }) {
    final current = _state;
    if (current == null) return;

    final updated = current.seats.map((seat) {
      if (seat.seatIndex == seatIndex) {
        return PrivateRoomSeat(
          seatIndex: seatIndex,
          playerName: name,
          avatarAsset: avatarAsset,
          isOnline: true,
        );
      }
      return seat;
    }).toList();

    _state = current.copyWith(seats: updated);
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
