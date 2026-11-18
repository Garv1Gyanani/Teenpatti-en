import 'dart:async';
import 'dart:math';

import 'package:teen_patti_core/teen_patti_core.dart';

import 'humanized_bot_runner.dart';
import 'room_transport.dart';
import 'server_backend.dart';

abstract class ScheduledTask {
  void cancel();
}

typedef TaskScheduler = ScheduledTask Function(
  Duration delay,
  void Function() callback,
);

class _DartTimerTask implements ScheduledTask {
  _DartTimerTask(Duration delay, void Function() callback)
      : _timer = Timer(delay, callback);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

ScheduledTask defaultTaskScheduler(
  Duration delay,
  void Function() callback,
) =>
    _DartTimerTask(delay, callback);

class _RoomSeatEntry {
  _RoomSeatEntry({
    required this.profile,
    this.claimedBot,
  });

  SeatProfile profile;
  ClaimedBot? claimedBot;
  bool leaveAfterHand = false;

  bool get isBot => profile.isBot || claimedBot != null;
}

/// Authoritative coordinator for a single live Teen Patti room.
///
/// Holds all deck and hole-card state in RAM, drives wake-on-demand staggered
/// bot matchmaking, swaps bots out gracefully when real humans arrive, and
/// emits sanitized [SeatObservation] states + per-seat private hole cards over
/// [RoomTransport].
class RoomActor {
  RoomActor({
    required RoomRecord room,
    required this.backend,
    required this.transport,
    required this.botRunner,
    TeenPattiEngine? engine,
    TaskScheduler? scheduleTask,
    DateTime Function()? nowUtc,
    Random? random,
    this.turnTimeout = const Duration(seconds: 25),
    this.disconnectGrace = const Duration(seconds: 25),
    this.roundBreakDuration = const Duration(seconds: 4),
    this.chatCooldown = const Duration(milliseconds: 1200),
    this.botChatReplyProbability = 0.45,
    this.requireSeatTokens = true,
  })  : _room = room,
        _schedule = scheduleTask ?? defaultTaskScheduler,
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
        _rng = random ?? Random.secure() {
    _engine = engine ??
        TeenPattiEngine(
          random: _rng,
          turnTimeout: turnTimeout,
          nowUtc: _nowUtc,
        );
  }

  static const List<String> _botChatPool = <String>[
    'Good luck! 🍀',
    'Well played! 👏',
    'Let\'s raise it! 🔥',
    'Nice hand! 😎',
    'See you at Showdown!',
    '👏',
    '🔥',
    '😎',
  ];

  final ServerBackendGateway backend;
  final RoomTransport transport;
  final HumanizedBotRunner botRunner;
  final TaskScheduler _schedule;
  final DateTime Function() _nowUtc;
  final Random _rng;
  final Duration turnTimeout;
  final Duration disconnectGrace;
  final Duration roundBreakDuration;
  final Duration chatCooldown;
  final double botChatReplyProbability;
  final bool requireSeatTokens;

  late final TeenPattiEngine _engine;
  RoomRecord _room;
  RoomRecord get room => _room;

  final Map<String, _RoomSeatEntry> _seatsById = {};
  final Map<String, String> _seatTokensByUser = {};
  final Map<String, DateTime> _lastSeenHumanUtc = {};
  final Map<String, DateTime> _lastChatAtByUser = {};
  final Set<String> _onlinePresenceIds = {};
  final Map<String, ScheduledTask> _humanGraceTimers = {};

  AuthoritativeTableState? _tableState;
  AuthoritativeTableState? get tableState => _tableState;

  int _roundCounter = 0;
  int _dealerIndex = 0;
  int _chatSeq = 0;
  bool _disposed = false;
  bool _startingHand = false;
  bool _settlingHand = false;
  String _roomStatus = 'waiting';

  ScheduledTask? _botJoinTimer;
  ScheduledTask? _turnTimeoutTimer;
  ScheduledTask? _botActTimer;
  ScheduledTask? _nextRoundTimer;
  ScheduledTask? _sideShowTimer;
  ScheduledTask? _botChatTimer;

  StreamSubscription<RoomActionMessage>? _actionSub;
  StreamSubscription<Set<String>>? _presenceSub;

