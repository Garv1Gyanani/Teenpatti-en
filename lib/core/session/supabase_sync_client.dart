import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error surfaced by Supabase matchmaking or private-room RPC calls.
class OnlineMatchmakingException implements Exception {
  const OnlineMatchmakingException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Result of an email/password sign-in, sign-up, or guest account link call.
class SupabaseAuthResult {
  const SupabaseAuthResult({
    required this.succeeded,
    this.userId,
    this.email,
    this.errorMessage,
    this.requiresEmailConfirmation = false,
  });

  factory SupabaseAuthResult.success({
    required String userId,
    required String email,
    bool requiresEmailConfirmation = false,
  }) {
    return SupabaseAuthResult(
      succeeded: true,
      userId: userId,
      email: email,
      requiresEmailConfirmation: requiresEmailConfirmation,
    );
  }

  factory SupabaseAuthResult.failure(String message) {
    return SupabaseAuthResult(
      succeeded: false,
      errorMessage: message,
    );
  }

  final bool succeeded;
  final String? userId;
  final String? email;
  final String? errorMessage;
  final bool requiresEmailConfirmation;
}

/// Seated table ticket returned by Supabase matchmaking or private-room RPCs.
class OnlineRoomTicket {
  const OnlineRoomTicket({
    required this.roomId,
    required this.seatIndex,
    required this.tableName,
    required this.variant,
    required this.minStake,
    required this.maxStake,
    required this.maxPlayers,
    required this.fillWithAi,
    required this.isPrivate,
    this.roomCode,
    this.status = 'waiting',
  });

  factory OnlineRoomTicket.fromJson(
    Map<String, dynamic> json, {
    required bool isPrivate,
  }) {
    return OnlineRoomTicket(
      roomId: json['room_id'] as String,
      roomCode: json['room_code'] as String?,
      seatIndex: (json['seat_index'] as num?)?.toInt() ?? 0,
      tableName: (json['table_name'] as String?) ?? 'Club Table',
      variant: (json['variant'] as String?) ?? 'Classic',
      minStake: (json['min_stake'] as num?)?.toInt() ?? 100,
      maxStake: (json['max_stake'] as num?)?.toInt() ?? 3200,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 5,
      fillWithAi: json['fill_with_ai'] as bool? ?? !isPrivate,
      isPrivate: isPrivate,
      status: (json['status'] as String?) ?? 'waiting',
    );
  }

  final String roomId;
  final String? roomCode;
  final int seatIndex;
  final String tableName;
  final String variant;
  final int minStake;
  final int maxStake;
  final int maxPlayers;
  final bool fillWithAi;
  final bool isPrivate;
  final String status;
}

/// Cloud sync client for Supabase Auth, PostgREST (`tp_profiles`,
/// `tp_wallet_transactions`, `tp_game_history`), and matchmaking RPCs.
///
/// Configured via `--dart-define=SUPABASE_URL=...` and
/// `--dart-define=SUPABASE_ANON_KEY=...`. Safely no-ops when unconfigured or
/// offline so local persistence remains authoritative.
class SupabaseSyncClient {
  SupabaseSyncClient({
    required String supabaseUrl,
    required this.supabaseAnonKey,
    http.Client? httpClient,
  })  : supabaseUrl = _normalizeUrl(supabaseUrl),
        _http = httpClient ?? http.Client();

  factory SupabaseSyncClient.fromEnvironment({http.Client? httpClient}) {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return SupabaseSyncClient(
      supabaseUrl: url.trim(),
      supabaseAnonKey: anonKey.trim(),
      httpClient: httpClient,
    );
  }

  static String _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static const Set<String> _serverProtectedProfileColumns = <String>{
    'chips',
    'rating',
    'games_played',
    'wins',
    'current_win_streak',
    'best_streak',
    'total_rewards_earned',
  };

  final String supabaseUrl;
  final String supabaseAnonKey;
  final http.Client _http;

  String? _accessToken;
  String? _refreshToken;
  String? _authUserId;
  String? _userEmail;
  Future<bool>? _authInFlight;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get authUserId => _authUserId;
  String? get userEmail => _userEmail;

  /// WebSocket base URL for `realtime_client` (`ws(s)://.../realtime/v1`).
  String get realtimeWebSocketUrl {
    final trimmed = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    if (trimmed.startsWith('https://')) {
      return 'wss://${trimmed.substring('https://'.length)}/realtime/v1';
    }
    if (trimmed.startsWith('http://')) {
      return 'ws://${trimmed.substring('http://'.length)}/realtime/v1';
    }
    return '$trimmed/realtime/v1';
  }

