import 'package:flutter/foundation.dart';

import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/friend_member.dart';
import '../../domain/usecases/get_friends_data_usecase.dart';

/// Presentation controller for the Friends screen.
class FriendsController extends ChangeNotifier {
  FriendsController({
    required GetFriendsDataUseCase getFriendsDataUseCase,
    AppSessionStore? sessionStore,
  })  : _getFriendsDataUseCase = getFriendsDataUseCase,
        _sessionStore = sessionStore {
    _sessionStore?.addListener(_onSessionChanged);
  }

  final GetFriendsDataUseCase _getFriendsDataUseCase;
  final AppSessionStore? _sessionStore;

  FriendsDirectory? _directory;
  FriendsDirectory? get directory => _directory;

  FriendsFilterTab _selectedTab = FriendsFilterTab.all;
  FriendsFilterTab get selectedTab => _selectedTab;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isDisposed = false;

  List<TableRoomInvite> get pendingInvites =>
      _directory?.pendingInvites ?? const <TableRoomInvite>[];

  List<FriendMember> get filteredFriends {
    final friends = _directory?.friends ?? const [];
    final query = _searchQuery.trim().toLowerCase();

    return friends.where((friend) {
      final matchesTab = switch (_selectedTab) {
        FriendsFilterTab.all => true,
        FriendsFilterTab.online => friend.isOnline,
        FriendsFilterTab.recentlyPlayed => friend.isRecentlyPlayed,
      };
      final matchesQuery = query.isEmpty ||
          friend.name.toLowerCase().contains(query) ||
          (friend.playerCode?.toLowerCase().contains(query) ?? false);
      return matchesTab && matchesQuery;
    }).toList();
  }

  void _onSessionChanged() {
    if (_isDisposed || _isLoading) return;
    final store = _sessionStore;
    if (store == null) return;
    final list = store.friends;
    _directory = FriendsDirectory(
      inviteCode: store.playerId,
      totalCount: list.length,
      onlineCount: list.where((f) => f.isOnline).length,
      friends: list,
      pendingInvites: store.pendingRoomInvites,
    );
    _notifySafely();
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

  Future<FriendMember> addFriendByCode(String code) async {
    final store = _sessionStore ?? AppSessionStore.instance;
    final added = await store.addFriendByCode(code);
    if (_sessionStore == null) {
      final existing = _directory?.friends ?? const <FriendMember>[];
      final updated = <FriendMember>[
        added,
        ...existing.where((f) => f.id != added.id),
      ];
      _directory = FriendsDirectory(
        inviteCode: _directory?.inviteCode ?? store.playerId,
        totalCount: updated.length,
        onlineCount: updated.where((f) => f.isOnline).length,
        friends: updated,
        pendingInvites: _directory?.pendingInvites ?? const <TableRoomInvite>[],
      );
      _notifySafely();
    }
    return added;
  }

  Future<void> removeFriend(String friendId) async {
    final store = _sessionStore ?? AppSessionStore.instance;
    await store.removeFriend(friendId);
    if (_sessionStore == null && _directory != null) {
      final updated =
          _directory!.friends.where((f) => f.id != friendId).toList();
      _directory = FriendsDirectory(
        inviteCode: _directory!.inviteCode,
        totalCount: updated.length,
        onlineCount: updated.where((f) => f.isOnline).length,
        friends: updated,
        pendingInvites: _directory!.pendingInvites,
      );
      _notifySafely();
    }
  }

  Future<bool> sendTableInvite({
    required FriendMember friend,
    String roomCode = '9F7K2D',
  }) async {
    final store = _sessionStore ?? AppSessionStore.instance;
    return store.sendTableInviteToFriend(
      friend: friend,
      roomCode: roomCode,
    );
  }

  Future<String?> respondToInvite(
    TableRoomInvite invite, {
    required bool accept,
  }) async {
    final store = _sessionStore ?? AppSessionStore.instance;
    final code = await store.respondToTableInvite(
      inviteId: invite.id,
      accept: accept,
    );
    if (_sessionStore == null && _directory != null) {
      final remaining = _directory!.pendingInvites
          .where((i) => i.id != invite.id)
          .toList(growable: false);
      _directory = FriendsDirectory(
        inviteCode: _directory!.inviteCode,
        totalCount: _directory!.totalCount,
        onlineCount: _directory!.onlineCount,
        friends: _directory!.friends,
        pendingInvites: remaining,
      );
      _notifySafely();
    }
    return code;
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
    _sessionStore?.removeListener(_onSessionChanged);
    super.dispose();
  }
}