  Future<void> start() async {
    await transport.connect();
    if (_disposed) return;

    _actionSub = transport.actions.listen(_onClientAction);
    _presenceSub = transport.onlineUserIds.listen(_onPresenceChanged);

    await syncWithDatabase();
  }

  /// Reconciles live DB room metadata and seated players with in-memory state.
  Future<void> syncWithDatabase({RoomRecord? latestRoom}) async {
    if (_disposed) return;
    if (latestRoom != null) {
      _room = latestRoom;
    }
    if (_room.status == 'closed') {
      await closeRoom();
      return;
    }

    final dbSeats = await backend.fetchRoomPlayers(_room.id);
    if (_disposed) return;

    final previousHumanIds = _seatsById.values
        .where((e) => !e.isBot)
        .map((e) => e.profile.profileId)
        .toSet();
    final dbIds = dbSeats.map((s) => s.profileId).toSet();

    // Update or add seats present in DB.
    for (final dbSeat in dbSeats) {
      final existing = _seatsById[dbSeat.profileId];
      if (existing != null) {
        existing.profile = dbSeat;
      } else {
        _seatsById[dbSeat.profileId] = _RoomSeatEntry(profile: dbSeat);
        if (!dbSeat.isBot) {
          _lastSeenHumanUtc[dbSeat.profileId] = _nowUtc();
          _ensureSeatTokenAndNotify(dbSeat.profileId);
          _armDisconnectGraceIfOffline(dbSeat.profileId);
        }
      }
    }

    // Handle seats removed externally from DB (e.g. direct DB leave).
    for (final removedId
        in _seatsById.keys.where((id) => !dbIds.contains(id)).toList()) {
      await _handlePlayerRemoved(removedId);
    }

    final currentHumanIds = _seatsById.values
        .where((e) => !e.isBot)
        .map((e) => e.profile.profileId)
        .toSet();
    final newlyArrivedHumans = currentHumanIds.difference(previousHumanIds);

    if (newlyArrivedHumans.isNotEmpty) {
      for (final _ in newlyArrivedHumans) {
        _markOldestBotToLeaveAfterHandIfNeeded();
      }
    }

    if (currentHumanIds.isEmpty && _seatsById.isNotEmpty) {
      await closeRoom();
      return;
    }

    _evaluateWaitingMatchmaking();
    await _broadcastWaitingSnapshotIfIdle();
  }

  int get humanCount => _seatsById.values.where((s) => !s.isBot).length;
  int get botCount => _seatsById.values.where((s) => s.isBot).length;
  int get totalSeatCount => _seatsById.length;
  bool get isClosed => _roomStatus == 'closed' || _disposed;

