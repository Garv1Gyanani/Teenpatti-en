import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:teen_patti_core/teen_patti_core.dart';

class _OnlineBotPersona {
  const _OnlineBotPersona({
    required this.slug,
    required this.displayName,
    required this.playerCode,
    required this.avatarAsset,
    required this.params,
    required this.thinkMeanMs,
    required this.thinkSigma,
    required this.initialChips,
    required this.rating,
    required this.gamesPlayed,
    required this.wins,
    required this.bestStreak,
    required this.daysSinceJoined,
    required this.lastActiveMinutesAgo,
  });

  final String slug;
  final String displayName;
  final String playerCode;
  final String avatarAsset;
  final BotProfileParams params;
  final int thinkMeanMs;
  final double thinkSigma;
  final int initialChips;
  final int rating;
  final int gamesPlayed;
  final int wins;
  final int bestStreak;
  final int daysSinceJoined;
  final int lastActiveMinutesAgo;
}

final List<_OnlineBotPersona> _onlinePersonas = [
  const _OnlineBotPersona(
    slug: 'vikram_s',
    displayName: 'Vikram S',
    playerCode: 'TP614829',
    avatarAsset: 'assets/images/online_avatar_1.png',
    params: BotProfileParams.cautious,
    thinkMeanMs: 2250,
    thinkSigma: 0.34,
    initialChips: 42800,
    rating: 1185,
    gamesPlayed: 214,
    wins: 73,
    bestStreak: 4,
    daysSinceJoined: 94,
    lastActiveMinutesAgo: 185,
  ),
  const _OnlineBotPersona(
    slug: 'priya_m',
    displayName: 'Priya M',
    playerCode: 'TP392710',
    avatarAsset: 'assets/images/online_avatar_2.png',
    params: BotProfileParams.balanced,
    thinkMeanMs: 1850,
    thinkSigma: 0.36,
    initialChips: 29450,
    rating: 1090,
    gamesPlayed: 146,
    wins: 49,
    bestStreak: 3,
    daysSinceJoined: 68,
    lastActiveMinutesAgo: 92,
  ),
  const _OnlineBotPersona(
    slug: 'dev_kapoor',
    displayName: 'Dev Kapoor',
    playerCode: 'TP847512',
    avatarAsset: 'assets/images/online_avatar_3.png',
    params: BotProfileParams.tightAggressive,
    thinkMeanMs: 1620,
    thinkSigma: 0.32,
    initialChips: 53600,
    rating: 1265,
    gamesPlayed: 318,
    wins: 109,
    bestStreak: 5,
    daysSinceJoined: 112,
    lastActiveMinutesAgo: 240,
  ),
  const _OnlineBotPersona(
    slug: 'naina_r',
    displayName: 'Naina R',
    playerCode: 'TP520194',
    avatarAsset: 'assets/images/online_avatar_4.png',
    params: BotProfileParams.blindBluffer,
    thinkMeanMs: 1480,
    thinkSigma: 0.38,
    initialChips: 23100,
    rating: 1035,
    gamesPlayed: 97,
    wins: 32,
    bestStreak: 4,
    daysSinceJoined: 41,
    lastActiveMinutesAgo: 45,
  ),
  const _OnlineBotPersona(
    slug: 'arjun_verma',
    displayName: 'Arjun Verma',
    playerCode: 'TP771308',
    avatarAsset: 'assets/images/online_avatar_5.png',
    params: BotProfileParams.shark,
    thinkMeanMs: 2420,
    thinkSigma: 0.30,
    initialChips: 64200,
    rating: 1310,
    gamesPlayed: 382,
    wins: 134,
    bestStreak: 6,
    daysSinceJoined: 128,
    lastActiveMinutesAgo: 310,
  ),
  const _OnlineBotPersona(
    slug: 'tara_gill',
    displayName: 'Tara Gill',
    playerCode: 'TP198435',
    avatarAsset: 'assets/images/online_avatar_6.png',
    params: BotProfileParams.loosePassive,
    thinkMeanMs: 2100,
    thinkSigma: 0.40,
    initialChips: 18700,
    rating: 965,
    gamesPlayed: 74,
    wins: 23,
    bestStreak: 2,
    daysSinceJoined: 29,
    lastActiveMinutesAgo: 130,
  ),
  const _OnlineBotPersona(
    slug: 'siddharth_k',
    displayName: 'Siddharth K',
    playerCode: 'TP904621',
    avatarAsset: 'assets/images/online_avatar_7.png',
    params: BotProfileParams.opportunist,
    thinkMeanMs: 1750,
    thinkSigma: 0.33,
    initialChips: 36900,
    rating: 1150,
    gamesPlayed: 189,
    wins: 66,
    bestStreak: 4,
    daysSinceJoined: 77,
    lastActiveMinutesAgo: 64,
  ),
  const _OnlineBotPersona(
    slug: 'kavya_nair',
    displayName: 'Kavya Nair',
    playerCode: 'TP263940',
    avatarAsset: 'assets/images/online_avatar_8.png',
    params: BotProfileParams.chaotic,
    thinkMeanMs: 1420,
    thinkSigma: 0.44,
    initialChips: 21500,
    rating: 990,
    gamesPlayed: 112,
    wins: 37,
    bestStreak: 3,
    daysSinceJoined: 53,
    lastActiveMinutesAgo: 28,
  ),
  _OnlineBotPersona(
    slug: 'ishaan_roy',
    displayName: 'Ishaan Roy',
    playerCode: 'TP449017',
    avatarAsset: 'assets/images/online_avatar_9.png',
    params: BotProfileParams.tightAggressive.copyWith(
      archetype: 'tight_aggressive_v2',
      blindPlayRate: 0.50,
      foldThreshold: 0.45,
      raiseAggression: 0.30,
    ),
    thinkMeanMs: 1690,
    thinkSigma: 0.31,
    initialChips: 31400,
    rating: 1125,
    gamesPlayed: 163,
    wins: 54,
    bestStreak: 4,
    daysSinceJoined: 84,
    lastActiveMinutesAgo: 155,
  ),
  _OnlineBotPersona(
    slug: 'zoya_khan',
    displayName: 'Zoya Khan',
    playerCode: 'TP685172',
    avatarAsset: 'assets/images/online_avatar_10.png',
    params: BotProfileParams.balanced.copyWith(
      archetype: 'balanced_v2',
      blindPlayRate: 0.44,
      sideShowAppetite: 0.65,
      bluffRate: 0.16,
    ),
    thinkMeanMs: 1980,
    thinkSigma: 0.35,
    initialChips: 27800,
    rating: 1075,
    gamesPlayed: 128,
    wins: 43,
    bestStreak: 3,
    daysSinceJoined: 61,
    lastActiveMinutesAgo: 75,
  ),
];

