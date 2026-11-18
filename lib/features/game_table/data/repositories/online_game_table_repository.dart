import 'dart:async';
import 'dart:math';

import 'package:realtime_client/realtime_client.dart';
import 'package:teen_patti_core/teen_patti_core.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/session/app_session_store.dart';
import '../../../../core/session/supabase_sync_client.dart';
import '../../domain/entities/game_table_config.dart';
import '../../domain/entities/table_chat_message.dart';
import '../../domain/repositories/game_table_repository.dart';

typedef RealtimeClientFactory = RealtimeClient Function(
  String url, {
  Map<String, String>? headers,
  Map<String, String>? params,
});

/// Recursively unwraps nested `payload` envelopes from Realtime broadcast JSON.
Map<String, dynamic> unwrapOnlineBroadcastPayload(Map<String, dynamic> raw) {
  var current = Map<String, dynamic>.from(raw);
  while (current['payload'] is Map) {
    current = Map<String, dynamic>.from(current['payload'] as Map);
  }
  current.remove('type');
  current.remove('event');
  return current;
}

/// Online [GameTableRepository] backed by Supabase Realtime Broadcast/Presence
/// channels and the authoritative Dart worker.
class OnlineGameTableRepository implements GameTableRepository {
  OnlineGameTableRepository({
    required this.config,
    required this.sessionStore,
    OnlineRoomTicket? initialTicket,
    RealtimeClientFactory? realtimeClientFactory,
  })  : _ticket = initialTicket,
        _realtimeClientFactory = realtimeClientFactory;

  final GameTableConfig config;
  final AppSessionStore sessionStore;
  final RealtimeClientFactory? _realtimeClientFactory;

  final StreamController<TableState> _stateController =
      StreamController<TableState>.broadcast();
  final StreamController<TableChatMessage> _chatController =
      StreamController<TableChatMessage>.broadcast();
  final Map<int, int> _roundStartChips = <int, int>{};

  OnlineRoomTicket? _ticket;
  RealtimeClient? _socket;
  RealtimeChannel? _publicChannel;
  RealtimeChannel? _actionsChannel;
  Timer? _jwtRefreshTimer;
  DateTime? _lastChatSentAt;

  Map<String, dynamic>? _lastPublicJson;
  List<PlayingCard> _myCards = const <PlayingCard>[];
  int _myCardsRound = -1;
  int _syncedResultRound = -1;
  int _actionSeq = 0;
  bool _disposed = false;
  bool _leaving = false;

  Stream<TableState> get stateStream => _stateController.stream;

  Stream<TableChatMessage> get chatStream => _chatController.stream;

  String? get roomId => _ticket?.roomId ?? config.roomId;

  String? get roomCode => _ticket?.roomCode ?? config.roomCode;

  /// Ensures authenticated Supabase session & synced chip balance before load.
  Future<bool> prepareSession() => sessionStore.prepareOnlineSession();

  @override
  Future<TableState> getInitialTableState() async {
    final authed = await sessionStore.prepareOnlineSession();
    final supabase = sessionStore.supabaseClient;
    final uid = supabase.authUserId;
    final jwt = supabase.accessToken;
    if (!authed || uid == null || jwt == null) {
      throw const OnlineMatchmakingException(
        'Could not authenticate online session.',
      );
    }

    _ticket ??= await _acquireRoomTicket(supabase);
    final ticket = _ticket!;
    if (_disposed) {
      return _buildWaitingPlaceholderState(uid: uid, ticket: ticket);
    }

    await _connectRealtime(
      supabase: supabase,
      roomId: ticket.roomId,
      uid: uid,
      jwt: jwt,
    );

    return _buildWaitingPlaceholderState(uid: uid, ticket: ticket);
  }