  void _ensureSeatTokenAndNotify(String profileId) {
    final token = _seatTokensByUser.putIfAbsent(profileId, _generateToken);
    final activeHand = _tableState;
    final seat = activeHand?.findPlayerById(profileId);
    final cards = (seat != null && seat.hasSeenCards)
        ? seat.cards
        : const <PlayingCard>[];
    unawaited(
      transport.sendPrivateSeatCards(
        profileId: profileId,
        cards: cards,
        roundNumber: activeHand?.roundNumber ?? _roundCounter,
      ),
    );
    // Notice seatToken is also carried cleanly when cards payload exists; wait:
    // if SeatToken transport is separate or needed by client, send it on seat channel too.
    assert(token.isNotEmpty);
  }

  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(24, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  void _markOldestBotToLeaveAfterHandIfNeeded() {
    final bots = _seatsById.values
        .where((s) => s.isBot && !s.leaveAfterHand)
        .toList()
      ..sort((a, b) => a.profile.seatIndex.compareTo(b.profile.seatIndex));

    if (bots.isEmpty) return;

    // Keep bots <= 50% of total seats, and vacate one bot per arriving human.
    final maxAllowedBots = _room.isPrivate && !_room.fillWithAi
        ? 0
        : max(0, min(_room.maxPlayers ~/ 2, max(0, 3 - humanCount)));
    final activeBotsRemaining =
        _seatsById.values.where((s) => s.isBot && !s.leaveAfterHand).length;

    if (activeBotsRemaining > maxAllowedBots || humanCount >= 2) {
      bots.first.leaveAfterHand = true;
    }
  }

  void _evaluateWaitingMatchmaking() {
    if (_disposed || _roomStatus == 'closed') return;
    final handInProgress = _tableState != null && !_tableState!.isRoundOver;
    if (handInProgress || _startingHand || _nextRoundTimer != null) return;

    if (humanCount == 0) {
      _cancelBotJoinTimer();
      return;
    }

    // Friends-only private rooms with fillWithAi=false never spawn bots.
    final aiAllowed = !_room.isPrivate || _room.fillWithAi;

    // Cancel pending bot timer if we already hit target seating.
    if (humanCount >= 3 || (!aiAllowed && humanCount >= 2)) {
      _cancelBotJoinTimer();
      unawaited(_tryStartNextHand());
      return;
    }

    // Start immediately once >=3 players are seated (public or AI-filled), or >=2
    // real humans in a non-AI private room.
    if (totalSeatCount >= 3 || (!aiAllowed && humanCount >= 2)) {
      _cancelBotJoinTimer();
      unawaited(_tryStartNextHand());
      return;
    }

    if (!aiAllowed) {
      _cancelBotJoinTimer();
      return;
    }

    final botCap = min(2, max(1, _room.maxPlayers ~/ 2));
    if (botCount >= botCap) {
      _cancelBotJoinTimer();
      return;
    }

    // Schedule staggered wake-on-demand bot join if not already pending.
    if (_botJoinTimer == null) {
      final delay = botCount == 0
          ? Duration(milliseconds: 8000 + _rng.nextInt(4001)) // 8-12s
          : Duration(milliseconds: 4000 + _rng.nextInt(4001)); // +4-8s
      _botJoinTimer = _schedule(delay, () {
        _botJoinTimer = null;
        unawaited(_onStaggeredBotJoinTimer());
      });
    }
  }

  void _cancelBotJoinTimer() {
    _botJoinTimer?.cancel();
    _botJoinTimer = null;
  }

  Future<void> _onStaggeredBotJoinTimer() async {
    if (_disposed || _roomStatus == 'closed') return;
    if (_tableState != null && !_tableState!.isRoundOver) return;
    if (humanCount == 0 || (!_room.fillWithAi && _room.isPrivate)) return;
    if (humanCount >= 3 || totalSeatCount >= 3) {
      await _tryStartNextHand();
      return;
    }

    final botCap = min(2, max(1, _room.maxPlayers ~/ 2));
    if (botCount >= botCap) return;

    final freeSeat = _firstFreeSeatIndex();
    if (freeSeat == null) return;

    final claimed = await backend.claimBots(
      roomId: _room.id,
      count: 1,
      minChips: _room.minStake * 10,
    );
    if (_disposed || claimed.isEmpty) return;

    final bot = claimed.first;
    // If real humans filled the table while claimBots was in flight, release it cleanly.
    if (humanCount == 0 ||
        humanCount >= 3 ||
        totalSeatCount >= _room.maxPlayers ||
        (_room.isPrivate && !_room.fillWithAi)) {
      await backend.releaseBot(bot.profileId);
      return;
    }

    botRunner.registerBot(bot);
    await backend.insertRoomPlayer(
      roomId: _room.id,
      profileId: bot.profileId,
      seatIndex: freeSeat,
    );

    _seatsById[bot.profileId] = _RoomSeatEntry(
      profile: SeatProfile(
        profileId: bot.profileId,
        seatIndex: freeSeat,
        displayName: bot.displayName,
        avatarAsset: bot.avatarAsset,
        chips: bot.chips,
        rating: bot.rating,
        isBot: true,
      ),
      claimedBot: bot,
    );

    await _broadcastWaitingSnapshotIfIdle();

    if (totalSeatCount >= 3 || (humanCount >= 2 && totalSeatCount >= 2)) {
      await _tryStartNextHand();
    } else {
      _evaluateWaitingMatchmaking();
    }
  }

  int? _firstFreeSeatIndex() {
    final used = {for (final s in _seatsById.values) s.profile.seatIndex};
    for (var i = 0; i < _room.maxPlayers; i++) {
      if (!used.contains(i)) return i;
    }
    return null;
  }

  Future<void> _tryStartNextHand() async {
    if (_disposed || _startingHand || _settlingHand) return;
    if (_tableState != null && !_tableState!.isRoundOver) return;
    if (humanCount == 0) return;

    final minPlayersToDeal = (!_room.isPrivate || _room.fillWithAi) ? 3 : 2;
    if (totalSeatCount < minPlayersToDeal) return;

    _startingHand = true;
    try {
      await _vacatePendingExitBots();
      if (humanCount == 0) {
        await closeRoom();
        return;
      }

      // If vacating bots dropped us below threshold, re-evaluate waiting/refill.
      if (totalSeatCount < minPlayersToDeal) {
        _roomStatus = 'waiting';
        await backend.updateRoomStatus(_room.id, 'waiting');
        await _broadcastWaitingSnapshotIfIdle();
        _evaluateWaitingMatchmaking();
        return;
      }

      // Refresh authoritative balances from DB before dealing.
      final freshSeats = await backend.fetchRoomPlayers(_room.id);
      if (_disposed) return;

      final participants = <TablePlayer>[];
      final boots = <String, int>{};

      final sortedSeats = freshSeats.toList()
        ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));

      for (final s in sortedSeats) {
        if (!_seatsById.containsKey(s.profileId)) continue;
        if (s.chips < _room.minStake) {
          // Broke seat leaves cleanly before round start.
          await _handlePlayerRemoved(s.profileId);
          await backend.removeRoomPlayer(
            roomId: _room.id,
            profileId: s.profileId,
          );
          continue;
        }
        _seatsById[s.profileId]!.profile = s;
        participants.add(
          TablePlayer(
            id: s.profileId,
            name: s.displayName,
            chips: s.chips,
            avatarAsset: s.avatarAsset,
            participantKind: _seatsById[s.profileId]!.isBot
                ? ParticipantKind.onlineAgent
                : ParticipantKind.human,
            rating: s.rating,
          ),
        );
        boots[s.profileId] = _room.minStake;
      }

      if (humanCount == 0 || participants.length < minPlayersToDeal) {
        _roomStatus = 'waiting';
        await backend.updateRoomStatus(_room.id, 'waiting');
        await _broadcastWaitingSnapshotIfIdle();
        _evaluateWaitingMatchmaking();
        return;
      }

      _roundCounter++;
      final dealt = _engine.startNewRound(
        tableName: _room.tableName,
        minStake: _room.minStake,
        maxStake: _room.maxStake,
        players: participants,
        roundNumber: _roundCounter,
        dealerIndex: _dealerIndex % participants.length,
        variant: TeenPattiVariant.fromLabel(_room.variant),
      );
      _dealerIndex++;

      await backend.holdRoundEscrows(
        roomId: _room.id,
        roundNumber: _roundCounter,
        bootsByProfileId: boots,
        tableName: _room.tableName,
      );

      if (_roomStatus != 'playing') {
        _roomStatus = 'playing';
        await backend.updateRoomStatus(_room.id, 'playing');
      }

      _tableState = dealt;
      // Clear any previous round's private cards on human seats until they See.
      for (final seat in _seatsById.values) {
        if (!seat.isBot) {
          await transport.sendPrivateSeatCards(
            profileId: seat.profile.profileId,
            cards: const [],
            roundNumber: _roundCounter,
          );
        }
      }

      await _broadcastTableState();
      _scheduleActiveActorTimers();
    } finally {
      _startingHand = false;
    }
  }

