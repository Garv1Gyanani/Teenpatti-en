import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../features/daily_rewards/domain/entities/daily_rewards_data.dart';
import '../../features/friends/domain/entities/friend_member.dart';
import '../../features/profile/domain/entities/player_profile_data.dart';
import '../../features/settings/domain/entities/app_settings_state.dart';
import '../../features/wallet/domain/entities/wallet_data.dart';
import '../constants/app_assets.dart';
import '../models/game_user.dart';
import '../utils/formatters.dart';
import 'local_storage_driver.dart';
import 'supabase_sync_client.dart';

/// Single source of truth for user identity, chip balance, wallet ledger,
/// profile statistics, daily rewards, and settings across all screens.
///
/// Persists atomically via [LocalStorageDriver] and syncs opportunistically
/// to Supabase via [SupabaseSyncClient].
class AppSessionStore extends ChangeNotifier {
  AppSessionStore({
    LocalStorageDriver? storageDriver,
    SupabaseSyncClient? supabaseClient,
  })  : _storage = storageDriver ?? InMemoryStorageDriver(),
        _supabase = supabaseClient ?? SupabaseSyncClient.fromEnvironment() {
    _resetToDefaults();
  }

  static const String _storageKey = 'ace_society_session_v1';

  /// Default 7-day reward ladder amounts.
  static const List<int> rewardLadder = [
    500,
    800,
    1000,
    1200,
    1500,
    2000,
    3000,
  ];

  static AppSessionStore _instance = AppSessionStore();

  /// Shared global instance wired into [AppRoutes].
  static AppSessionStore get instance => _instance;

  /// Replaces the global store (used by `main()` for disk persistence or tests).
  static void setInstance(AppSessionStore store) {
    _instance = store;
  }

  LocalStorageDriver _storage;
  SupabaseSyncClient _supabase;
  bool _hydrated = false;

  late String _profileId;
  late String _playerId;
  late String _displayName;
  late String _avatarAsset;
  String? _linkedProvider;
  bool _hasCompletedOnboarding = false;

  int _chips = 25000;
  int _practiceChips = 25000;
  int _rating = 1000;
  int _gamesPlayed = 0;
  int _wins = 0;
  int _currentWinStreak = 0;
  int _bestStreak = 0;

  int _dailyStreakDays = 5;
  int _bestDailyStreakDays = 12;
  int _totalRewardsEarned = 6200;
  String? _lastDailyClaimDate;

  bool _soundEffects = true;
  bool _backgroundMusic = true;
  bool _vibration = true;
  double _musicVolume = 0.25;
  double _sfxVolume = 0.85;

  late List<int> _weeklyGamesWon;
  late List<int> _weeklyChipsWon;
  late List<int> _weeklyWinRate;
  late List<ChipTransaction> _transactions;
  late List<FriendMember> _friends;
  List<TableRoomInvite> _pendingRoomInvites = const <TableRoomInvite>[];
  String? _pendingRoomCode;

  bool get isHydrated => _hydrated;
  String get profileId => _profileId;
  String get playerId => _playerId;
  String get displayName => _displayName;
  String get avatarAsset => _avatarAsset;
  String? get linkedProvider => _linkedProvider;
  bool get isAccountLinked =>
      _linkedProvider != null && _linkedProvider!.trim().isNotEmpty;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  int get chips => _chips;

  /// Separate, free, resettable local chip stack used strictly for offline
  /// Practice Mode and never merged with online balance or synced to Supabase.
  int get practiceChips => _practiceChips;
  int get rating => _rating;
  int get gamesPlayed => _gamesPlayed;
  int get wins => _wins;
  int get currentWinStreak => _currentWinStreak;
  int get bestStreak => _bestStreak;
  int get dailyStreakDays => _dailyStreakDays;
  int get bestDailyStreakDays => _bestDailyStreakDays;
  int get totalRewardsEarned => _totalRewardsEarned;
  bool get soundEffects => _soundEffects;
  bool get backgroundMusic => _backgroundMusic;
  bool get vibration => _vibration;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  List<ChipTransaction> get transactions => List.unmodifiable(_transactions);
  List<FriendMember> get friends => List.unmodifiable(_friends);
  List<TableRoomInvite> get pendingRoomInvites =>
      List.unmodifiable(_pendingRoomInvites);
  String? get pendingRoomCode => _pendingRoomCode;
  SupabaseSyncClient get supabaseClient => _supabase;

  /// Stores a deep-linked room code (`?room=XXXXXX`) to be auto-opened once the
  /// player reaches Home / Private Room.
  void setPendingRoomCode(String? code) {
    final cleaned = code?.trim().toUpperCase();
    final next = (cleaned != null && cleaned.isNotEmpty) ? cleaned : null;
    if (_pendingRoomCode == next) return;
    _pendingRoomCode = next;
    notifyListeners();
  }

  /// Reads and clears any pending deep-linked room code.
  String? consumePendingRoomCode() {
    final current = _pendingRoomCode;
    _pendingRoomCode = null;
    return current;
  }

  double get winRatePercent {
    if (_gamesPlayed == 0) return 0.0;
    return double.parse(((_wins / _gamesPlayed) * 100.0).toStringAsFixed(1));
  }

  int get level => 1 + (_gamesPlayed ~/ 10);
  double get levelProgress => ((_gamesPlayed % 10) / 10.0).clamp(0.1, 1.0);