  void restoreTokens({
    String? accessToken,
    String? refreshToken,
    String? authUserId,
    String? userEmail,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _authUserId = authUserId;
    _userEmail = userEmail;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
    _authUserId = null;
    _userEmail = null;
  }

  Map<String, String> _headers({bool preferMerge = false}) {
    final bearer = _accessToken ?? supabaseAnonKey;
    return <String, String>{
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $bearer',
      'Content-Type': 'application/json',
      if (preferMerge) 'Prefer': 'resolution=merge-duplicates,return=minimal',
    };
  }

  /// Ensures an anonymous or refreshed Supabase Auth session is active.
  Future<bool> ensureAuthenticated() {
    if (!isConfigured) return Future<bool>.value(false);
    if (_accessToken != null && _authUserId != null) {
      return Future<bool>.value(true);
    }
    return _authInFlight ??= _authenticateNow().whenComplete(() {
      _authInFlight = null;
    });
  }

  Future<bool> _authenticateNow() async {
    try {
      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        final refreshUri = Uri.parse(
          '$supabaseUrl/auth/v1/token?grant_type=refresh_token',
        );
        final refreshResp = await _http.post(
          refreshUri,
          headers: <String, String>{
            'apikey': supabaseAnonKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{'refresh_token': _refreshToken}),
        );
        if (refreshResp.statusCode >= 200 && refreshResp.statusCode < 300) {
          _parseAuthResponse(refreshResp.body);
          return _accessToken != null;
        }
      }

      // Sign in anonymously via GoTrue /auth/v1/signup with empty credentials.
      final signupUri = Uri.parse('$supabaseUrl/auth/v1/signup');
      final resp = await _http.post(
        signupUri,
        headers: <String, String>{
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'data': <String, dynamic>{}}),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _parseAuthResponse(resp.body);
        return _accessToken != null;
      }
    } catch (_) {
      // Offline or unreachable — local cache handles persistence.
    }
    return false;
  }