  Future<void> _vacatePendingExitBots() async {
    final toRemove = _seatsById.values
        .where((s) => s.isBot && s.leaveAfterHand)
        .map((s) => s.profile.profileId)
        .toList();

    for (final botId in toRemove) {
      await _releaseAndRemoveBot(botId);
    }

    // Enforce <=50% bot cap on multi-human tables between hands.
    if (humanCount >= 2 && botCount > (_room.maxPlayers ~/ 2)) {
      final activeBots = _seatsById.values
          .where((s) => s.isBot)
          .toList()
        ..sort((a, b) => a.profile.seatIndex.compareTo(b.profile.seatIndex));
      while (botCount > (_room.maxPlayers ~/ 2) && activeBots.isNotEmpty) {
        final target = activeBots.removeAt(0);
        await _releaseAndRemoveBot(target.profile.profileId);
      }
    }
  }

  Future<void> _releaseAndRemoveBot(String botId) async {
    _seatsById.remove(botId);
    botRunner.unregisterBot(botId);
    await backend.removeRoomPlayer(roomId: _room.id, profileId: botId);
    await backend.releaseBot(botId);
  }

  Future<void> _onClientAction(RoomActionMessage msg) async {
    if (_disposed || _roomStatus == 'closed') return;
    final seat = _seatsById[msg.playerId];
    if (seat == null || seat.isBot) return;

    if (msg.action == 'leave') {
      await _handleExplicitLeave(msg.playerId);
      return;
    }

    if (msg.action == 'chat' || msg.action == 'reaction') {
      await _handleClientChatOrReaction(seat, msg);
      return;
    }

    final state = _tableState;
    if (state == null || state.isRoundOver) return;

    var nextState = state;
    final pending = nextState.pendingSideShow;

    try {
      if (msg.action == 'sideShowResponse') {
        if (pending == null || pending.targetId != msg.playerId) return;
        nextState = _engine.resolveSideShow(
          nextState,
          accepted: msg.accepted ?? false,
        );
      } else {
        if (msg.action == 'seeCards' || msg.seeFirst) {
          final beforeSeen =
              nextState.findPlayerById(msg.playerId)?.hasSeenCards ?? true;
          nextState = _engine.seeCards(nextState, playerId: msg.playerId);
          final seatPlayer = nextState.findPlayerById(msg.playerId);
          if (!beforeSeen && seatPlayer != null && seatPlayer.hasSeenCards) {
            await transport.sendPrivateSeatCards(
              profileId: msg.playerId,
              cards: seatPlayer.cards,
              roundNumber: nextState.roundNumber,
            );
          }
          if (msg.action == 'seeCards') {
            _tableState = nextState;
            await _broadcastTableState();
            return;
          }
        }

        final parsedAction = _parsePlayerAction(msg.action);
        if (parsedAction == null) return;
        final active = nextState.activeTurnPlayer;
        if (active == null || active.id != msg.playerId) return;

        nextState = _engine.applyAction(
          nextState,
          playerId: msg.playerId,
          action: parsedAction,
          raiseStake: msg.raiseStake,
        );
      }
    } catch (_) {
      return;
    }

    await _commitStateTransition(nextState);
  }