  String _todayIsoDate([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  bool isDailyRewardClaimedToday([DateTime? now]) =>
      _lastDailyClaimDate == _todayIsoDate(now);

  int get todayDailyRewardAmount {
    final index = ((_dailyStreakDays - 1) % rewardLadder.length)
        .clamp(0, rewardLadder.length - 1);
    return rewardLadder[index];
  }

  /// Projects the local player as the unified [GameUser] model.
  GameUser toLocalGameUser({bool isPractice = false}) {
    return GameUser(
      id: 'local',
      name: _displayName,
      chips: isPractice ? _practiceChips : _chips,
      avatarAsset: _avatarAsset,
      kind: ParticipantKind.human,
      rating: _rating,
    );
  }

  void configure({
    LocalStorageDriver? storageDriver,
    SupabaseSyncClient? supabaseClient,
  }) {
    if (storageDriver != null) _storage = storageDriver;
    if (supabaseClient != null) _supabase = supabaseClient;
  }

  void _resetToDefaults() {
    _profileId = _generateUuidV4();
    _playerId = 'TP458732';
    _displayName = 'Garv';
    _avatarAsset = AppAssets.splashCharacter;
    _linkedProvider = null;
    _hasCompletedOnboarding = false;
    _chips = 25000;
    _practiceChips = 25000;
    _rating = 1000;
    _gamesPlayed = 0;
    _wins = 0;
    _currentWinStreak = 0;
    _bestStreak = 0;
    _dailyStreakDays = 5;
    _bestDailyStreakDays = 12;
    _totalRewardsEarned = 6200;
    _lastDailyClaimDate = null;
    _soundEffects = true;
    _backgroundMusic = true;
    _vibration = true;
    _musicVolume = 0.25;
    _sfxVolume = 0.85;
    _weeklyGamesWon = [5, 13, 8, 17, 12, 17, 0];
    _weeklyChipsWon = [8, 18, 11, 22, 16, 21, 0];
    _weeklyWinRate = [45, 58, 52, 64, 55, 61, 0];
    _transactions = [
      const ChipTransaction(
        id: 'tx_welcome_1',
        title: 'Welcome Stack',
        subtitle: 'Ace Society Starter Chips',
        amount: 25000,
        type: ChipTransactionType.dailyReward,
      ),
    ];
    _friends = List<FriendMember>.of(_defaultStarterFriends);
    _pendingRoomInvites = const <TableRoomInvite>[];
    _pendingRoomCode = null;
  }

  static const List<FriendMember> _defaultStarterFriends = <FriendMember>[
    FriendMember(
      id: 'fr_aryan',
      playerCode: 'TP901241',
      name: 'Aryan',
      avatarAsset: AppAssets.avatar2,
      isOnline: true,
      statusText: 'Online',
      isRecentlyPlayed: true,
    ),
    FriendMember(
      id: 'fr_sneha',
      playerCode: 'TP901242',
      name: 'Sneha',
      avatarAsset: AppAssets.avatar4,
      isOnline: true,
      statusText: 'Online',
      isRecentlyPlayed: true,
    ),
    FriendMember(
      id: 'fr_rohit',
      playerCode: 'TP901243',
      name: 'Rohit',
      avatarAsset: AppAssets.avatar3,
      isOnline: false,
      statusText: 'Last seen 30 min ago',
      isRecentlyPlayed: true,
    ),
    FriendMember(
      id: 'fr_meera',
      playerCode: 'TP901244',
      name: 'Meera',
      avatarAsset: AppAssets.splashCharacter,
      isOnline: false,
      statusText: 'Last seen 2 hr ago',
    ),
    FriendMember(
      id: 'fr_kabir',
      playerCode: 'TP901245',
      name: 'Kabir',
      avatarAsset: AppAssets.avatar5,
      isOnline: true,
      statusText: 'Online',
    ),
  ];

  /// Hydrates state from local storage (and initializes Supabase auth if configured).
  Future<void> hydrate() async {
    final raw = await _storage.readJson(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          _applyJson(json);
        }
      } catch (_) {
        // Keep clean defaults if stored JSON is corrupted.
      }
    }
    _hydrated = true;
    notifyListeners();

    if (_supabase.isConfigured) {
      unawaited(_syncProfileToCloud());
    }
  }

  /// Saves onboarding profile setup and marks onboarding completed.
  Future<void> completeProfileSetup({
    required String nickname,
    required String avatarAsset,
    String? linkedProvider,
  }) async {
    final trimmed = nickname.trim();
    if (trimmed.isNotEmpty) {
      _displayName = trimmed;
    }
    _avatarAsset = avatarAsset;
    _linkedProvider = linkedProvider;
    _hasCompletedOnboarding = true;

    await _persistAndNotify();
    unawaited(_syncProfileToCloud());
  }

  /// Updates display name and/or avatar from My Profile.
  Future<void> updateProfileIdentity({
    String? name,
    String? avatarAsset,
  }) async {
    if (name != null && name.trim().isNotEmpty) {
      _displayName = name.trim();
    }
    if (avatarAsset != null && avatarAsset.isNotEmpty) {
      _avatarAsset = avatarAsset;
    }
    await _persistAndNotify();
    unawaited(_syncProfileToCloud());
  }

  /// Claims today's daily streak reward across Home, Daily Rewards, and Wallet.
  Future<int?> claimDailyReward({DateTime? now}) async {
    if (isDailyRewardClaimedToday(now)) return null;

    final amount = todayDailyRewardAmount;
    _lastDailyClaimDate = _todayIsoDate(now);
    _chips += amount;
    _totalRewardsEarned += amount;
    if (_dailyStreakDays > _bestDailyStreakDays) {
      _bestDailyStreakDays = _dailyStreakDays;
    }

    final tx = ChipTransaction(
      id: 'tx_daily_${(now ?? DateTime.now()).millisecondsSinceEpoch}',
      title: 'Daily Reward',
      subtitle: 'Day $_dailyStreakDays Streak Bonus',
      amount: amount,
      type: ChipTransactionType.dailyReward,
    );
    _prependTransaction(tx);

    await _persistAndNotify();
    unawaited(_syncDailyRewardToCloud(tx));
    return amount;
  }