  /// Refreshes the active Supabase Auth JWT, falling back to anonymous sign-in
  /// when no valid refresh token is available.
  Future<bool> refreshSession() async {
    if (!isConfigured) return false;
    try {
      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        final refreshUri = Uri.parse(
          '$supabaseUrl/auth/v1/token?grant_type=refresh_token',
        );
        final refreshResp = await _http.post(
          refreshUri,
          headers: <String, String>{
            'apikey': supabaseAnonKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{'refresh_token': _refreshToken}),
        );
        if (refreshResp.statusCode >= 200 && refreshResp.statusCode < 300) {
          _parseAuthResponse(refreshResp.body);
          if (_accessToken != null && _authUserId != null) {
            return true;
          }
        }
      }
    } catch (_) {
      // Fall through to ensureAuthenticated.
    }
    _accessToken = null;
    return ensureAuthenticated();
  }

  void _parseAuthResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return;
    _accessToken = (decoded['access_token'] as String?) ?? _accessToken;
    _refreshToken = (decoded['refresh_token'] as String?) ?? _refreshToken;
    final user = decoded['user'];
    if (user is Map<String, dynamic>) {
      _authUserId = (user['id'] as String?) ?? _authUserId;
      final email = user['email'] as String?;
      if (email != null && email.trim().isNotEmpty) {
        _userEmail = email.trim();
      }
    } else if (decoded['id'] is String) {
      _authUserId = decoded['id'] as String;
      final email = decoded['email'] as String?;
      if (email != null && email.trim().isNotEmpty) {
        _userEmail = email.trim();
      }
    }
  }

  String _extractAuthError(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final msg = (decoded['msg'] as String?) ??
            (decoded['error_description'] as String?) ??
            (decoded['message'] as String?) ??
            (decoded['error'] as String?);
        if (msg != null && msg.trim().isNotEmpty) {
          return msg.trim();
        }
      }
    } catch (_) {}
    return fallback;
  }

  /// Signs in an existing account using email & password via Supabase Auth.
  Future<SupabaseAuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!isConfigured) {
      return SupabaseAuthResult.failure('Online server is not configured.');
    }
    try {
      final uri = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
      final resp = await _http.post(
        uri,
        headers: <String, String>{
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'email': normalizedEmail,
          'password': password,
        }),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _parseAuthResponse(resp.body);
        if (_accessToken != null && _authUserId != null) {
          _userEmail = normalizedEmail;
          return SupabaseAuthResult.success(
            userId: _authUserId!,
            email: _userEmail!,
          );
        }
      }
      return SupabaseAuthResult.failure(
        _extractAuthError(resp.body, 'Invalid email or password.'),
      );
    } catch (_) {
      return SupabaseAuthResult.failure(
        'Could not reach authentication server.',
      );
    }
  }

  /// Creates a new email & password account via Supabase Auth.
  Future<SupabaseAuthResult> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!isConfigured) {
      return SupabaseAuthResult.failure('Online server is not configured.');
    }
    try {
      final uri = Uri.parse('$supabaseUrl/auth/v1/signup');
      final resp = await _http.post(
        uri,
        headers: <String, String>{
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'email': normalizedEmail,
          'password': password,
          if (displayName != null && displayName.trim().isNotEmpty)
            'data': <String, dynamic>{'display_name': displayName.trim()},
        }),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _parseAuthResponse(resp.body);
        if (_accessToken != null && _authUserId != null) {
          _userEmail = normalizedEmail;
          return SupabaseAuthResult.success(
            userId: _authUserId!,
            email: normalizedEmail,
          );
        }
        if (_authUserId != null) {
          return SupabaseAuthResult.success(
            userId: _authUserId!,
            email: normalizedEmail,
            requiresEmailConfirmation: true,
          );
        }
      }
      return SupabaseAuthResult.failure(
        _extractAuthError(resp.body, 'Could not create account.'),
      );
    } catch (_) {
      return SupabaseAuthResult.failure(
        'Could not reach authentication server.',
      );
    }
  }

  /// Links an email and password to the current anonymous guest session
  /// (`PUT /auth/v1/user`), preserving `auth.uid()`, chips, and career stats.
  Future<SupabaseAuthResult> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!isConfigured) {
      return SupabaseAuthResult.failure('Online server is not configured.');
    }
    final authed = await ensureAuthenticated();
    if (!authed || _accessToken == null || _authUserId == null) {
      return SupabaseAuthResult.failure('No active session to link.');
    }

    try {
      final uri = Uri.parse('$supabaseUrl/auth/v1/user');
      final resp = await _http.put(
        uri,
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{
          'email': normalizedEmail,
          'password': password,
        }),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _parseAuthResponse(resp.body);
        _userEmail = normalizedEmail;
        return SupabaseAuthResult.success(
          userId: _authUserId!,
          email: normalizedEmail,
        );
      }
      return SupabaseAuthResult.failure(
        _extractAuthError(resp.body, 'Could not link email to this account.'),
      );
    } catch (_) {
      return SupabaseAuthResult.failure(
        'Could not reach authentication server.',
      );
    }
  }

  /// Upserts client-editable profile fields in `public.tp_profiles`.
  ///
  /// Strips server-protected chip/rating/career stat columns and aligns `id`
  /// with `auth.uid()` to satisfy RLS and `tp_enforce_profile_server_fields`.
  Future<bool> upsertProfile(Map<String, dynamic> profileRow) async {
    if (!isConfigured) return false;
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) return false;

    try {
      final sanitized = <String, dynamic>{
        for (final entry in profileRow.entries)
          if (!_serverProtectedProfileColumns.contains(entry.key))
            entry.key: entry.value,
        'id': _authUserId,
        'auth_user_id': _authUserId,
      };
      final uri = Uri.parse('$supabaseUrl/rest/v1/tp_profiles?on_conflict=id');
      var resp = await _http.post(
        uri,
        headers: _headers(preferMerge: true),
        body: jsonEncode(sanitized),
      );
      if (resp.statusCode == 409) {
        sanitized['player_code'] =
            'TP${_authUserId!.replaceAll('-', '').substring(0, 8).toUpperCase()}';
        resp = await _http.post(
          uri,
          headers: _headers(preferMerge: true),
          body: jsonEncode(sanitized),
        );
      }
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Reads the authenticated player's server-authoritative profile & balance.
  Future<Map<String, dynamic>?> fetchOwnProfile() async {
    if (!isConfigured) return null;
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) return null;

    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/tp_profiles?id=eq.$_authUserId&select=id,player_code,display_name,avatar_asset,linked_provider,chips,rating,games_played,wins,current_win_streak,best_streak,daily_streak,best_daily_streak,total_rewards_earned,last_daily_claim_date,sound_effects,background_music,vibration,weekly_games_won,weekly_chips_won,weekly_win_rate&limit=1',
      );
      final resp = await _http.get(uri, headers: _headers());
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List && decoded.isNotEmpty) {
          final first = decoded.first;
          if (first is Map<String, dynamic>) return first;
        }
      }
    } catch (_) {
      // Offline / transient network error.
    }
    return null;
  }

  /// Reads the authenticated player's recent wallet ledger rows from Supabase.
  Future<List<Map<String, dynamic>>> fetchWalletTransactions({
    int limit = 50,
  }) async {
    if (!isConfigured) return const <Map<String, dynamic>>[];
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) return const <Map<String, dynamic>>[];

    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/tp_wallet_transactions?profile_id=eq.$_authUserId&select=id,type,title,subtitle,amount,created_at&order=created_at.desc&limit=$limit',
      );
      final resp = await _http.get(uri, headers: _headers());
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> _callWalletRpc(
    String rpcName, [
    Map<String, dynamic> body = const <String, dynamic>{},
  ]) async {
    if (!isConfigured) return null;
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) return null;

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/$rpcName');
      final resp = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode(body),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          return Map<String, dynamic>.from(decoded.first as Map);
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Atomically claims today's daily streak reward via `tp_claim_daily_reward`.
  Future<Map<String, dynamic>?> claimDailyRewardRpc() =>
      _callWalletRpc('tp_claim_daily_reward');

  /// Atomically claims a Watch & Earn reward via `tp_claim_watch_reward`.
  Future<Map<String, dynamic>?> claimWatchRewardRpc() =>
      _callWalletRpc('tp_claim_watch_reward');

  /// Atomically claims low-stack relief chips via `tp_claim_bailout_chips`.
  Future<Map<String, dynamic>?> claimBailoutChipsRpc({int minBoot = 100}) =>
      _callWalletRpc(
        'tp_claim_bailout_chips',
        <String, dynamic>{'p_min_boot': minBoot},
      );

  /// Atomically credits a validated chip store pack via `tp_claim_chip_pack`.
  Future<Map<String, dynamic>?> claimChipPackRpc({
    required int chipAmount,
    required int priceInr,
  }) =>
      _callWalletRpc(
        'tp_claim_chip_pack',
        <String, dynamic>{
          'p_chip_amount': chipAmount,
          'p_price_inr': priceInr,
        },
      );

  /// Joins an open public room matching stake/variant or creates a new one.
  Future<OnlineRoomTicket?> joinOrCreatePublicRoom({
    int minStake = 100,
    int maxStake = 3200,
    int maxPlayers = 5,
    String variant = 'Classic',
    String tableName = 'Classic Club',
  }) async {
    return _callRoomRpc(
      rpcName: 'tp_join_or_create_public_room',
      body: <String, dynamic>{
        'p_min_stake': minStake,
        'p_max_stake': maxStake,
        'p_max_players': maxPlayers,
        'p_variant': variant,
        'p_table_name': tableName,
      },
      isPrivate: false,
    );
  }

  /// Creates an invite-only private room (`fillWithAi` defaults to `false`).
  Future<OnlineRoomTicket?> createPrivateRoom({
    String tableName = 'Royal Private Room',
    String variant = 'Classic',
    int minStake = 250,
    int maxStake = 8000,
    int maxPlayers = 5,
    bool fillWithAi = false,
  }) async {
    return _callRoomRpc(
      rpcName: 'tp_create_private_room',
      body: <String, dynamic>{
        'p_table_name': tableName,
        'p_variant': variant,
        'p_min_stake': minStake,
        'p_max_stake': maxStake,
        'p_max_players': maxPlayers,
        'p_fill_with_ai': fillWithAi,
      },
      isPrivate: true,
    );
  }

  /// Joins an active private room using its 6-character shareable room code.
  Future<OnlineRoomTicket?> joinRoomByCode(String roomCode) async {
    return _callRoomRpc(
      rpcName: 'tp_join_room_by_code',
      body: <String, dynamic>{'p_room_code': roomCode.trim().toUpperCase()},
      isPrivate: true,
    );
  }

  /// Removes this authenticated player's seat row from `tp_room_players`.
  Future<bool> leaveRoomSeat(String roomId) async {
    if (!isConfigured) return false;
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) return false;

    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/tp_room_players?room_id=eq.$roomId&profile_id=eq.$_authUserId',
      );
      final resp = await _http.delete(uri, headers: _headers());
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<OnlineRoomTicket?> _callRoomRpc({
    required String rpcName,
    required Map<String, dynamic> body,
    required bool isPrivate,
  }) async {
    if (!isConfigured) return null;
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) {
      throw const OnlineMatchmakingException(
        'Could not sign in to online club servers.',
      );
    }

    final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/$rpcName');
    final resp = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);
      Map<String, dynamic>? row;
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        row = Map<String, dynamic>.from(decoded.first as Map);
      } else if (decoded is Map) {
        row = Map<String, dynamic>.from(decoded);
      }
      if (row != null) {
        return OnlineRoomTicket.fromJson(row, isPrivate: isPrivate);
      }
      throw const OnlineMatchmakingException('Empty room assignment response.');
    }

    var message = 'Matchmaking request failed (${resp.statusCode}).';
    String? code;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        message = (decoded['message'] as String?) ?? message;
        code = decoded['code'] as String?;
      }
    } catch (_) {}
    throw OnlineMatchmakingException(message, code: code);
  }

  /// Inserts a wallet ledger row into `public.tp_wallet_transactions`.
  Future<bool> insertWalletTransaction(Map<String, dynamic> txRow) async {
    if (!isConfigured) return false;
    await ensureAuthenticated();

    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/tp_wallet_transactions?on_conflict=id',
      );
      final resp = await _http.post(
        uri,
        headers: _headers(preferMerge: true),
        body: jsonEncode(txRow),
      );
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Inserts a completed Teen Patti round into `public.tp_game_history`.
  Future<bool> insertGameHistory(Map<String, dynamic> historyRow) async {
    if (!isConfigured) return false;
    await ensureAuthenticated();

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/tp_game_history');
      final resp = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode(historyRow),
      );
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Updates the authenticated player's `last_seen_at` online presence timestamp.
  Future<bool> touchPresenceRpc() async {
    if (!isConfigured) return false;
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) return false;

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/tp_touch_presence');
      final resp = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode(const <String, dynamic>{}),
      );
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Connects the authenticated user with another player via `tp_add_friend_by_code`.
  Future<Map<String, dynamic>?> addFriendByCodeRpc(String playerCode) async {
    if (!isConfigured) return null;
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) {
      throw const OnlineMatchmakingException(
        'Could not sign in to online club servers.',
      );
    }

    final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/tp_add_friend_by_code');
    final resp = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'p_player_code': playerCode.trim().toUpperCase(),
      }),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        return Map<String, dynamic>.from(decoded.first as Map);
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    }

    var message = 'Could not add friend with code $playerCode.';
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } catch (_) {}
    throw OnlineMatchmakingException(message);
  }

  /// Removes a friendship row pair via `tp_remove_friend`.
  Future<bool> removeFriendRpc(String friendId) async {
    if (!isConfigured) return false;
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) return false;

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/tp_remove_friend');
      final resp = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{'p_friend_id': friendId}),
      );
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the authenticated user's friends directory with live presence via
  /// `tp_get_friends_directory`.
  Future<List<Map<String, dynamic>>> fetchFriendsDirectoryRpc() async {
    if (!isConfigured) return const <Map<String, dynamic>>[];
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) return const <Map<String, dynamic>>[];

    try {
      final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/tp_get_friends_directory');
      final resp = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode(const <String, dynamic>{}),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  /// Sends an in-app table invite notification to a friend via `tp_send_room_invite`.
  Future<Map<String, dynamic>?> sendRoomInviteRpc({
    required String friendId,
    required String roomCode,
    String? roomId,
    String tableName = 'Private Club',
    String variant = 'Classic',
    int minStake = 100,
  }) async {
    return _callWalletRpc('tp_send_room_invite', <String, dynamic>{
      'p_friend_id': friendId,
      'p_room_code': roomCode.trim().toUpperCase(),
      if (roomId != null && roomId.isNotEmpty) 'p_room_id': roomId,
      'p_table_name': tableName,
      'p_variant': variant,
      'p_min_stake': minStake,
    });
  }

  /// Fetches active pending room invitations for the authenticated user via
  /// `tp_get_pending_room_invites`.
  Future<List<Map<String, dynamic>>> fetchPendingRoomInvitesRpc() async {
    if (!isConfigured) return const <Map<String, dynamic>>[];
    final authed = await ensureAuthenticated();
    if (!authed || _authUserId == null) return const <Map<String, dynamic>>[];

    try {
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/rpc/tp_get_pending_room_invites',
      );
      final resp = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode(const <String, dynamic>{}),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  /// Accepts or declines a pending room invite via `tp_respond_room_invite`.
  Future<Map<String, dynamic>?> respondRoomInviteRpc({
    required String inviteId,
    required bool accept,
  }) async {
    return _callWalletRpc('tp_respond_room_invite', <String, dynamic>{
      'p_invite_id': inviteId,
      'p_accept': accept,
    });
  }
}