Future<void> main() async {
  final rawUrl = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final serviceRoleKey =
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY']?.trim() ?? '';

  if (rawUrl.isEmpty || serviceRoleKey.isEmpty) {
    stderr.writeln(
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variable.',
    );
    exitCode = 2;
    return;
  }

  final baseUrl = rawUrl.endsWith('/')
      ? rawUrl.substring(0, rawUrl.length - 1)
      : rawUrl;
  final client = http.Client();

  try {
    final existingUsersByEmail = await _fetchExistingBotUsers(
      client: client,
      baseUrl: baseUrl,
      serviceRoleKey: serviceRoleKey,
    );

    final now = DateTime.now().toUtc();

    for (final bot in _onlinePersonas) {
      final email = 'bot-${bot.slug}@bots.internal.invalid';
      final userId = existingUsersByEmail[email] ??
          await _createBotAuthUser(
            client: client,
            baseUrl: baseUrl,
            serviceRoleKey: serviceRoleKey,
            email: email,
          );

      final joinedAt =
          now.subtract(Duration(days: bot.daysSinceJoined)).toIso8601String();
      final lastActive = now
          .subtract(Duration(minutes: bot.lastActiveMinutesAgo))
          .toIso8601String();

      await _upsertRow(
        client: client,
        baseUrl: baseUrl,
        serviceRoleKey: serviceRoleKey,
        table: 'tp_profiles',
        onConflict: 'id',
        row: {
          'id': userId,
          'player_code': bot.playerCode,
          'display_name': bot.displayName,
          'avatar_asset': bot.avatarAsset,
          'chips': bot.initialChips,
          'rating': bot.rating,
          'games_played': bot.gamesPlayed,
          'wins': bot.wins,
          'current_win_streak': 0,
          'best_streak': bot.bestStreak,
          'daily_streak': (bot.daysSinceJoined % 7) + 1,
          'best_daily_streak': 7 + (bot.daysSinceJoined % 9),
          'total_rewards_earned': 3200 + (bot.gamesPlayed * 25),
          'created_at': joinedAt,
          'updated_at': lastActive,
        },
      );

      await _upsertRow(
        client: client,
        baseUrl: baseUrl,
        serviceRoleKey: serviceRoleKey,
        table: 'tp_bot_pool',
        onConflict: 'profile_id',
        row: {
          'profile_id': userId,
          'archetype': bot.params.archetype,
          'params': bot.params.toJson(),
          'think_mean_ms': bot.thinkMeanMs,
          'think_sigma': bot.thinkSigma,
          'min_bankroll': 5000,
          'target_bankroll': 25000,
          'last_active_at': lastActive,
          'created_at': joinedAt,
        },
      );

      stdout.writeln(
        'Seeded online bot ${bot.displayName} ($userId) [${bot.params.archetype}]',
      );
    }

    stdout.writeln('Successfully seeded all ${_onlinePersonas.length} online bots.');
  } finally {
    client.close();
  }
}