  /// Credits Watch & Earn bonus chips and appends a ledger entry.
  Future<int> claimWatchAndEarn({int reward = 1000}) async {
    _chips += reward;
    _totalRewardsEarned += reward;
    final tx = ChipTransaction(
      id: 'tx_watch_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Watch & Earn',
      subtitle: 'Rewarded bonus • Just now',
      amount: reward,
      type: ChipTransactionType.dailyReward,
    );
    _prependTransaction(tx);

    await _persistAndNotify();
    unawaited(_syncWatchRewardToCloud());
    return reward;
  }

  /// Credits purchased chips and appends a ledger entry.
  Future<void> purchaseChips({
    required int priceInr,
    required int chipAmount,
  }) async {
    _chips += chipAmount;
    final tx = ChipTransaction(
      id: 'tx_buy_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Chip Purchase',
      subtitle: '₹$priceInr • ${formatIndianNumber(chipAmount)} Chips',
      amount: chipAmount,
      type: ChipTransactionType.chipPurchase,
    );
    _prependTransaction(tx);

    await _persistAndNotify();
    unawaited(
      _syncChipPurchaseToCloud(chipAmount: chipAmount, priceInr: priceInr),
    );
  }

  /// Credits emergency bailout chips when the player's stack drops below a
  /// table's minimum boot requirement.
  Future<int> claimBailoutChips({int amount = 2500}) async {
    _chips += amount;
    _totalRewardsEarned += amount;
    final tx = ChipTransaction(
      id: 'tx_bailout_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Club Relief Chips',
      subtitle: 'Low-stack table bailout',
      amount: amount,
      type: ChipTransactionType.dailyReward,
    );
    _prependTransaction(tx);

    await _persistAndNotify();
    unawaited(_syncBailoutToCloud());
    return amount;
  }

  /// Credits free local-only practice relief chips without touching online wallet
  /// or Supabase state.
  Future<int> claimPracticeReliefChips({int amount = 2500}) async {
    _practiceChips += amount;
    await _persistAndNotify();
    return amount;
  }

  /// Resets the free offline practice chip stack back to [defaultStack].
  Future<int> resetPracticeChips({int defaultStack = 25000}) async {
    _practiceChips = max(0, defaultStack);
    await _persistAndNotify();
    return _practiceChips;
  }

  /// Applies authoritative online chip balance received from the game worker.
  Future<void> applyOnlineChipsFromServer(int newBalance) async {
    _chips = max(0, newBalance);
    await _persistAndNotify();
  }

  /// Ensures an authenticated Supabase session aligned with [profileId], upserts
  /// client-editable identity fields, and pulls authoritative server chips/stats.
  Future<bool> prepareOnlineSession() async {
    if (!_supabase.isConfigured) return false;
    final authed = await _supabase.ensureAuthenticated();
    final uid = _supabase.authUserId;
    if (!authed || uid == null) return false;

    if (_profileId != uid) {
      _profileId = uid;
    }
    if (_playerId == 'TP458732') {
      _playerId = _playerCodeFromUid(uid);
    }

    final upserted = await _supabase.upsertProfile(_toSupabaseProfileRow());
    if (!upserted) return false;
    await syncOnlineProfileFromServer();
    await _persistAndNotify();
    return true;
  }

  static String _playerCodeFromUid(String uid) =>
      'TP${uid.replaceAll('-', '').substring(0, 8).toUpperCase()}';

  /// Refreshes server-authoritative balance & career stats from `tp_profiles`.
  Future<void> syncOnlineProfileFromServer({
    bool syncIdentityAndLedger = false,
  }) async {
    final row = await _supabase.fetchOwnProfile();
    if (row == null) return;
    _chips = (row['chips'] as num?)?.toInt() ?? _chips;
    _rating = (row['rating'] as num?)?.toInt() ?? _rating;
    _gamesPlayed = (row['games_played'] as num?)?.toInt() ?? _gamesPlayed;
    _wins = (row['wins'] as num?)?.toInt() ?? _wins;
    _currentWinStreak =
        (row['current_win_streak'] as num?)?.toInt() ?? _currentWinStreak;
    _bestStreak = (row['best_streak'] as num?)?.toInt() ?? _bestStreak;
    _dailyStreakDays =
        (row['daily_streak'] as num?)?.toInt() ?? _dailyStreakDays;
    _bestDailyStreakDays =
        (row['best_daily_streak'] as num?)?.toInt() ?? _bestDailyStreakDays;
    _totalRewardsEarned =
        (row['total_rewards_earned'] as num?)?.toInt() ?? _totalRewardsEarned;
    final serverClaimDate = row['last_daily_claim_date'] as String?;
    if (serverClaimDate != null && serverClaimDate.isNotEmpty) {
      _lastDailyClaimDate = serverClaimDate;
    }
    final serverProvider = row['linked_provider'] as String?;
    if (serverProvider != null && serverProvider.trim().isNotEmpty) {
      _linkedProvider = serverProvider.trim();
    }

    if (syncIdentityAndLedger) {
      final serverName = row['display_name'] as String?;
      if (serverName != null && serverName.trim().isNotEmpty) {
        _displayName = serverName.trim();
      }
      final serverAvatar = row['avatar_asset'] as String?;
      if (serverAvatar != null && serverAvatar.trim().isNotEmpty) {
        _avatarAsset = serverAvatar.trim();
      }
      final serverCode = row['player_code'] as String?;
      if (serverCode != null && serverCode.trim().isNotEmpty) {
        _playerId = serverCode.trim();
      }

      final remoteTxRows = await _supabase.fetchWalletTransactions(limit: 50);
      if (remoteTxRows.isNotEmpty) {
        _transactions = remoteTxRows
            .map(
              (m) => ChipTransaction(
                id: (m['id'] as String?) ?? 'tx_0',
                title: (m['title'] as String?) ?? 'Transaction',
                subtitle: (m['subtitle'] as String?) ?? '',
                amount: (m['amount'] as num?)?.toInt() ?? 0,
                type: ChipTransactionType.values.firstWhere(
                  (t) => t.name == m['type'],
                  orElse: () => ChipTransactionType.dailyReward,
                ),
              ),
            )
            .toList(growable: false);
      }
    }

    await _persistAndNotify();
  }

