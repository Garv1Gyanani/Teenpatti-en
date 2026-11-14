import 'package:flutter/foundation.dart';

import '../../domain/entities/game_table_room.dart';
import '../../domain/usecases/get_available_tables_usecase.dart';

/// Presentation controller for the Choose a Table lobby screen.
class TableLobbyController extends ChangeNotifier {
  TableLobbyController({
    required GetAvailableTablesUseCase getAvailableTablesUseCase,
  }) : _getAvailableTablesUseCase = getAvailableTablesUseCase;

  final GetAvailableTablesUseCase _getAvailableTablesUseCase;

  List<GameTableRoom> _allTables = const [];
  TableTier? _selectedTier;
  bool _showOpenOnly = false;
  bool _isLoading = true;
  bool _isDisposed = false;

  TableTier? get selectedTier => _selectedTier;
  bool get showOpenOnly => _showOpenOnly;
  bool get isLoading => _isLoading;

  /// When a tier is tapped again, it clears the filter to show all tiers;
  /// otherwise filters or prioritizes rooms cleanly.
  List<GameTableRoom> get filteredTables {
    Iterable<GameTableRoom> result = _allTables;
    if (_showOpenOnly) {
      result = result.where((t) => !t.isFull);
    }
    if (_selectedTier != null) {
      final tierMatches = result.where((t) => t.tier == _selectedTier).toList();
      if (tierMatches.isNotEmpty) {
        return tierMatches;
      }
    }
    return result.toList();
  }

  List<GameTableRoom> get allTables => _showOpenOnly
      ? _allTables.where((t) => !t.isFull).toList()
      : _allTables;

  Future<void> loadTables() async {
    _isLoading = true;
    _notifySafely();
    try {
      _allTables = await _getAvailableTablesUseCase();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void selectTier(TableTier tier) {
    _selectedTier = _selectedTier == tier ? null : tier;
    _notifySafely();
  }

  void toggleOpenOnly() {
    _showOpenOnly = !_showOpenOnly;
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