  PlayerTableAction? _parsePlayerAction(String action) => switch (action) {
        'blind' => PlayerTableAction.blind,
        'chaal' => PlayerTableAction.chaal,
        'pack' => PlayerTableAction.pack,
        'sideShow' => PlayerTableAction.sideShow,
        'show' => PlayerTableAction.show,
        _ => null,
      };

  Future<void> _handleClientChatOrReaction(
    _RoomSeatEntry seat,
    RoomActionMessage msg,
  ) async {
    final rawText = (msg.text ?? '').trim();
    if (rawText.isEmpty) return;

    final now = _nowUtc();
    final lastAt = _lastChatAtByUser[msg.playerId];
    if (lastAt != null && now.difference(lastAt) < chatCooldown) {
      return;
    }
    _lastChatAtByUser[msg.playerId] = now;

    final sanitizedText =
        rawText.length > 80 ? rawText.substring(0, 80) : rawText;
    final isReaction = msg.action == 'reaction' || msg.isQuickReaction;
    _chatSeq++;

    await transport.sendPublicChat(
      RoomChatBroadcast(
        id: 'chat_${_room.id}_$_chatSeq',
        senderId: seat.profile.profileId,
        senderName: seat.profile.displayName,
        senderAvatar: seat.profile.avatarAsset,
        text: sanitizedText,
        isQuickReaction: isReaction,
        timestampUtc: now,
      ),
    );

    _maybeScheduleBotChatReply();
  }