Future<Map<String, String>> _fetchExistingBotUsers({
  required http.Client client,
  required String baseUrl,
  required String serviceRoleKey,
}) async {
  final result = <String, String>{};
  var page = 1;
  const perPage = 200;

  while (true) {
    final uri = Uri.parse(
      '$baseUrl/auth/v1/admin/users?page=$page&per_page=$perPage',
    );
    final res = await client.get(
      uri,
      headers: _serviceHeaders(serviceRoleKey),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Failed to list auth users: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final users = body['users'] as List<dynamic>? ?? const [];
    for (final raw in users) {
      final user = raw as Map<String, dynamic>;
      final email = (user['email'] as String?)?.toLowerCase();
      final id = user['id'] as String?;
      if (email != null && id != null && email.endsWith('@bots.internal.invalid')) {
        result[email] = id;
      }
    }
    if (users.length < perPage) break;
    page++;
  }

  return result;
}

Future<String> _createBotAuthUser({
  required http.Client client,
  required String baseUrl,
  required String serviceRoleKey,
  required String email,
}) async {
  final uri = Uri.parse('$baseUrl/auth/v1/admin/users');
  final password = 'Bot-${DateTime.now().microsecondsSinceEpoch}-${email.hashCode.abs()}!';
  final res = await client.post(
    uri,
    headers: _serviceHeaders(serviceRoleKey),
    body: jsonEncode({
      'email': email,
      'password': password,
      'email_confirm': true,
    }),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw StateError('Failed to create bot auth user $email: ${res.statusCode} ${res.body}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return body['id'] as String;
}

Future<void> _upsertRow({
  required http.Client client,
  required String baseUrl,
  required String serviceRoleKey,
  required String table,
  required String onConflict,
  required Map<String, dynamic> row,
}) async {
  final uri = Uri.parse('$baseUrl/rest/v1/$table?on_conflict=$onConflict');
  final res = await client.post(
    uri,
    headers: {
      ..._serviceHeaders(serviceRoleKey),
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    },
    body: jsonEncode(row),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw StateError('Failed upserting $table: ${res.statusCode} ${res.body}');
  }
}

Map<String, String> _serviceHeaders(String serviceRoleKey) => {
      'apikey': serviceRoleKey,
      'Authorization': 'Bearer $serviceRoleKey',
      'Content-Type': 'application/json',
    };
