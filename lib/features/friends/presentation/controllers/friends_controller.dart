import 'package:flutter/foundation.dart';

import '../../domain/entities/friend_member.dart';
import '../../domain/usecases/get_friends_data_usecase.dart';

/// Presentation controller for the Friends screen.
class FriendsController extends ChangeNotifier {
  FriendsController({
    required GetFriendsDataUseCase getFriendsDataUseCase,
  }) : _getFriendsDataUseCase = getFriendsDataUseCase;

  final GetFriendsDataUseCase _getFriendsDataUseCase;

  FriendsDirectory? _directory;
  FriendsDirectory? get directory => _directory;

  FriendsFilterTab _selectedTab = FriendsFilterTab.all;
  FriendsFilterTab get selectedTab => _selectedTab;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isDisposed = false;

  List<FriendMember> get filteredFriends {
    final friends = _directory?.friends ?? const [];
    final query = _searchQuery.trim().toLowerCase();

    return friends.where((friend) {
      final matchesTab = switch (_selectedTab) {
        FriendsFilterTab.all => true,
        FriendsFilterTab.online => friend.isOnline,
        FriendsFilterTab.recentlyPlayed => friend.isRecentlyPlayed,
      };
      final matchesQuery =
          query.isEmpty || friend.name.toLowerCase().contains(query);
      return matchesTab && matchesQuery;
    }).toList();
  }

  Future<void> loadFriends() async {
    _isLoading = true;
    _notifySafely();
    try {
      _directory = await _getFriendsDataUseCase();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void selectTab(FriendsFilterTab tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    _notifySafely();
  }

  void updateSearch(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
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
