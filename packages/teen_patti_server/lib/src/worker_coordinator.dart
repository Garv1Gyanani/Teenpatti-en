import 'dart:async';
import 'dart:math';

import 'humanized_bot_runner.dart';
import 'room_actor.dart';
import 'room_transport.dart';
import 'server_backend.dart';

/// Top-level coordinator for the single-instance authoritative game worker.
///
/// Clears orphaned bot locks and voids held round escrows on boot, emits
/// regular heartbeats, reconciles active `tp_rooms` with live [RoomActor]
/// instances, and periodically tops up depleted bot bankrolls.
class WorkerCoordinator {
  WorkerCoordinator({
    required this.backend,
    required this.transportFactory,
    HumanizedBotRunner? botRunner,
    TaskScheduler? scheduleTask,
    DateTime Function()? nowUtc,
    Random? random,
    String? workerId,
    this.syncInterval = const Duration(seconds: 2),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.topUpInterval = const Duration(minutes: 10),
    this.turnTimeout = const Duration(seconds: 25),
    this.disconnectGrace = const Duration(seconds: 25),
    this.roundBreakDuration = const Duration(seconds: 4),
  })  : botRunner = botRunner ?? HumanizedBotRunner(random: random),
        _schedule = scheduleTask ?? defaultTaskScheduler,
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
        _rng = random ?? Random.secure(),
        workerId = workerId ?? 'tp-worker-${DateTime.now().toUtc().millisecondsSinceEpoch}';

  final ServerBackendGateway backend;
  final RoomTransportFactory transportFactory;
  final HumanizedBotRunner botRunner;
  final TaskScheduler _schedule;
  final DateTime Function() _nowUtc;
  final Random _rng;
  final String workerId;
  final Duration syncInterval;
  final Duration heartbeatInterval;
  final Duration topUpInterval;
  final Duration turnTimeout;
  final Duration disconnectGrace;
  final Duration roundBreakDuration;

  final Map<String, RoomActor> _rooms = {};
  Map<String, RoomActor> get activeRooms => Map.unmodifiable(_rooms);

  DateTime? _startedAt;
  bool _running = false;
  bool _syncing = false;
  ScheduledTask? _syncTimer;
  ScheduledTask? _heartbeatTimer;
  ScheduledTask? _topUpTimer;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _startedAt = _nowUtc();

    await backend.resetAllBotLocks();
    await backend.refundHeldEscrows();
    await backend.upsertHeartbeat(
      workerId: workerId,
      activeRooms: 0,
      startedAt: _startedAt!,
    );

    await syncOnce();
    _armRecurringTasks();
  }

  void _armRecurringTasks() {
    if (!_running) return;
    _syncTimer = _schedule(syncInterval, () {
      _syncTimer = null;
      unawaited(() async {
        await syncOnce();
        if (_running && _syncTimer == null) {
          _syncTimer = _schedule(syncInterval, _onSyncTick);
        }
      }());
    });
    _heartbeatTimer = _schedule(heartbeatInterval, _onHeartbeatTick);
    _topUpTimer = _schedule(topUpInterval, _onTopUpTick);
  }

  void _onSyncTick() {
    _syncTimer = null;
    if (!_running) return;
    unawaited(() async {
      await syncOnce();
      if (_running) {
        _syncTimer = _schedule(syncInterval, _onSyncTick);
      }
    }());
  }

  void _onHeartbeatTick() {
    _heartbeatTimer = null;
    if (!_running) return;
    unawaited(() async {
      try {
        await backend.upsertHeartbeat(
          workerId: workerId,
          activeRooms: _rooms.length,
          startedAt: _startedAt ?? _nowUtc(),
        );
      } catch (_) {}
      if (_running) {
        _heartbeatTimer = _schedule(heartbeatInterval, _onHeartbeatTick);
      }
    }());
  }

  void _onTopUpTick() {
    _topUpTimer = null;
    if (!_running) return;
    unawaited(() async {
      try {
        await backend.topUpLowBankrollBots();
      } catch (_) {}
      if (_running) {
        _topUpTimer = _schedule(topUpInterval, _onTopUpTick);
      }
    }());
  }

  Future<void> syncOnce() async {
    if (!_running || _syncing) return;
    _syncing = true;
    try {
      final dbRooms = await backend.fetchActiveRooms();
      if (!_running) return;

      final activeIds = dbRooms.map((r) => r.id).toSet();

      for (final removedId
          in _rooms.keys.where((id) => !activeIds.contains(id)).toList()) {
        final actor = _rooms.remove(removedId);
        await actor?.closeRoom();
      }

      for (final dbRoom in dbRooms) {
        final existing = _rooms[dbRoom.id];
        if (existing != null) {
          if (existing.isClosed) {
            _rooms.remove(dbRoom.id);
          } else {
            await existing.syncWithDatabase(latestRoom: dbRoom);
            if (existing.isClosed) {
              _rooms.remove(dbRoom.id);
            }
          }
          continue;
        }

        final actor = RoomActor(
          room: dbRoom,
          backend: backend,
          transport: transportFactory.create(dbRoom.id),
          botRunner: botRunner,
          scheduleTask: _schedule,
          nowUtc: _nowUtc,
          random: _rng,
          turnTimeout: turnTimeout,
          disconnectGrace: disconnectGrace,
          roundBreakDuration: roundBreakDuration,
        );
        _rooms[dbRoom.id] = actor;
        await actor.start();
        if (actor.isClosed) {
          _rooms.remove(dbRoom.id);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _syncTimer?.cancel();
    _syncTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _topUpTimer?.cancel();
    _topUpTimer = null;

    for (final actor in _rooms.values.toList()) {
      await actor.closeRoom();
    }
    _rooms.clear();
    await transportFactory.dispose();
  }
}
