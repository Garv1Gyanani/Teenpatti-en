import 'package:flutter/foundation.dart';

import '../../domain/entities/table_state.dart';
import '../../domain/usecases/get_table_state_usecase.dart';
import '../../domain/usecases/perform_player_action_usecase.dart';

/// Presentation controller for the Teen Patti Game Table screen.
class GameTableController extends ChangeNotifier {
  GameTableController({
    required GetTableStateUseCase getTableStateUseCase,
    required PerformPlayerActionUseCase performPlayerActionUseCase,
  })  : _getTableStateUseCase = getTableStateUseCase,
        _performPlayerActionUseCase = performPlayerActionUseCase;

  final GetTableStateUseCase _getTableStateUseCase;
  final PerformPlayerActionUseCase _performPlayerActionUseCase;

  TableState? _state;
  TableState? get state => _state;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isActing = false;
  bool get isActing => _isActing;

  String? _lastActionFeedback;
  String? get lastActionFeedback => _lastActionFeedback;

  bool _isDisposed = false;

  Future<void> loadTable() async {
    _isLoading = true;
    _notifySafely();

    try {
      _state = await _getTableStateUseCase();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> performAction(PlayerTableAction action) async {
    final current = _state;
    if (current == null || _isActing || current.localPlayer.hasPacked) return;

    _isActing = true;
    _notifySafely();

    try {
      final updated = await _performPlayerActionUseCase(
        currentState: current,
        action: action,
      );
      final feedback = switch (action) {
        PlayerTableAction.pack => 'You packed your hand.',
        PlayerTableAction.sideShow => 'Side Show requested.',
        PlayerTableAction.blind => 'Played Blind ₹${current.blindAmount}.',
        PlayerTableAction.chaal => 'Played Chaal ₹${current.chaalAmount}.',
        PlayerTableAction.show => 'Showdown called!',
      };
      _state = updated.copyWith(lastActionLabel: feedback);
      _lastActionFeedback = feedback;
    } finally {
      _isActing = false;
      _notifySafely();
    }
  }

  Future<void> dealNewHand() async {
    if (_isActing) return;
    _isActing = true;
    _notifySafely();

    try {
      _state = await _getTableStateUseCase();
      _lastActionFeedback = 'New hand dealt!';
    } finally {
      _isActing = false;
      _notifySafely();
    }
  }

  void clearFeedback() {
    _lastActionFeedback = null;
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