  void _maybeScheduleBotChatReply() {
    if (_disposed || _roomStatus == 'closed') return;
    if (botChatReplyProbability <= 0 ||
        _rng.nextDouble() > botChatReplyProbability) {
      return;
    }

    final activeBots = _seatsById.values.where((entry) {
      if (!entry.isBot) return false;
      final p = _tableState?.findPlayerById(entry.profile.profileId);
      return p == null || !p.hasPacked;
    }).toList(growable: false);

    if (activeBots.isEmpty) return;

    _botChatTimer?.cancel();
    final delay = Duration(milliseconds: 900 + _rng.nextInt(1200));
    _botChatTimer = _schedule(delay, () {
      _botChatTimer = null;
      if (_disposed || _roomStatus == 'closed') return;
      final currentBots = _seatsById.values.where((e) => e.isBot).toList();
      if (currentBots.isEmpty) return;
      final bot = currentBots[_rng.nextInt(currentBots.length)];
      final reply = _botChatPool[_rng.nextInt(_botChatPool.length)];
      final isEmojiOnly = reply.runes.length <= 2;
      _chatSeq++;
      unawaited(
        transport.sendPublicChat(
          RoomChatBroadcast(
            id: 'bot_chat_${_room.id}_$_chatSeq',
            senderId: bot.profile.profileId,
            senderName: bot.profile.displayName,
            senderAvatar: bot.profile.avatarAsset,
            text: reply,
            isQuickReaction: isEmojiOnly,
            timestampUtc: _nowUtc(),
          ),
        ),
      );
    });
  }

  Future<void> _handleExplicitLeave(String profileId) async {
    _cancelHumanGraceTimer(profileId);
    _seatsById.remove(profileId);
    _seatTokensByUser.remove(profileId);
    _lastSeenHumanUtc.remove(profileId);
    _lastChatAtByUser.remove(profileId);

    await backend.removeRoomPlayer(roomId: _room.id, profileId: profileId);

    if (_tableState != null && !_tableState!.isRoundOver) {
      final forfeited = _engine.forfeitPlayer(
        _tableState!,
        playerId: profileId,
        reasonLabel: 'Left table',
      );
      await _commitStateTransition(forfeited);
    }

    if (humanCount == 0) {
      await closeRoom();
    } else if (_tableState == null || _tableState!.isRoundOver) {
      await _broadcastWaitingSnapshotIfIdle();
      _evaluateWaitingMatchmaking();
    }
  }

  Future<void> _handlePlayerRemoved(String profileId) async {
    _cancelHumanGraceTimer(profileId);
    _seatsById.remove(profileId);
    _seatTokensByUser.remove(profileId);
    _lastSeenHumanUtc.remove(profileId);

    if (_tableState != null && !_tableState!.isRoundOver) {
      final forfeited = _engine.forfeitPlayer(
        _tableState!,
        playerId: profileId,
        reasonLabel: 'Left table',
      );
      await _commitStateTransition(forfeited);
    }
  }

  void _onPresenceChanged(Set<String> presentIds) {
    if (_disposed || _roomStatus == 'closed') return;
    _onlinePresenceIds
      ..clear()
      ..addAll(presentIds);

    final now = _nowUtc();
    for (final entry in _seatsById.values) {
      if (entry.isBot) continue;
      final uid = entry.profile.profileId;
      if (presentIds.contains(uid)) {
        _lastSeenHumanUtc[uid] = now;
        final wasPendingDrop = _humanGraceTimers.containsKey(uid);
        _cancelHumanGraceTimer(uid);
        if (wasPendingDrop) {
          // Resend latest state & seen cards upon quick reconnect.
          final active = _tableState;
          final seatPlayer = active?.findPlayerById(uid);
          if (active != null && seatPlayer != null && seatPlayer.hasSeenCards) {
            unawaited(
              transport.sendPrivateSeatCards(
                profileId: uid,
                cards: seatPlayer.cards,
                roundNumber: active.roundNumber,
              ),
            );
          }
          unawaited(_broadcastWaitingSnapshotIfIdle());
        }
      } else {
        _armDisconnectGraceIfOffline(uid);
      }
    }
  }

  void _armDisconnectGraceIfOffline(String uid) {
    if (_disposed || _onlinePresenceIds.contains(uid)) return;
    if (_humanGraceTimers.containsKey(uid)) return;
    _humanGraceTimers[uid] = _schedule(disconnectGrace, () {
      _humanGraceTimers.remove(uid);
      unawaited(_onHumanDisconnectExpired(uid));
    });
  }

  void _cancelHumanGraceTimer(String uid) {
    _humanGraceTimers.remove(uid)?.cancel();
  }