  Future<OnlineRoomTicket> _acquireRoomTicket(
    SupabaseSyncClient supabase,
  ) async {
    if (config.roomId != null && config.roomId!.isNotEmpty) {
      return OnlineRoomTicket(
        roomId: config.roomId!,
        roomCode: config.roomCode,
        seatIndex: 0,
        tableName: config.tableName,
        variant: config.variant,
        minStake: config.minStake,
        maxStake: config.maxStake,
        maxPlayers: config.maxPlayers,
        fillWithAi: config.fillWithAi,
        isPrivate: config.roomCode != null && config.roomCode!.isNotEmpty,
      );
    }

    if (config.roomCode != null && config.roomCode!.isNotEmpty) {
      final joined = await supabase.joinRoomByCode(config.roomCode!);
      if (joined != null) return joined;
    }

    final ticket = await supabase.joinOrCreatePublicRoom(
      minStake: config.minStake,
      maxStake: config.maxStake,
      maxPlayers: config.maxPlayers,
      variant: config.variant,
      tableName: config.tableName,
    );
    if (ticket == null) {
      throw const OnlineMatchmakingException(
        'Failed to join or create an online room.',
      );
    }
    return ticket;
  }

  Future<void> _connectRealtime({
    required SupabaseSyncClient supabase,
    required String roomId,
    required String uid,
    required String jwt,
  }) async {
    final headers = <String, String>{
      'apikey': supabase.supabaseAnonKey,
      'Authorization': 'Bearer $jwt',
    };
    final params = <String, String>{'apikey': supabase.supabaseAnonKey};

    final factory = _realtimeClientFactory;
    final socket = factory != null
        ? factory(
            supabase.realtimeWebSocketUrl,
            headers: headers,
            params: params,
          )
        : RealtimeClient(
            supabase.realtimeWebSocketUrl,
            headers: headers,
            params: params,
          );
    _socket = socket;
    await socket.setAuth(jwt);

    _publicChannel = await _subscribeWithRetry(
      socket,
      () {
        final chan = socket.channel(
          'room:$roomId:public',
          RealtimeChannelConfig(private: true, key: uid),
        );
        chan.onBroadcast(
          event: 'state',
          callback: (raw) {
            if (_disposed) return;
            final data = unwrapOnlineBroadcastPayload(raw);
            _lastPublicJson = data;
            _emitObservation(data, uid: uid);
          },
        );
        chan.onBroadcast(
          event: 'chat',
          callback: (raw) {
            if (_disposed) return;
            final data = unwrapOnlineBroadcastPayload(raw);
            _emitChatBroadcast(data, uid: uid);
          },
        );
        return chan;
      },
      'room:$roomId:public',
    );

    if (!_disposed && _publicChannel != null) {
      try {
        await _publicChannel!.track(<String, dynamic>{
          'user_id': uid,
          'online_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {
        // Non-fatal; periodic or next Presence sync covers transient failure.
      }
    }

    await _subscribeWithRetry(
      socket,
      () {
        final chan = socket.channel(
          'room:$roomId:seat:$uid',
          const RealtimeChannelConfig(private: true),
        );
        chan.onBroadcast(
          event: 'cards',
          callback: (raw) {
            if (_disposed) return;
            final data = unwrapOnlineBroadcastPayload(raw);
            final roundNumber = (data['roundNumber'] as num?)?.toInt() ?? 0;
            final rawCards = data['cards'] as List<dynamic>? ?? const [];
            final parsedCards = rawCards
                .whereType<Map<String, dynamic>>()
                .map(PlayingCard.fromJson)
                .toList(growable: false);
            _myCardsRound = roundNumber;
            _myCards = List<PlayingCard>.unmodifiable(parsedCards);
            if (_lastPublicJson != null) {
              _emitObservation(_lastPublicJson!, uid: uid);
            }
          },
        );
        return chan;
      },
      'room:$roomId:seat:$uid',
    );

    // Actions channel is insert-only for clients: never subscribe, send via REST fallback.
    _actionsChannel = socket.channel(
      'room:$roomId:actions',
      const RealtimeChannelConfig(private: true),
    );

    _jwtRefreshTimer?.cancel();
    _jwtRefreshTimer = Timer.periodic(const Duration(minutes: 45), (_) async {
      if (_disposed) return;
      final refreshed = await supabase.refreshSession();
      final nextJwt = supabase.accessToken;
      if (refreshed && nextJwt != null && !_disposed) {
        await _socket?.setAuth(nextJwt);
      }
    });
  }

  Future<RealtimeChannel> _subscribeWithRetry(
    RealtimeClient socket,
    RealtimeChannel Function() buildChannel,
    String label,
  ) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final channel = buildChannel();
      final completer = Completer<void>();
      channel.subscribe((status, error) {
        if (completer.isCompleted) return;
        if (status == RealtimeSubscribeStatus.subscribed) {
          completer.complete();
        } else if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          completer.completeError(
            error ?? StateError('Channel $label failed: $status'),
          );
        }
      });

      try {
        await completer.future.timeout(const Duration(seconds: 10));
        return channel;
      } catch (err) {
        final isPartitionWarmup = err.toString().contains('MissingPartition');
        try {
          await socket.removeChannel(channel);
        } catch (_) {}
        if (!isPartitionWarmup || attempt == maxAttempts || _disposed) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    throw StateError('Failed to subscribe to $label');
  }

  void _emitObservation(
    Map<String, dynamic> publicJson, {
    required String uid,
  }) {
    final publicRound = (publicJson['roundNumber'] as num?)?.toInt() ?? 0;
    final cardsForRound =
        _myCardsRound == publicRound ? _myCards : const <PlayingCard>[];

    final obs = SeatObservation.fromPublicAndPrivateJson(
      publicJson: publicJson,
      viewerId: uid,
      myCards: cardsForRound,
    );

    final mapped = mapObservationToTableState(
      obs,
      viewerId: uid,
      localFallback: _localFallbackUser(uid),
      roundStartChipsByRound: _roundStartChips,
      privateRoomCode: roomCode,
      lastKnownRoundStart: _roundStartChips[obs.roundNumber],
    );

    if (obs.roundNumber > 0) {
      final local = mapped.localPlayerOrNull;
      if (local != null) {
        _roundStartChips.putIfAbsent(
          obs.roundNumber,
          () => local.chips + local.totalBet,
        );
      }
    }

    if (obs.isRoundOver &&
        obs.roundNumber > 0 &&
        _syncedResultRound != obs.roundNumber) {
      _syncedResultRound = obs.roundNumber;
      final local = mapped.localPlayerOrNull;
      if (local != null) {
        unawaited(sessionStore.applyOnlineChipsFromServer(local.chips));
        unawaited(sessionStore.syncOnlineProfileFromServer());
      }
    }

    if (!_disposed && !_stateController.isClosed) {
      _stateController.add(mapped);
    }
  }

  /// Pure mapper converting a sanitized server [SeatObservation] into UI
  /// [TableState]. Exposed for unit testing.
  static TableState mapObservationToTableState(
    SeatObservation obs, {
    required String viewerId,
    required TablePlayer localFallback,
    Map<int, int>? roundStartChipsByRound,
    int? lastKnownRoundStart,
    String? privateRoomCode,
  }) {
    final mappedPlayers = <TablePlayer>[];
    for (final seat in obs.seats) {
      final isLocal = seat.id == viewerId;
      mappedPlayers.add(
        TablePlayer(
          id: seat.id,
          name: seat.name,
          chips: seat.chips,
          avatarAsset: seat.avatarAsset,
          // Keep online seat presentation uniform on client; bots are never marked.
          participantKind: ParticipantKind.human,
          rating: seat.rating,
          isLocalPlayer: isLocal,
          isDealer: seat.isDealer,
          isActiveTurn: seat.isActiveTurn,
          hasPacked: seat.hasPacked,
          hasSeenCards: seat.hasSeenCards,
          hasGiftBadge: seat.hasGiftBadge,
          cards: isLocal ? obs.myCards : seat.revealedCards,
          totalBet: seat.totalBet,
          lastBetAmount: seat.lastBetAmount,
          blindTurnsTaken: seat.blindTurnsTaken,
          lastActionText: seat.lastActionText,
        ),
      );
    }

    if (!mappedPlayers.any((p) => p.isLocalPlayer)) {
      mappedPlayers.insert(0, localFallback);
    }

    final local = mappedPlayers.firstWhere((p) => p.isLocalPlayer);
    final trackedStart = roundStartChipsByRound?[obs.roundNumber] ??
        lastKnownRoundStart ??
        (local.chips + local.totalBet);

    RoundResult? roundResult;
    if (obs.isRoundOver && obs.winnerId != null) {
      final winner = mappedPlayers.firstWhere(
        (p) => p.id == obs.winnerId,
        orElse: () => mappedPlayers.first,
      );
      final showdownHands = mappedPlayers
          .where((p) => !p.hasPacked && p.cards.length == 3)
          .map(
            (p) => ShowdownHandSummary(
              player: p,
              handLabel: TeenPattiHandEvaluator.evaluate(
                p.cards,
                variant: obs.variant,
                jokerCard: obs.jokerCard,
              ).label,
              isWinner: p.id == winner.id,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => a.isWinner ? -1 : (b.isWinner ? 1 : 0));

      String? winningShowdownLabel;
      for (final h in showdownHands) {
        if (h.isWinner) {
          winningShowdownLabel = h.handLabel;
          break;
        }
      }
      final winnerLabel = winningShowdownLabel ??
          (winner.cards.length == 3
              ? TeenPattiHandEvaluator.evaluate(
                  winner.cards,
                  variant: obs.variant,
                  jokerCard: obs.jokerCard,
                ).label
              : 'Uncontested Pot');

      final packedOpponents = mappedPlayers
          .where((p) => p.hasPacked && !p.isLocalPlayer)
          .toList(growable: false);

      roundResult = RoundResult(
        wonAmount: obs.potAmount,
        previousBalance: trackedStart,
        newBalance: local.chips,
        handLabel: winnerLabel,
        winner: winner,
        packedOpponents: packedOpponents,
        showdownHands: showdownHands,
        winReason: obs.winReason ?? 'Won Hand',
      );
    }

    final isWaiting = obs.roundNumber <= 0;
    final defaultWaitingLabel = privateRoomCode != null &&
            privateRoomCode.isNotEmpty
        ? 'Room $privateRoomCode • Waiting for players...'
        : 'Searching for players...';

    return TableState(
      tableName: obs.tableName,
      minStake: obs.minStake,
      maxStake: obs.maxStake,
      potAmount: obs.potAmount,
      blindAmount: obs.blindAmount,
      chaalAmount: obs.chaalAmount,
      players: List<TablePlayer>.unmodifiable(mappedPlayers),
      variant: obs.variant,
      jokerCard: obs.jokerCard,
      maxBlindTurns: obs.maxBlindTurns,
      roundNumber: obs.roundNumber,
      turnCount: obs.turnCount,
      dealerIndex: obs.dealerIndex,
      activeTurnIndex: obs.activeTurnIndex,
      potLimit: obs.potLimit,
      localRoundStartChips: trackedStart,
      turnDeadline: obs.turnDeadline,
      pendingSideShow: obs.pendingSideShow,
      lastActionLabel: obs.lastActionLabel ??
          (isWaiting ? defaultWaitingLabel : null),
      roundActionLog: obs.roundActionLog,
      roundResult: roundResult,
    );
  }

  TablePlayer _localFallbackUser(String uid) {
    final user = sessionStore.toLocalGameUser(isPractice: false);
    return TablePlayer(
      id: uid,
      name: user.name,
      chips: user.chips,
      avatarAsset: user.avatarAsset,
      participantKind: ParticipantKind.human,
      rating: user.rating,
      isLocalPlayer: true,
    );
  }

  TableState _buildWaitingPlaceholderState({
    required String uid,
    required OnlineRoomTicket ticket,
  }) {
    final codePrefix =
        ticket.roomCode != null && ticket.roomCode!.isNotEmpty
            ? 'Room ${ticket.roomCode} • '
            : '';
    return TableState(
      tableName: ticket.tableName,
      minStake: ticket.minStake,
      maxStake: ticket.maxStake,
      potAmount: 0,
      blindAmount: ticket.minStake,
      chaalAmount: ticket.minStake * 2,
      players: <TablePlayer>[_localFallbackUser(uid)],
      variant: TeenPattiVariant.fromLabel(ticket.variant),
      roundNumber: 0,
      lastActionLabel: ticket.isPrivate
          ? '${codePrefix}Waiting for players...'
          : 'Searching for players...',
    );
  }

  @override
  Future<TableState> seeCards({
    required TableState currentState,
    required String playerId,
  }) async {
    await _sendAction(
      <String, dynamic>{'playerId': playerId, 'action': 'seeCards'},
    );
    return currentState;
  }

  @override
  Future<TableState> performAction({
    required TableState currentState,
    required PlayerTableAction action,
    String? playerId,
    bool raiseStake = false,
  }) async {
    final uid =
        playerId ?? sessionStore.supabaseClient.authUserId ?? currentState.localPlayer.id;
    await _sendAction(<String, dynamic>{
      'playerId': uid,
      'action': action.name,
      if (raiseStake) 'raiseStake': true,
    });
    return currentState;
  }

  @override
  Future<TableState> resolveSideShow({
    required TableState currentState,
    required bool accepted,
  }) async {
    final uid = sessionStore.supabaseClient.authUserId ?? currentState.localPlayer.id;
    await _sendAction(<String, dynamic>{
      'playerId': uid,
      'action': 'sideShowResponse',
      'accepted': accepted,
    });
    return currentState;
  }

  @override
  Future<TableState> dealNewHand({required TableState currentState}) async {
    // Authoritative server deals next hands automatically.
    return currentState;
  }

  @override
  Future<TableState> performAutomatedTurn({
    required TableState currentState,
  }) async {
    return currentState;
  }

  void _emitChatBroadcast(
    Map<String, dynamic> data, {
    required String uid,
  }) {
    if (_disposed || _chatController.isClosed) return;
    final text = (data['text'] as String?)?.trim() ?? '';
    final senderId = (data['senderId'] as String?)?.trim() ?? '';
    if (text.isEmpty || senderId.isEmpty) return;

    final senderName = (data['senderName'] as String?)?.trim() ?? 'Player';
    final senderAvatar = (data['senderAvatar'] as String?)?.trim();
    final isQuickReaction = (data['isQuickReaction'] as bool?) ?? false;
    final tsRaw = data['timestampUtc'] as String?;
    final timestamp = tsRaw != null
        ? DateTime.tryParse(tsRaw)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    _chatController.add(
      TableChatMessage(
        id: (data['id'] as String?) ??
            'online_chat_${DateTime.now().millisecondsSinceEpoch}',
        senderId: senderId,
        senderName: senderName,
        senderAvatar:
            senderAvatar != null && senderAvatar.isNotEmpty
                ? senderAvatar
                : AppAssets.avatar2,
        text: text,
        timestamp: timestamp,
        isLocal: senderId == uid,
        isQuickReaction: isQuickReaction,
      ),
    );
  }

  /// Sends a rate-limited table chat message or emoji reaction to `room:{id}:actions`
  /// for authoritative relay onto `room:{id}:public`.
  Future<bool> sendChatOrReaction({
    required String text,
    required bool isQuickReaction,
    String? playerId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _disposed) return false;

    final now = DateTime.now();
    final last = _lastChatSentAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 1000)) {
      return false;
    }
    _lastChatSentAt = now;

    final sanitized =
        trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed;
    final uid = playerId ?? sessionStore.supabaseClient.authUserId ?? 'local';
    await _sendAction(<String, dynamic>{
      'playerId': uid,
      'action': isQuickReaction ? 'reaction' : 'chat',
      'text': sanitized,
      'isQuickReaction': isQuickReaction,
    });
    return true;
  }

