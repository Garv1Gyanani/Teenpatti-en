import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:teen_patti_core/teen_patti_core.dart';

class RoomRecord {
  const RoomRecord({
    required this.id,
    this.roomCode,
    required this.tableName,
    required this.variant,
    required this.minStake,
    required this.maxStake,
    required this.maxPlayers,
    required this.isPrivate,
    required this.fillWithAi,
    this.hostProfileId,
    required this.status,
    required this.createdAt,
  });

  factory RoomRecord.fromJson(Map<String, dynamic> json) {
    return RoomRecord(
      id: json['id'] as String,
      roomCode: json['room_code'] as String?,
      tableName: json['table_name'] as String? ?? 'Teen Patti',
      variant: json['variant'] as String? ?? 'Classic',
      minStake: (json['min_stake'] as num?)?.toInt() ?? 100,
      maxStake: (json['max_stake'] as num?)?.toInt() ?? 3200,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 5,
      isPrivate: json['is_private'] as bool? ?? false,
      fillWithAi: json['fill_with_ai'] as bool? ?? true,
      hostProfileId: json['host_profile_id'] as String?,
      status: json['status'] as String? ?? 'waiting',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  final String id;
  final String? roomCode;
  final String tableName;
  final String variant;
  final int minStake;
  final int maxStake;
  final int maxPlayers;
  final bool isPrivate;
  final bool fillWithAi;
  final String? hostProfileId;
  final String status;
  final DateTime createdAt;
}

class SeatProfile {
  const SeatProfile({
    required this.profileId,
    required this.seatIndex,
    required this.displayName,
    required this.avatarAsset,
    required this.chips,
    required this.rating,
    required this.isBot,
  });

  final String profileId;
  final int seatIndex;
  final String displayName;
  final String avatarAsset;
  final int chips;
  final int rating;
  final bool isBot;
}

class ClaimedBot {
  const ClaimedBot({
    required this.profileId,
    required this.displayName,
    required this.avatarAsset,
    required this.chips,
    required this.rating,
    required this.archetype,
    required this.params,
    required this.thinkMeanMs,
    required this.thinkSigma,
  });

  factory ClaimedBot.fromJson(Map<String, dynamic> json) {
    final rawParams = json['params'];
    final paramsMap = rawParams is Map<String, dynamic>
        ? rawParams
        : rawParams is Map
            ? Map<String, dynamic>.from(rawParams)
            : const <String, dynamic>{};
    return ClaimedBot(
      profileId: json['profile_id'] as String,
      displayName: json['display_name'] as String? ?? 'Player',
      avatarAsset: json['avatar_asset'] as String? ??
          'assets/images/online_avatar_1.png',
      chips: (json['chips'] as num?)?.toInt() ?? 25000,
      rating: (json['rating'] as num?)?.toInt() ?? 1000,
      archetype: json['archetype'] as String? ?? 'balanced',
      params: BotProfileParams.fromJson(paramsMap),
      thinkMeanMs: (json['think_mean_ms'] as num?)?.toInt() ?? 1900,
      thinkSigma: (json['think_sigma'] as num?)?.toDouble() ?? 0.35,
    );
  }

  final String profileId;
  final String displayName;
  final String avatarAsset;
  final int chips;
  final int rating;
  final String archetype;
  final BotProfileParams params;
  final int thinkMeanMs;
  final double thinkSigma;
}

class SettlementSeatDelta {
  const SettlementSeatDelta({
    required this.profileId,
    required this.won,
    required this.bootAmount,
    required this.investedAmount,
    required this.wonAmount,
    required this.potAmount,
    required this.handLabel,
    required this.winReason,
    required this.tableName,
    required this.variant,
    required this.isBot,
  });

  final String profileId;
  final bool won;
  final int bootAmount;
  final int investedAmount;
  final int wonAmount;
  final int potAmount;
  final String handLabel;
  final String winReason;
  final String tableName;
  final String variant;
  final bool isBot;

  /// Net profit/loss relative to stack BEFORE the hand began.
  int get netChips => wonAmount - investedAmount;

  /// DB adjustment at round end (since [bootAmount] was deducted at hand start).
  int get settlementDeltaFromPostBoot => wonAmount - investedAmount + bootAmount;
}

abstract class ServerBackendGateway {
  Future<void> resetAllBotLocks();

  Future<int> refundHeldEscrows();

  Future<void> upsertHeartbeat({
    required String workerId,
    required int activeRooms,
    required DateTime startedAt,
  });

  Future<List<RoomRecord>> fetchActiveRooms();

  Future<List<SeatProfile>> fetchRoomPlayers(String roomId);

  Future<void> updateRoomStatus(String roomId, String status);

  Future<void> insertRoomPlayer({
    required String roomId,
    required String profileId,
    required int seatIndex,
  });

  Future<void> removeRoomPlayer({
    required String roomId,
    required String profileId,
  });

  Future<List<ClaimedBot>> claimBots({
    required String roomId,
    required int count,
    required int minChips,
  });

  Future<void> releaseBot(
    String profileId, {
    int cooldownMinSec = 60,
    int cooldownMaxSec = 300,
  });

  Future<void> holdRoundEscrows({
    required String roomId,
    required int roundNumber,
    required Map<String, int> bootsByProfileId,
    required String tableName,
  });

  Future<void> settleRound({
    required String roomId,
    required int roundNumber,
    required List<SettlementSeatDelta> seats,
    required bool hasHumanParticipant,
  });

  Future<int> topUpLowBankrollBots();
}

class SupabaseServerBackend implements ServerBackendGateway {
  SupabaseServerBackend({
    required String supabaseUrl,
    required this.serviceRoleKey,
    http.Client? httpClient,
  })  : baseUrl = supabaseUrl.endsWith('/')
            ? supabaseUrl.substring(0, supabaseUrl.length - 1)
            : supabaseUrl,
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final String serviceRoleKey;
  final http.Client _http;

  Map<String, String> _headers({String? prefer}) => <String, String>{
        'apikey': serviceRoleKey,
        'Authorization': 'Bearer $serviceRoleKey',
        'Content-Type': 'application/json',
        'Prefer': ?prefer,
      };

  @override
  Future<void> resetAllBotLocks() async {
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tp_bot_pool?active_table_id=not.is.null',
    );
    final res = await _http.patch(
      uri,
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(<String, dynamic>{
        'active_table_id': null,
        'seated_at': null,
        'available_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    _ensureSuccess(res, 'resetAllBotLocks');
  }

  @override
  Future<int> refundHeldEscrows() async {
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tp_hand_escrows?status=eq.held&select=id,room_id,round_number,profile_id,boot_amount',
    );
    final res = await _http.get(uri, headers: _headers());
    _ensureSuccess(res, 'fetchHeldEscrows');
    final rows = (jsonDecode(res.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (rows.isEmpty) return 0;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    var refundedCount = 0;

    for (final escrow in rows) {
      final escrowId = escrow['id'] as String;
      final profileId = escrow['profile_id'] as String;
      final bootAmount = (escrow['boot_amount'] as num).toInt();

      if (bootAmount > 0) {
        final profile = await _fetchProfile(profileId);
        if (profile != null) {
          final currentChips = (profile['chips'] as num?)?.toInt() ?? 0;
          await _patchProfile(profileId, {
            'chips': currentChips + bootAmount,
          });
          await _insertWalletTx(
            id: 'refund_${escrowId}_$profileId',
            profileId: profileId,
            type: 'gameWin',
            title: 'Table Recovery Refund',
            subtitle: 'Boot returned after table restart',
            amount: bootAmount,
          );
        }
      }

      final markUri = Uri.parse(
        '$baseUrl/rest/v1/tp_hand_escrows?id=eq.$escrowId',
      );
      final markRes = await _http.patch(
        markUri,
        headers: _headers(prefer: 'return=minimal'),
        body: jsonEncode(<String, dynamic>{
          'status': 'refunded',
          'settled_at': nowIso,
        }),
      );
      _ensureSuccess(markRes, 'markEscrowRefunded');
      refundedCount++;
    }

    return refundedCount;
  }

  @override
  Future<void> upsertHeartbeat({
    required String workerId,
    required int activeRooms,
    required DateTime startedAt,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tp_worker_heartbeat?on_conflict=worker_id',
    );
    final res = await _http.post(
      uri,
      headers: _headers(prefer: 'resolution=merge-duplicates,return=minimal'),
      body: jsonEncode(<String, dynamic>{
        'worker_id': workerId,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'active_rooms': activeRooms,
        'started_at': startedAt.toUtc().toIso8601String(),
      }),
    );
    _ensureSuccess(res, 'upsertHeartbeat');
  }

  @override
  Future<List<RoomRecord>> fetchActiveRooms() async {
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tp_rooms?status=in.(waiting,playing)&order=created_at.asc',
    );
    final res = await _http.get(uri, headers: _headers());
    _ensureSuccess(res, 'fetchActiveRooms');
    final list = (jsonDecode(res.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list.map(RoomRecord.fromJson).toList();
  }

  @override
  Future<List<SeatProfile>> fetchRoomPlayers(String roomId) async {
    final seatsUri = Uri.parse(
      '$baseUrl/rest/v1/tp_room_players?room_id=eq.$roomId&order=seat_index.asc&select=profile_id,seat_index',
    );
    final seatsRes = await _http.get(seatsUri, headers: _headers());
    _ensureSuccess(seatsRes, 'fetchRoomPlayers.seats');
    final seatRows = (jsonDecode(seatsRes.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (seatRows.isEmpty) return const [];

    final ids = seatRows.map((r) => r['profile_id'] as String).toList();
    final idFilter = ids.join(',');

    final profilesUri = Uri.parse(
      '$baseUrl/rest/v1/tp_profiles?id=in.($idFilter)&select=id,display_name,avatar_asset,chips,rating',
    );
    final botsUri = Uri.parse(
      '$baseUrl/rest/v1/tp_bot_pool?profile_id=in.($idFilter)&select=profile_id',
    );

    final results = await Future.wait([
      _http.get(profilesUri, headers: _headers()),
      _http.get(botsUri, headers: _headers()),
    ]);
    _ensureSuccess(results[0], 'fetchRoomPlayers.profiles');
    _ensureSuccess(results[1], 'fetchRoomPlayers.bots');

    final profilesById = <String, Map<String, dynamic>>{
      for (final raw
          in (jsonDecode(results[0].body) as List<dynamic>)
              .cast<Map<String, dynamic>>())
        raw['id'] as String: raw,
    };
    final botIds = <String>{
      for (final raw
          in (jsonDecode(results[1].body) as List<dynamic>)
              .cast<Map<String, dynamic>>())
        raw['profile_id'] as String,
    };

    return seatRows.map((seat) {
      final profileId = seat['profile_id'] as String;
      final profile = profilesById[profileId] ?? const <String, dynamic>{};
      return SeatProfile(
        profileId: profileId,
        seatIndex: (seat['seat_index'] as num).toInt(),
        displayName: profile['display_name'] as String? ?? 'Player',
        avatarAsset: profile['avatar_asset'] as String? ??
            'assets/images/online_avatar_1.png',
        chips: (profile['chips'] as num?)?.toInt() ?? 0,
        rating: (profile['rating'] as num?)?.toInt() ?? 1000,
        isBot: botIds.contains(profileId),
      );
    }).toList();
  }

  @override
  Future<void> updateRoomStatus(String roomId, String status) async {
    final uri = Uri.parse('$baseUrl/rest/v1/tp_rooms?id=eq.$roomId');
    final res = await _http.patch(
      uri,
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(<String, dynamic>{'status': status}),
    );
    _ensureSuccess(res, 'updateRoomStatus');
  }

  @override
  Future<void> insertRoomPlayer({
    required String roomId,
    required String profileId,
    required int seatIndex,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tp_room_players?on_conflict=room_id,profile_id',
    );
    final res = await _http.post(
      uri,
      headers: _headers(prefer: 'resolution=merge-duplicates,return=minimal'),
      body: jsonEncode(<String, dynamic>{
        'room_id': roomId,
        'profile_id': profileId,
        'seat_index': seatIndex,
      }),
    );
    _ensureSuccess(res, 'insertRoomPlayer');
  }

  @override
  Future<void> removeRoomPlayer({
    required String roomId,
    required String profileId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tp_room_players?room_id=eq.$roomId&profile_id=eq.$profileId',
    );
    final res = await _http.delete(uri, headers: _headers());
    _ensureSuccess(res, 'removeRoomPlayer');
  }

  @override
  Future<List<ClaimedBot>> claimBots({
    required String roomId,
    required int count,
    required int minChips,
  }) async {
    if (count <= 0) return const [];
    final uri = Uri.parse('$baseUrl/rest/v1/rpc/tp_claim_bots');
    final res = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'p_table_id': roomId,
        'p_count': count,
        'p_min_chips': minChips,
      }),
    );
    _ensureSuccess(res, 'claimBots');
    final list = (jsonDecode(res.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list.map(ClaimedBot.fromJson).toList();
  }

  @override
  Future<void> releaseBot(
    String profileId, {
    int cooldownMinSec = 60,
    int cooldownMaxSec = 300,
  }) async {
    final uri = Uri.parse('$baseUrl/rest/v1/rpc/tp_release_bot');
    final res = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'p_profile_id': profileId,
        'p_cooldown_min_sec': cooldownMinSec,
        'p_cooldown_max_sec': cooldownMaxSec,
      }),
    );
    _ensureSuccess(res, 'releaseBot');
  }

  @override
  Future<void> holdRoundEscrows({
    required String roomId,
    required int roundNumber,
    required Map<String, int> bootsByProfileId,
    required String tableName,
  }) async {
    if (bootsByProfileId.isEmpty) return;

    final escrowRows = <Map<String, dynamic>>[];
    for (final entry in bootsByProfileId.entries) {
      final profile = await _fetchProfile(entry.key);
      if (profile != null) {
        final currentChips = (profile['chips'] as num?)?.toInt() ?? 0;
        final nextChips = (currentChips - entry.value).clamp(0, 1 << 60);
        await _patchProfile(entry.key, {'chips': nextChips});
        await _insertWalletTx(
          id: 'boot_${roomId}_r${roundNumber}_${entry.key}',
          profileId: entry.key,
          type: 'gameEntry',
          title: '$tableName Boot',
          subtitle: 'Round #$roundNumber ante',
          amount: -entry.value,
        );
      }
      escrowRows.add(<String, dynamic>{
        'room_id': roomId,
        'round_number': roundNumber,
        'profile_id': entry.key,
        'boot_amount': entry.value,
        'status': 'held',
      });
    }

    final uri = Uri.parse('$baseUrl/rest/v1/tp_hand_escrows');
    final res = await _http.post(
      uri,
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(escrowRows),
    );
    _ensureSuccess(res, 'holdRoundEscrows');
  }

  @override
  Future<void> settleRound({
    required String roomId,
    required int roundNumber,
    required List<SettlementSeatDelta> seats,
    required bool hasHumanParticipant,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final seat in seats) {
      final profile = await _fetchProfile(seat.profileId);
      if (profile != null) {
        final currentChips = (profile['chips'] as num?)?.toInt() ?? 0;
        final gamesPlayed = (profile['games_played'] as num?)?.toInt() ?? 0;
        final wins = (profile['wins'] as num?)?.toInt() ?? 0;
        final streak = (profile['current_win_streak'] as num?)?.toInt() ?? 0;
        final bestStreak = (profile['best_streak'] as num?)?.toInt() ?? 0;
        final rating = (profile['rating'] as num?)?.toInt() ?? 1000;

        final nextChips =
            (currentChips + seat.settlementDeltaFromPostBoot).clamp(0, 1 << 60);
        final nextStreak = seat.won ? streak + 1 : 0;
        final nextBest = nextStreak > bestStreak ? nextStreak : bestStreak;
        final nextRating = (rating + (seat.won ? 12 : -6)).clamp(400, 9999);

        await _patchProfile(seat.profileId, {
          'chips': nextChips,
          'games_played': gamesPlayed + 1,
          'wins': wins + (seat.won ? 1 : 0),
          'current_win_streak': nextStreak,
          'best_streak': nextBest,
          'rating': nextRating,
        });
      }

      final extraWager = seat.investedAmount - seat.bootAmount;
      if (extraWager > 0) {
        await _insertWalletTx(
          id: 'bet_${roomId}_r${roundNumber}_${seat.profileId}',
          profileId: seat.profileId,
          type: 'gameEntry',
          title: '${seat.tableName} Stake',
          subtitle: 'Round #$roundNumber bets',
          amount: -extraWager,
        );
      }

      if (seat.won && seat.wonAmount > 0) {
        await _insertWalletTx(
          id: 'win_${roomId}_r${roundNumber}_${seat.profileId}',
          profileId: seat.profileId,
          type: 'gameWin',
          title: '${seat.tableName} Pot Won',
          subtitle: '${seat.handLabel} (${seat.winReason})',
          amount: seat.wonAmount,
        );
      }

      if (!seat.isBot) {
        await _insertGameHistory({
          'profile_id': seat.profileId,
          'table_name': seat.tableName,
          'variant': seat.variant,
          'boot_amount': seat.bootAmount,
          'pot_amount': seat.potAmount,
          'net_chips': seat.netChips,
          'won': seat.won,
          'hand_label': seat.handLabel,
          'win_reason': seat.winReason,
        });
      } else {
        await _recordBotRoundMetrics(
          profileId: seat.profileId,
          netChips: seat.netChips,
          hasHumanParticipant: hasHumanParticipant,
          nowIso: nowIso,
        );
      }
    }

    final escrowUri = Uri.parse(
      '$baseUrl/rest/v1/tp_hand_escrows?room_id=eq.$roomId&round_number=eq.$roundNumber&status=eq.held',
    );
    final escrowRes = await _http.patch(
      escrowUri,
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(<String, dynamic>{
        'status': 'settled',
        'settled_at': nowIso,
      }),
    );
    _ensureSuccess(escrowRes, 'markRoundEscrowsSettled');
  }

  @override
  Future<int> topUpLowBankrollBots() async {
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tp_bot_pool?select=profile_id,min_bankroll,target_bankroll',
    );
    final res = await _http.get(uri, headers: _headers());
    _ensureSuccess(res, 'topUpLowBankrollBots.pool');
    final poolRows = (jsonDecode(res.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (poolRows.isEmpty) return 0;

    final ids = poolRows.map((r) => r['profile_id'] as String).join(',');
    final profUri = Uri.parse(
      '$baseUrl/rest/v1/tp_profiles?id=in.($ids)&select=id,chips',
    );
    final profRes = await _http.get(profUri, headers: _headers());
    _ensureSuccess(profRes, 'topUpLowBankrollBots.profiles');
    final chipsById = <String, int>{
      for (final row
          in (jsonDecode(profRes.body) as List<dynamic>)
              .cast<Map<String, dynamic>>())
        row['id'] as String: (row['chips'] as num?)?.toInt() ?? 0,
    };

    var toppedUp = 0;
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final bot in poolRows) {
      final id = bot['profile_id'] as String;
      final minBankroll = (bot['min_bankroll'] as num?)?.toInt() ?? 5000;
      final targetBankroll =
          (bot['target_bankroll'] as num?)?.toInt() ?? 25000;
      final current = chipsById[id] ?? 0;
      if (current < minBankroll && targetBankroll > current) {
        final delta = targetBankroll - current;
        await _patchProfile(id, {'chips': targetBankroll});
        await _insertWalletTx(
          id: 'refill_${stamp}_$id',
          profileId: id,
          type: 'dailyReward',
          title: 'Club Bankroll Refill',
          subtitle: 'Periodic stack replenishment',
          amount: delta,
        );
        toppedUp++;
      }
    }
    return toppedUp;
  }

  Future<Map<String, dynamic>?> _fetchProfile(String profileId) async {
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tp_profiles?id=eq.$profileId&select=id,chips,rating,games_played,wins,current_win_streak,best_streak',
    );
    final res = await _http.get(uri, headers: _headers());
    _ensureSuccess(res, 'fetchProfile');
    final list = (jsonDecode(res.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list.isEmpty ? null : list.first;
  }

  Future<void> _patchProfile(String profileId, Map<String, dynamic> fields) async {
    final uri = Uri.parse('$baseUrl/rest/v1/tp_profiles?id=eq.$profileId');
    final res = await _http.patch(
      uri,
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(fields),
    );
    _ensureSuccess(res, 'patchProfile');
  }

  Future<void> _insertWalletTx({
    required String id,
    required String profileId,
    required String type,
    required String title,
    required String subtitle,
    required int amount,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/rest/v1/tp_wallet_transactions?on_conflict=id',
    );
    final res = await _http.post(
      uri,
      headers: _headers(prefer: 'resolution=ignore-duplicates,return=minimal'),
      body: jsonEncode(<String, dynamic>{
        'id': id,
        'profile_id': profileId,
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'amount': amount,
      }),
    );
    _ensureSuccess(res, 'insertWalletTx');
  }

  Future<void> _insertGameHistory(Map<String, dynamic> row) async {
    final uri = Uri.parse('$baseUrl/rest/v1/tp_game_history');
    final res = await _http.post(
      uri,
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(row),
    );
    _ensureSuccess(res, 'insertGameHistory');
  }

  Future<void> _recordBotRoundMetrics({
    required String profileId,
    required int netChips,
    required bool hasHumanParticipant,
    required String nowIso,
  }) async {
    final getUri = Uri.parse(
      '$baseUrl/rest/v1/tp_bot_pool?profile_id=eq.$profileId&select=human_pots_played,human_net_chips',
    );
    final getRes = await _http.get(getUri, headers: _headers());
    _ensureSuccess(getRes, 'fetchBotMetrics');
    final list = (jsonDecode(getRes.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (list.isEmpty) return;

    final currentPots = (list.first['human_pots_played'] as num?)?.toInt() ?? 0;
    final currentNet = (list.first['human_net_chips'] as num?)?.toInt() ?? 0;

    final patchUri = Uri.parse(
      '$baseUrl/rest/v1/tp_bot_pool?profile_id=eq.$profileId',
    );
    final patchRes = await _http.patch(
      patchUri,
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(<String, dynamic>{
        'last_active_at': nowIso,
        if (hasHumanParticipant) 'human_pots_played': currentPots + 1,
        if (hasHumanParticipant) 'human_net_chips': currentNet + netChips,
      }),
    );
    _ensureSuccess(patchRes, 'patchBotMetrics');
  }

  void _ensureSuccess(http.Response res, String op) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Supabase $op failed (${res.statusCode}): ${res.body}');
    }
  }
}