  Future<void> _onHumanDisconnectExpired(String uid) async {
    if (_disposed || _roomStatus == 'closed') return;
    if (_onlinePresenceIds.contains(uid)) return;
    final seat = _seatsById[uid];
    if (seat == null || seat.isBot) return;

    await _handleExplicitLeave(uid);
  }

  Future<void> _commitStateTransition(AuthoritativeTableState nextState) async {
    _cancelTurnTimers();
    _tableState = nextState;

    await _broadcastTableState();

    if (nextState.isRoundOver) {
      await _settleCompletedRound(nextState);
      return;
    }

    _scheduleActiveActorTimers();
  }

  void _scheduleActiveActorTimers() {
    _cancelTurnTimers();
    final state = _tableState;
    if (state == null || state.isRoundOver || _disposed) return;

    final pending = state.pendingSideShow;
    if (pending != null) {
      final targetEntry = _seatsById[pending.targetId];
      if (targetEntry != null && targetEntry.isBot) {
        final delay = Duration(milliseconds: 900 + _rng.nextInt(1400));
        _sideShowTimer = _schedule(delay, () {
          unawaited(_executeBotSideShow(pending.targetId));
        });
      }
    }

    final deadline = state.turnDeadline;
    final timeoutDelay = deadline != null
        ? deadline.difference(_nowUtc()).clampNonNegative()
        : turnTimeout;

    _turnTimeoutTimer = _schedule(timeoutDelay, () {
      unawaited(_onTurnDeadlineExpired());
    });

    if (pending == null) {
      final active = state.activeTurnPlayer;
      if (active != null) {
        final activeSeat = _seatsById[active.id];
        if (activeSeat != null && activeSeat.isBot) {
          final plan = botRunner.planTurn(
            authorativeState: state,
            botId: active.id,
            nowUtc: _nowUtc(),
          );
          if (!plan.shouldTimeout) {
            _botActTimer = _schedule(plan.thinkDelay, () {
              unawaited(_executePlannedBotTurn(active.id, plan));
            });
          }
        }
      }
    }
  }

  Future<void> _executeBotSideShow(String botId) async {
    final state = _tableState;
    if (_disposed || state == null || state.isRoundOver) return;
    final pending = state.pendingSideShow;
    if (pending == null || pending.targetId != botId) return;

    final accepted = botRunner.decideSideShow(
      authorativeState: state,
      targetBotId: botId,
    );
    final nextState = _engine.resolveSideShow(state, accepted: accepted);
    await _commitStateTransition(nextState);
  }

  Future<void> _executePlannedBotTurn(
    String botId,
    HumanizedBotTurnPlan plan,
  ) async {
    final state = _tableState;
    if (_disposed || state == null || state.isRoundOver) return;
    if (state.pendingSideShow != null) return;
    final active = state.activeTurnPlayer;
    if (active == null || active.id != botId) return;

    var working = state;
    if (plan.seeCards && !active.hasSeenCards) {
      working = _engine.seeCards(working, playerId: botId);
    }
    final decision = plan.decision;
    if (decision == null) return;

    try {
      working = _engine.applyAction(
        working,
        playerId: botId,
        action: decision.action,
        raiseStake: decision.raiseStake,
      );
      await _commitStateTransition(working);
    } catch (_) {
      final packed = _engine.forfeitPlayer(
        working,
        playerId: botId,
        reasonLabel: 'Packed',
      );
      await _commitStateTransition(packed);
    }
  }

  Future<void> _onTurnDeadlineExpired() async {
    final state = _tableState;
    if (_disposed || state == null || state.isRoundOver) return;

    final pending = state.pendingSideShow;
    if (pending != null) {
      final resolved = _engine.resolveSideShow(state, accepted: false);
      await _commitStateTransition(resolved);
      return;
    }

    final active = state.activeTurnPlayer;
    if (active == null) return;

    final packed = _engine.applyAction(
      state,
      playerId: active.id,
      action: PlayerTableAction.pack,
    );
    await _commitStateTransition(packed);
  }