  Future<void> _sendAction(Map<String, dynamic> payload) async {
    final chan = _actionsChannel;
    if (_disposed || chan == null) return;
    _actionSeq++;
    await chan.sendBroadcastMessage(
      event: 'action',
      payload: <String, dynamic>{
        ...payload,
        'requestId': 'req_${_actionSeq}_${Random().nextInt(99999)}',
      },
    );
  }

  /// Sends explicit `'leave'` signal to worker, removes DB seat, and closes channels.
  Future<void> leaveTable() async {
    if (_leaving) return;
    _leaving = true;

    final uid = sessionStore.supabaseClient.authUserId;
    final activeRoomId = roomId;

    if (uid != null && !_disposed) {
      try {
        await _sendAction(<String, dynamic>{
          'playerId': uid,
          'action': 'leave',
        }).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    if (_publicChannel != null) {
      try {
        await _publicChannel!.untrack();
      } catch (_) {}
    }

    if (activeRoomId != null && activeRoomId.isNotEmpty) {
      try {
        await sessionStore.supabaseClient.leaveRoomSeat(activeRoomId);
      } catch (_) {}
    }

    await dispose();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _jwtRefreshTimer?.cancel();
    _jwtRefreshTimer = null;

    if (_socket != null) {
      try {
        await _socket!.removeAllChannels();
      } catch (_) {}
      try {
        await _socket!.disconnect();
      } catch (_) {}
      _socket = null;
    }

    _publicChannel = null;
    _actionsChannel = null;

    if (!_stateController.isClosed) {
      await _stateController.close();
    }
    if (!_chatController.isClosed) {
      await _chatController.close();
    }
  }
}
