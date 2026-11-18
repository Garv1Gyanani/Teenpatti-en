import 'dart:async';

import 'package:realtime_client/realtime_client.dart';
import 'package:teen_patti_core/teen_patti_core.dart';

class RoomActionMessage {
  const RoomActionMessage({
    required this.playerId,
    required this.action,
    this.raiseStake = false,
    this.seeFirst = false,
    this.targetId,
    this.accepted,
    this.text,
    this.isQuickReaction = false,
    this.requestId,
  });

  factory RoomActionMessage.fromJson(Map<String, dynamic> json) {
    return RoomActionMessage(
      playerId: json['playerId'] as String? ?? json['player_id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      raiseStake: json['raiseStake'] as bool? ?? json['raise_stake'] as bool? ?? false,
      seeFirst: json['seeFirst'] as bool? ?? json['see_first'] as bool? ?? false,
      targetId: json['targetId'] as String? ?? json['target_id'] as String?,
      accepted: json['accepted'] as bool?,
      text: json['text'] as String?,
      isQuickReaction:
          json['isQuickReaction'] as bool? ??
          json['is_quick_reaction'] as bool? ??
          false,
      requestId: json['requestId'] as String? ?? json['request_id'] as String?,
    );
  }

  final String playerId;
  final String action;
  final bool raiseStake;
  final bool seeFirst;
  final String? targetId;
  final bool? accepted;
  final String? text;
  final bool isQuickReaction;
  final String? requestId;
}

class RoomChatBroadcast {
  const RoomChatBroadcast({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.isQuickReaction,
    required this.timestampUtc,
  });