  Future<void> _settleCompletedRound(AuthoritativeTableState finished) async {
    if (_settlingHand) return;
    _settlingHand = true;
    try {
      final result = finished.roundResult;
      if (result == null) return;

      final hasHuman = finished.players.any(
        (p) => !(_seatsById[p.id]?.isBot ?? p.isClientBot),
      );

      final deltas = <SettlementSeatDelta>[];
      for (final player in finished.players) {
        final isBot = _seatsById[player.id]?.isBot ??
            player.participantKind == ParticipantKind.onlineAgent;
        final won = player.id == result.winner.id;
        final wonAmount = won ? result.wonAmount : 0;
        final delta = SettlementSeatDelta(
          profileId: player.id,
          won: won,
          bootAmount: min(_room.minStake, player.totalBet),
          investedAmount: player.totalBet,
          wonAmount: wonAmount,
          potAmount: finished.potAmount,
          handLabel: result.handLabel,
          winReason: result.winReason,
          tableName: _room.tableName,
          variant: _room.variant,
          isBot: isBot,
        );
        deltas.add(delta);
        if (isBot) {
          botRunner.recordHandOutcome(player.id, netChips: delta.netChips);
        }
      }

      await backend.settleRound(
        roomId: _room.id,
        roundNumber: finished.roundNumber,
        seats: deltas,
        hasHumanParticipant: hasHuman,
      );

      if (_disposed) return;

      await _vacatePendingExitBots();

      if (humanCount == 0) {
        await closeRoom();
        return;
      }

      _nextRoundTimer?.cancel();
      _nextRoundTimer = _schedule(roundBreakDuration, () {
        _nextRoundTimer = null;
        unawaited(_tryStartNextHand());
      });
    } finally {
      _settlingHand = false;
    }
  }

  Future<void> _broadcastTableState() async {
    final state = _tableState;
    if (state == null || _disposed) return;
    final publicObs = SeatObservation.publicFromTableState(state);
    await transport.sendPublicState(publicObs);
  }

  Future<void> _broadcastWaitingSnapshotIfIdle() async {
    final active = _tableState;
    if (active != null && !active.isRoundOver) {
      await _broadcastTableState();
      return;
    }
    if (_disposed || _roomStatus == 'closed') return;
    final sorted = _seatsById.values.toList()
      ..sort((a, b) => a.profile.seatIndex.compareTo(b.profile.seatIndex));

    final obs = SeatObservation(
      tableName: _room.tableName,
      viewerId: '',
      minStake: _room.minStake,
      maxStake: _room.maxStake,
      potAmount: 0,
      blindAmount: _room.minStake,
      chaalAmount: _room.minStake * 2,
      variant: TeenPattiVariant.fromLabel(_room.variant),
      roundNumber: 0,
      seats: [
        for (final entry in sorted)
          ObservedSeat(
            id: entry.profile.profileId,
            name: entry.profile.displayName,
            chips: entry.profile.chips,
            avatarAsset: entry.profile.avatarAsset,
            seatIndex: entry.profile.seatIndex,
            rating: entry.profile.rating,
          ),
      ],
    );
    await transport.sendPublicState(obs);
  }

  void _cancelTurnTimers() {
    _turnTimeoutTimer?.cancel();
    _turnTimeoutTimer = null;
    _botActTimer?.cancel();
    _botActTimer = null;
    _sideShowTimer?.cancel();
    _sideShowTimer = null;
  }

  Future<void> closeRoom() async {
    if (_disposed) return;
    _disposed = true;
    _roomStatus = 'closed';

    _cancelBotJoinTimer();
    _cancelTurnTimers();
    _nextRoundTimer?.cancel();
    _nextRoundTimer = null;
    _botChatTimer?.cancel();
    _botChatTimer = null;
    for (final timer in _humanGraceTimers.values) {
      timer.cancel();
    }
    _humanGraceTimers.clear();

    final bots = _seatsById.values
        .where((s) => s.isBot)
        .map((s) => s.profile.profileId)
        .toList();
    for (final botId in bots) {
      botRunner.unregisterBot(botId);
      try {
        await backend.removeRoomPlayer(roomId: _room.id, profileId: botId);
        await backend.releaseBot(botId);
      } catch (_) {}
    }

    try {
      await backend.updateRoomStatus(_room.id, 'closed');
    } catch (_) {}

    await _actionSub?.cancel();
    await _presenceSub?.cancel();
    await transport.dispose();
  }
}

extension on Duration {
  Duration clampNonNegative() => isNegative ? Duration.zero : this;
}