  /// Signs in an existing member with email and password, restoring their
  /// server profile, chip stack, and wallet ledger when Supabase is configured.
  Future<SupabaseAuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@') || !normalizedEmail.contains('.')) {
      return SupabaseAuthResult.failure('Please enter a valid email address.');
    }
    if (password.length < 6) {
      return SupabaseAuthResult.failure(
        'Password must be at least 6 characters.',
      );
    }

    if (_supabase.isConfigured) {
      final res = await _supabase.signInWithEmailPassword(
        email: normalizedEmail,
        password: password,
      );
      if (!res.succeeded) return res;

      _profileId = res.userId ?? _profileId;
      _playerId = _playerCodeFromUid(_profileId);
      _linkedProvider = 'Email ($normalizedEmail)';
      _hasCompletedOnboarding = true;

      final existingProfile = await _supabase.fetchOwnProfile();
      if (existingProfile != null) {
        await syncOnlineProfileFromServer(syncIdentityAndLedger: true);
        if (_linkedProvider == null || _linkedProvider!.isEmpty) {
          _linkedProvider = 'Email ($normalizedEmail)';
          await _supabase.upsertProfile(_toSupabaseProfileRow());
        }
      } else {
        final emailPrefix = normalizedEmail.split('@').first.trim();
        if (_displayName == 'Garv' && emailPrefix.isNotEmpty) {
          _displayName =
              emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
        }
        await _supabase.upsertProfile(_toSupabaseProfileRow());
        await syncOnlineProfileFromServer(syncIdentityAndLedger: true);
      }

      await _persistAndNotify();
      return res;
    }

    // Offline / local fallback for unconfigured environments and widget tests.
    final emailPrefix = normalizedEmail.split('@').first.trim();
    if (_displayName == 'Garv' && emailPrefix.isNotEmpty) {
      _displayName = emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
    }
    _linkedProvider = 'Email ($normalizedEmail)';
    _hasCompletedOnboarding = true;
    await _persistAndNotify();
    return SupabaseAuthResult.success(
      userId: _profileId,
      email: normalizedEmail,
    );
  }

  /// Registers a new member account with email, password, and optional nickname.
  Future<SupabaseAuthResult> registerWithEmail({
    required String email,
    required String password,
    String? nickname,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@') || !normalizedEmail.contains('.')) {
      return SupabaseAuthResult.failure('Please enter a valid email address.');
    }
    if (password.length < 6) {
      return SupabaseAuthResult.failure(
        'Password must be at least 6 characters.',
      );
    }

    final trimmedNick = nickname?.trim();
    if (trimmedNick != null && trimmedNick.isNotEmpty) {
      _displayName = trimmedNick;
    } else if (_displayName == 'Garv') {
      final prefix = normalizedEmail.split('@').first.trim();
      if (prefix.isNotEmpty) {
        _displayName = prefix[0].toUpperCase() + prefix.substring(1);
      }
    }

    if (_supabase.isConfigured) {
      final res = await _supabase.signUpWithEmailPassword(
        email: normalizedEmail,
        password: password,
        displayName: _displayName,
      );
      if (!res.succeeded) return res;

      if (res.userId != null) {
        _profileId = res.userId!;
        _playerId = _playerCodeFromUid(_profileId);
      }
      _linkedProvider = 'Email ($normalizedEmail)';
      _hasCompletedOnboarding = true;

      if (!res.requiresEmailConfirmation) {
        await _supabase.upsertProfile(_toSupabaseProfileRow());
        await syncOnlineProfileFromServer(syncIdentityAndLedger: false);
      }

      await _persistAndNotify();
      return res;
    }

    _linkedProvider = 'Email ($normalizedEmail)';
    _hasCompletedOnboarding = true;
    await _persistAndNotify();
    return SupabaseAuthResult.success(
      userId: _profileId,
      email: normalizedEmail,
    );
  }

  /// Upgrades the active Guest session by linking an email & password, keeping
  /// the player's `profileId`, chip balance, and career stats intact.
  Future<SupabaseAuthResult> linkGuestAccountWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@') || !normalizedEmail.contains('.')) {
      return SupabaseAuthResult.failure('Please enter a valid email address.');
    }
    if (password.length < 6) {
      return SupabaseAuthResult.failure(
        'Password must be at least 6 characters.',
      );
    }

    if (_supabase.isConfigured) {
      final res = await _supabase.linkEmailPassword(
        email: normalizedEmail,
        password: password,
      );
      if (!res.succeeded) return res;

      _linkedProvider = 'Email ($normalizedEmail)';
      await _persistAndNotify();
      await _syncProfileToCloud();
      return res;
    }

    _linkedProvider = 'Email ($normalizedEmail)';
    await _persistAndNotify();
    return SupabaseAuthResult.success(
      userId: _profileId,
      email: normalizedEmail,
    );
  }

  /// Syncs the player's Friends circle, live online presence, and pending
  /// table invitations from Supabase when configured.
  Future<void> syncFriendsAndInvitesFromServer() async {
    if (!_supabase.isConfigured) return;
    await _syncProfileToCloud();
    await _supabase.touchPresenceRpc();

    final remoteFriends = await _supabase.fetchFriendsDirectoryRpc();
    if (remoteFriends.isNotEmpty) {
      final parsedRemote =
          remoteFriends.map(FriendMember.fromJson).toList(growable: false);
      final remoteById = <String, FriendMember>{
        for (final f in parsedRemote) f.id: f,
      };
      final merged = <FriendMember>[...parsedRemote];
      for (final local in _friends) {
        if (!remoteById.containsKey(local.id) &&
            !parsedRemote.any(
              (r) =>
                  r.playerCode != null &&
                  local.playerCode != null &&
                  r.playerCode!.toUpperCase() ==
                      local.playerCode!.toUpperCase(),
            )) {
          merged.add(local);
        }
      }
      _friends = merged;
    }

    final remoteInvites = await _supabase.fetchPendingRoomInvitesRpc();
    _pendingRoomInvites =
        remoteInvites.map(TableRoomInvite.fromJson).toList(growable: false);
    await _persistAndNotify();
  }

  /// Connects a friend by their Player ID or Invite Code via Supabase RPC
  /// (`tp_add_friend_by_code`) when configured, or locally when offline.
  Future<FriendMember> addFriendByCode(String rawCode) async {
    final cleaned = rawCode.trim().toUpperCase();
    if (cleaned.isEmpty) {
      throw const OnlineMatchmakingException(
        'Enter a valid Player ID or Invite Code.',
      );
    }
    if (cleaned == _playerId.toUpperCase()) {
      throw const OnlineMatchmakingException(
        'You cannot add your own Player ID.',
      );
    }

    FriendMember added;
    if (_supabase.isConfigured) {
      await _syncProfileToCloud();
      final row = await _supabase.addFriendByCodeRpc(cleaned);
      if (row == null) {
        throw OnlineMatchmakingException(
          'No player found with code $cleaned.',
        );
      }
      added = FriendMember.fromJson(row);
    } else {
      final normalizedCode =
          cleaned.startsWith('TP') ? cleaned : 'TP$cleaned';
      const avatars = <String>[
        AppAssets.avatar2,
        AppAssets.avatar3,
        AppAssets.avatar4,
        AppAssets.avatar5,
      ];
      final avatar = avatars[cleaned.hashCode.abs() % avatars.length];
      added = FriendMember(
        id: 'fr_${cleaned.toLowerCase()}',
        playerCode: normalizedCode,
        name: 'Member ${cleaned.substring(0, min(6, cleaned.length))}',
        avatarAsset: avatar,
        isOnline: true,
        statusText: 'Online',
        isRecentlyPlayed: false,
      );
    }

    _friends = <FriendMember>[
      added,
      ..._friends.where(
        (f) =>
            f.id != added.id &&
            (f.playerCode == null ||
                added.playerCode == null ||
                f.playerCode!.toUpperCase() !=
                    added.playerCode!.toUpperCase()),
      ),
    ];
    await _persistAndNotify();
    return added;
  }

  /// Removes a friend from the player's circle and deletes the server friendship.
  Future<void> removeFriend(String friendId) async {
    _friends = _friends.where((f) => f.id != friendId).toList(growable: false);
    await _persistAndNotify();
    if (_supabase.isConfigured) {
      unawaited(_supabase.removeFriendRpc(friendId));
    }
  }

  /// Sends an in-app table invite notification to [friend] for [roomCode].
  Future<bool> sendTableInviteToFriend({
    required FriendMember friend,
    required String roomCode,
    String? roomId,
    String tableName = 'Private Club',
    String variant = 'Classic',
    int minStake = 100,
  }) async {
    final cleanedCode = roomCode.trim().toUpperCase();
    if (cleanedCode.isEmpty) return false;
    if (_supabase.isConfigured) {
      await _syncProfileToCloud();
      final res = await _supabase.sendRoomInviteRpc(
        friendId: friend.id,
        roomCode: cleanedCode,
        roomId: roomId,
        tableName: tableName,
        variant: variant,
        minStake: minStake,
      );
      return res != null;
    }
    return true;
  }

  /// Accepts or declines a pending in-app table invite and returns the target
  /// `roomCode` when accepted.
  Future<String?> respondToTableInvite({
    required String inviteId,
    required bool accept,
  }) async {
    TableRoomInvite? target;
    for (final inv in _pendingRoomInvites) {
      if (inv.id == inviteId) {
        target = inv;
        break;
      }
    }
    _pendingRoomInvites = _pendingRoomInvites
        .where((inv) => inv.id != inviteId)
        .toList(growable: false);
    notifyListeners();

    if (_supabase.isConfigured) {
      final row = await _supabase.respondRoomInviteRpc(
        inviteId: inviteId,
        accept: accept,
      );
      if (accept && row != null && row['room_code'] is String) {
        return (row['room_code'] as String).trim().toUpperCase();
      }
    }
    return accept ? target?.roomCode : null;
  }

  /// Pushes a live in-app room invite into the session store.
  void pushIncomingRoomInvite(TableRoomInvite invite) {
    _pendingRoomInvites = <TableRoomInvite>[
      invite,
      ..._pendingRoomInvites.where((i) => i.id != invite.id),
    ];
    notifyListeners();
  }

  /// Records a finished Teen Patti round: syncs balance, appends `Game Entry`
  /// and `Game Win` wallet transactions, updates profile stats, and syncs to cloud.
  Future<void> recordCompletedRound({
    required String tableName,
    required String variant,
    required int bootAmount,
    required int roundNumber,
    required int previousBalance,
    required int newBalance,
    required int potAmount,
    required int localTotalBet,
    required bool isLocalWinner,
    required String handLabel,
    required String winReason,
    bool isPractice = false,
  }) async {
    if (isPractice) {
      _practiceChips = max(0, newBalance);
      await _persistAndNotify();
      return;
    }

    _chips = max(0, newBalance);
    _gamesPlayed += 1;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final syncedTransactions = <ChipTransaction>[];

    if (localTotalBet > 0) {
      final entryTx = ChipTransaction(
        id: 'tx_entry_${nowMs}_$roundNumber',
        title: 'Game Entry',
        subtitle: '$tableName • Round $roundNumber',
        amount: -localTotalBet,
        type: ChipTransactionType.gameEntry,
      );
      _prependTransaction(entryTx);
      syncedTransactions.add(entryTx);
    }

    if (isLocalWinner) {
      _wins += 1;
      _currentWinStreak += 1;
      if (_currentWinStreak > _bestStreak) {
        _bestStreak = _currentWinStreak;
      }
      _rating += 15;
      _weeklyGamesWon[6] += 1;
      _weeklyChipsWon[6] += max(1, (potAmount / 1000).round());

      final winTx = ChipTransaction(
        id: 'tx_win_${nowMs}_$roundNumber',
        title: 'Game Win',
        subtitle: '$tableName • $handLabel',
        amount: potAmount,
        type: ChipTransactionType.gameWin,
      );
      _prependTransaction(winTx);
      syncedTransactions.add(winTx);
    } else {
      _currentWinStreak = 0;
      _rating = max(800, _rating - 8);
    }

    _weeklyWinRate[6] = winRatePercent.round();

    await _persistAndNotify();
    unawaited(
      _syncRoundToCloud(
        transactions: syncedTransactions,
        historyRow: <String, dynamic>{
          'profile_id': _profileId,
          'table_name': tableName,
          'variant': variant,
          'boot_amount': bootAmount,
          'pot_amount': potAmount,
          'net_chips': newBalance - previousBalance,
          'won': isLocalWinner,
          'hand_label': handLabel,
          'win_reason': winReason,
        },
      ),
    );
  }

  /// Updates music/SFX volume in memory and notifies listeners live during
  /// slider drags without triggering storage writes or cloud requests per tick.
  void previewAudioVolumes({
    double? musicVolume,
    double? sfxVolume,
  }) {
    var changed = false;
    if (musicVolume != null) {
      final next = musicVolume.clamp(0.0, 1.0);
      if (next != _musicVolume) {
        _musicVolume = next;
        changed = true;
      }
    }
    if (sfxVolume != null) {
      final next = sfxVolume.clamp(0.0, 1.0);
      if (next != _sfxVolume) {
        _sfxVolume = next;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Updates sound/music/vibration settings and volumes, persisting locally.
  Future<void> updateSettings({
    bool? soundEffects,
    bool? backgroundMusic,
    bool? vibration,
    double? musicVolume,
    double? sfxVolume,
  }) async {
    if (soundEffects != null) _soundEffects = soundEffects;
    if (backgroundMusic != null) _backgroundMusic = backgroundMusic;
    if (vibration != null) _vibration = vibration;
    if (musicVolume != null) _musicVolume = musicVolume.clamp(0.0, 1.0);
    if (sfxVolume != null) _sfxVolume = sfxVolume.clamp(0.0, 1.0);

    await _persistAndNotify();
    unawaited(_syncProfileToCloud());
  }

  /// Signs out active onboarding session while keeping stored preferences clean.
  Future<void> logout() async {
    _hasCompletedOnboarding = false;
    _supabase.clearTokens();
    await _persistAndNotify();
  }

  /// Builds [WalletData] snapshot from unified session state.
  WalletData toWalletData() {
    return WalletData(
      balance: _chips,
      hasClaimableFreeChips: !isDailyRewardClaimedToday(),
      dailyClaimAmount: todayDailyRewardAmount,
      streakBonusUpTo: rewardLadder.last,
      watchEarnAmount: 1000,
      transactions: List.unmodifiable(_transactions),
    );
  }

  /// Builds [PlayerProfileData] snapshot from unified session state.
  PlayerProfileData toPlayerProfileData() {
    final tier = _chips >= 100000
        ? 'VIP Royal'
        : (_chips >= 50000 ? 'High Roller' : 'Club Member');
    return PlayerProfileData(
      name: _displayName,
      playerId: _playerId,
      avatarAsset: _avatarAsset,
      tierLabel: tier,
      chipBalance: _chips,
      gamesPlayed: _gamesPlayed,
      wins: _wins,
      winRatePercent: winRatePercent,
      bestStreak: _bestStreak,
      weeklyPerformance: <PerformanceMetric, List<double>>{
        PerformanceMetric.gamesWon:
            _weeklyGamesWon.map((v) => v.toDouble()).toList(growable: false),
        PerformanceMetric.chipsWon:
            _weeklyChipsWon.map((v) => v.toDouble()).toList(growable: false),
        PerformanceMetric.winRate:
            _weeklyWinRate.map((v) => v.toDouble()).toList(growable: false),
      },
    );
  }

  /// Builds [DailyRewardsData] snapshot from unified session state.
  DailyRewardsData toDailyRewardsData() {
    final claimedToday = isDailyRewardClaimedToday();
    final activeDay = ((_dailyStreakDays - 1) % 7) + 1;
    final nextDay = activeDay < 7 ? activeDay + 1 : 7;

    final days = List<DailyRewardDay>.generate(7, (idx) {
      final dayNum = idx + 1;
      final status = dayNum < activeDay
          ? DailyRewardCardStatus.claimed
          : (dayNum == activeDay
              ? (claimedToday
                  ? DailyRewardCardStatus.claimed
                  : DailyRewardCardStatus.current)
              : DailyRewardCardStatus.locked);

      return DailyRewardDay(
        dayNumber: dayNum,
        amount: rewardLadder[idx],
        status: status,
        isGrandBonus: dayNum == 7,
      );
    });

    return DailyRewardsData(
      currentStreakDays: _dailyStreakDays,
      nextRewardDay: nextDay,
      nextRewardAmount: rewardLadder[nextDay - 1],
      totalRewardsEarned: _totalRewardsEarned,
      streakRecordDays: _bestDailyStreakDays,
      isTodayClaimed: claimedToday,
      days: days,
    );
  }

  /// Builds [AppSettingsState] snapshot from unified session state.
  AppSettingsState toSettingsState() {
    return AppSettingsState(
      soundEffects: _soundEffects,
      backgroundMusic: _backgroundMusic,
      vibration: _vibration,
      musicVolume: _musicVolume,
      sfxVolume: _sfxVolume,
      playerName: _displayName,
      playerId: _playerId,
      avatarAsset: _avatarAsset,
      linkedProvider: _linkedProvider,
    );
  }

  void _prependTransaction(ChipTransaction tx) {
    _transactions = [tx, ..._transactions].take(100).toList(growable: false);
  }

  Future<void> _persistAndNotify() async {
    notifyListeners();
    await _storage.writeJson(_storageKey, jsonEncode(_toJson()));
  }

  Future<void> _syncProfileToCloud() async {
    if (!_supabase.isConfigured) return;
    final authed = await _supabase.ensureAuthenticated();
    if (authed && _supabase.authUserId != null) {
      _profileId = _supabase.authUserId!;
      if (_playerId == 'TP458732') {
        _playerId = _playerCodeFromUid(_profileId);
      }
    }
    final ok = await _supabase.upsertProfile(_toSupabaseProfileRow());
    if (ok) {
      // Persist aligned profileId & refreshed auth tokens if sign-in completed.
      await _storage.writeJson(_storageKey, jsonEncode(_toJson()));
    }
  }

  Future<void> _syncDailyRewardToCloud(ChipTransaction localTx) async {
    if (!_supabase.isConfigured) return;
    await _syncProfileToCloud();
    final row = await _supabase.claimDailyRewardRpc();
    if (row != null) {
      _chips = (row['new_chips'] as num?)?.toInt() ?? _chips;
      _dailyStreakDays =
          (row['daily_streak'] as num?)?.toInt() ?? _dailyStreakDays;
      _bestDailyStreakDays =
          (row['best_daily_streak'] as num?)?.toInt() ?? _bestDailyStreakDays;
      _totalRewardsEarned =
          (row['total_rewards_earned'] as num?)?.toInt() ?? _totalRewardsEarned;
      _lastDailyClaimDate =
          (row['claim_date'] as String?) ?? _lastDailyClaimDate;
      await _persistAndNotify();
    } else {
      await _supabase.insertWalletTransaction(_toSupabaseTxRow(localTx));
    }
  }

  Future<void> _syncWatchRewardToCloud() async {
    if (!_supabase.isConfigured) return;
    await _syncProfileToCloud();
    final row = await _supabase.claimWatchRewardRpc();
    if (row != null) {
      _chips = (row['new_chips'] as num?)?.toInt() ?? _chips;
      _totalRewardsEarned =
          (row['total_rewards_earned'] as num?)?.toInt() ?? _totalRewardsEarned;
      await _persistAndNotify();
    }
  }

  Future<void> _syncBailoutToCloud() async {
    if (!_supabase.isConfigured) return;
    await _syncProfileToCloud();
    final row = await _supabase.claimBailoutChipsRpc();
    if (row != null) {
      _chips = (row['new_chips'] as num?)?.toInt() ?? _chips;
      _totalRewardsEarned =
          (row['total_rewards_earned'] as num?)?.toInt() ?? _totalRewardsEarned;
      await _persistAndNotify();
    }
  }

  Future<void> _syncChipPurchaseToCloud({
    required int chipAmount,
    required int priceInr,
  }) async {
    if (!_supabase.isConfigured) return;
    await _syncProfileToCloud();
    final row = await _supabase.claimChipPackRpc(
      chipAmount: chipAmount,
      priceInr: priceInr,
    );
    if (row != null) {
      _chips = (row['new_chips'] as num?)?.toInt() ?? _chips;
      await _persistAndNotify();
    }
  }

  Future<void> _syncRoundToCloud({
    required List<ChipTransaction> transactions,
    required Map<String, dynamic> historyRow,
  }) async {
    if (!_supabase.isConfigured) return;
    final authed = await _supabase.ensureAuthenticated();
    if (authed && _supabase.authUserId != null) {
      _profileId = _supabase.authUserId!;
    }
    await _supabase.upsertProfile(_toSupabaseProfileRow());
    for (final tx in transactions) {
      await _supabase.insertWalletTransaction(_toSupabaseTxRow(tx));
    }
    await _supabase.insertGameHistory(<String, dynamic>{
      ...historyRow,
      'profile_id': _profileId,
    });
  }

  Map<String, dynamic> _toSupabaseProfileRow() {
    return <String, dynamic>{
      'id': _supabase.authUserId ?? _profileId,
      'player_code': _playerId,
      'display_name': _displayName,
      'avatar_asset': _avatarAsset,
      'linked_provider': _linkedProvider,
      'daily_streak': _dailyStreakDays,
      'best_daily_streak': _bestDailyStreakDays,
      'last_daily_claim_date': _lastDailyClaimDate,
      'sound_effects': _soundEffects,
      'background_music': _backgroundMusic,
      'vibration': _vibration,
      'weekly_games_won': _weeklyGamesWon,
      'weekly_chips_won': _weeklyChipsWon,
      'weekly_win_rate': _weeklyWinRate,
    };
  }

  Map<String, dynamic> _toSupabaseTxRow(ChipTransaction tx) {
    return <String, dynamic>{
      'id': tx.id,
      'profile_id': _profileId,
      'type': tx.type.name,
      'title': tx.title,
      'subtitle': tx.subtitle,
      'amount': tx.amount,
    };
  }

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'profileId': _profileId,
      'playerId': _playerId,
      'displayName': _displayName,
      'avatarAsset': _avatarAsset,
      'linkedProvider': _linkedProvider,
      'hasCompletedOnboarding': _hasCompletedOnboarding,
      'chips': _chips,
      'practiceChips': _practiceChips,
      'rating': _rating,
      'gamesPlayed': _gamesPlayed,
      'wins': _wins,
      'currentWinStreak': _currentWinStreak,
      'bestStreak': _bestStreak,
      'dailyStreakDays': _dailyStreakDays,
      'bestDailyStreakDays': _bestDailyStreakDays,
      'totalRewardsEarned': _totalRewardsEarned,
      'lastDailyClaimDate': _lastDailyClaimDate,
      'soundEffects': _soundEffects,
      'backgroundMusic': _backgroundMusic,
      'vibration': _vibration,
      'musicVolume': _musicVolume,
      'sfxVolume': _sfxVolume,
      'weeklyGamesWon': _weeklyGamesWon,
      'weeklyChipsWon': _weeklyChipsWon,
      'weeklyWinRate': _weeklyWinRate,
      'supabaseAccessToken': _supabase.accessToken,
      'supabaseRefreshToken': _supabase.refreshToken,
      'supabaseAuthUserId': _supabase.authUserId,
      'supabaseUserEmail': _supabase.userEmail,
      'transactions': _transactions
          .map(
            (tx) => <String, dynamic>{
              'id': tx.id,
              'title': tx.title,
              'subtitle': tx.subtitle,
              'amount': tx.amount,
              'type': tx.type.name,
            },
          )
          .toList(growable: false),
      'friends': _friends.map((f) => f.toJson()).toList(growable: false),
    };
  }

  void _applyJson(Map<String, dynamic> json) {
    _profileId = (json['profileId'] as String?) ?? _profileId;
    _playerId = (json['playerId'] as String?) ?? _playerId;
    _displayName = (json['displayName'] as String?) ?? _displayName;
    _avatarAsset = (json['avatarAsset'] as String?) ?? _avatarAsset;
    _linkedProvider = json['linkedProvider'] as String?;
    _hasCompletedOnboarding =
        (json['hasCompletedOnboarding'] as bool?) ?? false;
    _chips = (json['chips'] as num?)?.toInt() ?? _chips;
    _practiceChips = (json['practiceChips'] as num?)?.toInt() ?? _practiceChips;
    _rating = (json['rating'] as num?)?.toInt() ?? _rating;
    _gamesPlayed = (json['gamesPlayed'] as num?)?.toInt() ?? 0;
    _wins = (json['wins'] as num?)?.toInt() ?? 0;
    _currentWinStreak = (json['currentWinStreak'] as num?)?.toInt() ?? 0;
    _bestStreak = (json['bestStreak'] as num?)?.toInt() ?? 0;
    _dailyStreakDays = (json['dailyStreakDays'] as num?)?.toInt() ?? 5;
    _bestDailyStreakDays =
        (json['bestDailyStreakDays'] as num?)?.toInt() ?? 12;
    _totalRewardsEarned =
        (json['totalRewardsEarned'] as num?)?.toInt() ?? 6200;
    _lastDailyClaimDate = json['lastDailyClaimDate'] as String?;
    _soundEffects = (json['soundEffects'] as bool?) ?? true;
    _backgroundMusic = (json['backgroundMusic'] as bool?) ?? true;
    _vibration = (json['vibration'] as bool?) ?? true;
    _musicVolume =
        ((json['musicVolume'] as num?)?.toDouble() ?? 0.25).clamp(0.0, 1.0);
    _sfxVolume =
        ((json['sfxVolume'] as num?)?.toDouble() ?? 0.85).clamp(0.0, 1.0);

    _weeklyGamesWon = _parseIntList(json['weeklyGamesWon'], _weeklyGamesWon);
    _weeklyChipsWon = _parseIntList(json['weeklyChipsWon'], _weeklyChipsWon);
    _weeklyWinRate = _parseIntList(json['weeklyWinRate'], _weeklyWinRate);

    _supabase.restoreTokens(
      accessToken: json['supabaseAccessToken'] as String?,
      refreshToken: json['supabaseRefreshToken'] as String?,
      authUserId: json['supabaseAuthUserId'] as String?,
      userEmail: json['supabaseUserEmail'] as String?,
    );

    final rawTx = json['transactions'];
    if (rawTx is List) {
      _transactions = rawTx
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => ChipTransaction(
              id: (m['id'] as String?) ?? 'tx_0',
              title: (m['title'] as String?) ?? 'Transaction',
              subtitle: (m['subtitle'] as String?) ?? '',
              amount: (m['amount'] as num?)?.toInt() ?? 0,
              type: ChipTransactionType.values.firstWhere(
                (t) => t.name == m['type'],
                orElse: () => ChipTransactionType.dailyReward,
              ),
            ),
          )
          .toList(growable: false);
    }

    final rawFriends = json['friends'];
    if (rawFriends is List && rawFriends.isNotEmpty) {
      _friends = rawFriends
          .whereType<Map<String, dynamic>>()
          .map(FriendMember.fromJson)
          .toList(growable: false);
    }
  }

  static List<int> _parseIntList(Object? raw, List<int> fallback) {
    if (raw is List && raw.length == 7) {
      return raw.map((e) => (e as num?)?.toInt() ?? 0).toList(growable: false);
    }
    return fallback;
  }

  static String _generateUuidV4() {
    final rng = Random();
    String hex(int count) => List.generate(
          count,
          (_) => rng.nextInt(16).toRadixString(16),
        ).join();
    final variant = (8 + rng.nextInt(4)).toRadixString(16);
    return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
  }
}