  factory RoomChatBroadcast.fromJson(Map<String, dynamic> json) {
    final tsRaw = json['timestampUtc'] as String?;
    return RoomChatBroadcast(
      id: (json['id'] as String?) ?? 'chat_0',
      senderId: (json['senderId'] as String?) ?? '',
      senderName: (json['senderName'] as String?) ?? 'Player',
      senderAvatar: (json['senderAvatar'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      isQuickReaction: (json['isQuickReaction'] as bool?) ?? false,
      timestampUtc: tsRaw != null
          ? DateTime.tryParse(tsRaw)?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }

  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final bool isQuickReaction;
  final DateTime timestampUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'text': text,
        'isQuickReaction': isQuickReaction,
        'timestampUtc': timestampUtc.toUtc().toIso8601String(),
      };
}

abstract class RoomTransport {
  Stream<RoomActionMessage> get actions;

  Stream<Set<String>> get onlineUserIds;

  Future<void> connect();

  Future<void> sendPublicState(SeatObservation publicState);

  Future<void> sendPublicChat(RoomChatBroadcast message);

  Future<void> sendPrivateSeatCards({
    required String profileId,
    required List<PlayingCard> cards,
    required int roundNumber,
  });

  Future<void> dispose();
}

abstract class RoomTransportFactory {
  RoomTransport create(String roomId);

  Future<void> dispose();
}

Map<String, dynamic> unwrapRealtimeBroadcastPayload(
  Map<String, dynamic> raw,
) {
  var current = Map<String, dynamic>.from(raw);
  while (current['payload'] is Map) {
    current = Map<String, dynamic>.from(current['payload'] as Map);
  }
  current.remove('type');
  current.remove('event');
  return current;
}

class SupabaseRealtimeTransportFactory implements RoomTransportFactory {
  SupabaseRealtimeTransportFactory({
    required String supabaseUrl,
    required String serviceRoleKey,
    this.workerKey = 'authoritative-worker',
  })  : _socket = RealtimeClient(
          _toRealtimeWsUrl(supabaseUrl),
          headers: <String, String>{
            'apikey': serviceRoleKey,
            'Authorization': 'Bearer $serviceRoleKey',
          },
          params: <String, String>{'apikey': serviceRoleKey},
        ),
        _serviceRoleKey = serviceRoleKey;

  final RealtimeClient _socket;
  final String _serviceRoleKey;
  final String workerKey;
  bool _authConfigured = false;

  Future<void> ensureAuthConfigured() async {
    if (_authConfigured) return;
    _authConfigured = true;
    await _socket.setAuth(_serviceRoleKey);
  }

  @override
  RoomTransport create(String roomId) {
    return _SupabaseRealtimeRoomTransport(
      roomId: roomId,
      socket: _socket,
      ensureAuthConfigured: ensureAuthConfigured,
      workerKey: workerKey,
    );
  }

  @override
  Future<void> dispose() async {
    await _socket.removeAllChannels();
  }

  static String _toRealtimeWsUrl(String rawUrl) {
    final trimmed = rawUrl.trim().endsWith('/')
        ? rawUrl.trim().substring(0, rawUrl.trim().length - 1)
        : rawUrl.trim();
    if (trimmed.startsWith('https://')) {
      return 'wss://${trimmed.substring(8)}/realtime/v1';
    }
    if (trimmed.startsWith('http://')) {
      return 'ws://${trimmed.substring(7)}/realtime/v1';
    }
    return '$trimmed/realtime/v1';
  }
}

class _SupabaseRealtimeRoomTransport implements RoomTransport {
  _SupabaseRealtimeRoomTransport({
    required this.roomId,
    required RealtimeClient socket,
    required Future<void> Function() ensureAuthConfigured,
    required String workerKey,
  })  : _socket = socket,
        _ensureAuthConfigured = ensureAuthConfigured,
        _workerKey = workerKey;

  final String roomId;
  final RealtimeClient _socket;
  final Future<void> Function() _ensureAuthConfigured;
  final String _workerKey;

  final _actionsController = StreamController<RoomActionMessage>.broadcast();
  final _presenceController = StreamController<Set<String>>.broadcast();

  RealtimeChannel? _publicChannel;
  RealtimeChannel? _actionsChannel;
  final Map<String, RealtimeChannel> _seatChannels = {};
  bool _disposed = false;

  @override
  Stream<RoomActionMessage> get actions => _actionsController.stream;

  @override
  Stream<Set<String>> get onlineUserIds => _presenceController.stream;

  @override
  Future<void> connect() async {
    await _ensureAuthConfigured();
    if (_disposed) return;

    RealtimeChannel buildPublicChannel() {
      final chan = _socket.channel(
        'room:$roomId:public',
        RealtimeChannelConfig(private: true, key: _workerKey),
      );
      void emitPresence() {
        if (_disposed) return;
        final keys = <String>{};
        for (final single in chan.presenceState()) {
          for (final presence in single.presences) {
            final uid = presence.payload['user_id'] as String? ?? single.key;
            if (uid.isNotEmpty && uid != _workerKey) {
              keys.add(uid);
            }
          }
          if (single.key.isNotEmpty && single.key != _workerKey) {
            keys.add(single.key);
          }
        }
        _presenceController.add(keys);
      }

      chan
          .onPresenceSync((_) => emitPresence())
          .onPresenceJoin((_) => emitPresence())
          .onPresenceLeave((_) => emitPresence());
      return chan;
    }

    RealtimeChannel buildActionsChannel() {
      final chan = _socket.channel(
        'room:$roomId:actions',
        const RealtimeChannelConfig(private: true),
      );
      chan.onBroadcast(
        event: 'action',
        callback: (raw) {
          if (_disposed) return;
          final data = unwrapRealtimeBroadcastPayload(raw);
          final msg = RoomActionMessage.fromJson(data);
          if (msg.playerId.isNotEmpty && msg.action.isNotEmpty) {
            _actionsController.add(msg);
          }
        },
      );
      return chan;
    }

    final results = await Future.wait([
      _subscribeWithRetry(buildPublicChannel, 'room:$roomId:public'),
      _subscribeWithRetry(buildActionsChannel, 'room:$roomId:actions'),
    ]);
    _publicChannel = results[0];
    _actionsChannel = results[1];
  }

  Future<RealtimeChannel> _subscribeWithRetry(
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
          await _socket.removeChannel(channel);
        } catch (_) {}
        if (!isPartitionWarmup || attempt == maxAttempts || _disposed) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    throw StateError('Channel $label failed after $maxAttempts attempts');
  }

  @override
  Future<void> sendPublicState(SeatObservation publicState) async {
    final chan = _publicChannel;
    if (chan == null || _disposed) return;
    await chan.sendBroadcastMessage(
      event: 'state',
      payload: <String, dynamic>{'payload': publicState.toPublicJson()},
    );
  }

  @override
  Future<void> sendPublicChat(RoomChatBroadcast message) async {
    final chan = _publicChannel;
    if (chan == null || _disposed) return;
    await chan.sendBroadcastMessage(
      event: 'chat',
      payload: <String, dynamic>{'payload': message.toJson()},
    );
  }

  @override
  Future<void> sendPrivateSeatCards({
    required String profileId,
    required List<PlayingCard> cards,
    required int roundNumber,
  }) async {
    if (_disposed) return;
    var chan = _seatChannels[profileId];
    if (chan == null) {
      chan = await _subscribeWithRetry(
        () => _socket.channel(
          'room:$roomId:seat:$profileId',
          const RealtimeChannelConfig(private: true),
        ),
        'room:$roomId:seat:$profileId',
      );
      _seatChannels[profileId] = chan;
    }
    if (_disposed) return;
    await chan.sendBroadcastMessage(
      event: 'cards',
      payload: <String, dynamic>{
        'payload': <String, dynamic>{
          'roundNumber': roundNumber,
          'cards': cards.map((c) => c.toJson()).toList(),
        },
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final channels = <RealtimeChannel>[
      ?_publicChannel,
      ?_actionsChannel,
      ..._seatChannels.values,
    ];
    _seatChannels.clear();
    for (final c in channels) {
      try {
        await _socket.removeChannel(c);
      } catch (_) {}
    }
    await _actionsController.close();
    await _presenceController.close();
  }
}
