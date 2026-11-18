import 'dart:async';
import 'dart:math';

import 'package:teen_patti_core/teen_patti_core.dart';
import 'package:teen_patti_server/teen_patti_server.dart';
import 'package:test/test.dart';

class _FakeScheduledTask implements ScheduledTask {
  _FakeScheduledTask(this.id, this.fireAt, this.callback, this._onCancel);

  final int id;
  final DateTime fireAt;
  final void Function() callback;
  final void Function(int id) _onCancel;
  bool cancelled = false;

  @override
  void cancel() {
    if (!cancelled) {
      cancelled = true;
      _onCancel(id);
    }
  }
}

class _FakeClock {
  _FakeClock(this.now);

  DateTime now;
  int _nextId = 0;
  final Map<int, _FakeScheduledTask> _tasks = {};

  DateTime nowUtc() => now;

  ScheduledTask schedule(Duration delay, void Function() callback) {
    final safeDelay = delay.isNegative ? Duration.zero : delay;
    final id = ++_nextId;
    final task = _FakeScheduledTask(
      id,
      now.add(safeDelay),
      callback,
      _tasks.remove,
    );
    _tasks[id] = task;
    return task;
  }

  Future<void> advance(Duration duration) async {
    await _drainMicrotasks();
    final target = now.add(duration);
    while (true) {
      _FakeScheduledTask? next;
      for (final task in _tasks.values) {
        if (!task.cancelled && !task.fireAt.isAfter(target)) {
          if (next == null || task.fireAt.isBefore(next.fireAt)) {
            next = task;
          }
        }
      }
      if (next == null) break;
      _tasks.remove(next.id);
      now = next.fireAt;
      if (!next.cancelled) {
        next.callback();
        await _drainMicrotasks();
      }
    }
    now = target;
    await _drainMicrotasks();
  }

  Future<void> _drainMicrotasks() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class _FakeRoomTransport implements RoomTransport {
  final _actions = StreamController<RoomActionMessage>.broadcast();
  final _presence = StreamController<Set<String>>.broadcast();

  final List<SeatObservation> publicStates = [];
  final List<RoomChatBroadcast> publicChats = [];
  final List<({String profileId, List<PlayingCard> cards, int roundNumber})>
      privateCardEvents = [];
  bool disposed = false;

  @override
  Stream<RoomActionMessage> get actions => _actions.stream;

  @override
  Stream<Set<String>> get onlineUserIds => _presence.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> sendPublicState(SeatObservation publicState) async {
    publicStates.add(publicState);
  }

  @override
  Future<void> sendPublicChat(RoomChatBroadcast message) async {
    publicChats.add(message);
  }

  @override
  Future<void> sendPrivateSeatCards({
    required String profileId,
    required List<PlayingCard> cards,
    required int roundNumber,
  }) async {
    privateCardEvents.add((
      profileId: profileId,
      cards: cards,
      roundNumber: roundNumber,
    ));
  }

  void pushAction(RoomActionMessage message) {
    if (!disposed) _actions.add(message);
  }

  void pushPresence(Set<String> userIds) {
    if (!disposed) _presence.add(userIds);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _actions.close();
    await _presence.close();
  }
}

class _FakeTransportFactory implements RoomTransportFactory {
  final Map<String, _FakeRoomTransport> transportsByRoom = {};

  @override
  RoomTransport create(String roomId) {
    return transportsByRoom.putIfAbsent(roomId, _FakeRoomTransport.new);
  }

  @override
  Future<void> dispose() async {
    for (final t in transportsByRoom.values) {
      await t.dispose();
    }
  }
}

class _FakeServerBackend implements ServerBackendGateway {
  final Map<String, RoomRecord> rooms = {};
  final Map<String, List<SeatProfile>> roomSeats = {};
  final Map<String, int> chipsByProfile = {};
  final List<ClaimedBot> availableBots = [];
  final Set<String> claimedBotIds = {};
  final List<String> releasedBotIds = [];
  final List<Map<String, int>> heldEscrows = [];
  final List<List<SettlementSeatDelta>> settlements = [];

  int resetLocksCalls = 0;
  int refundedEscrows = 2;
  int heartbeatCount = 0;
  int topUpCalls = 0;

  @override
  Future<void> resetAllBotLocks() async {
    resetLocksCalls++;
    claimedBotIds.clear();
  }

  @override
  Future<int> refundHeldEscrows() async => refundedEscrows;

  @override
  Future<void> upsertHeartbeat({
    required String workerId,
    required int activeRooms,
    required DateTime startedAt,
  }) async {
    heartbeatCount++;
  }

  @override
  Future<List<RoomRecord>> fetchActiveRooms() async {
    return rooms.values.where((r) => r.status != 'closed').toList();
  }

  @override
  Future<List<SeatProfile>> fetchRoomPlayers(String roomId) async {
    final seats = roomSeats[roomId] ?? const [];
    return seats
        .map(
          (s) => SeatProfile(
            profileId: s.profileId,
            seatIndex: s.seatIndex,
            displayName: s.displayName,
            avatarAsset: s.avatarAsset,
            chips: chipsByProfile[s.profileId] ?? s.chips,
            rating: s.rating,
            isBot: s.isBot,
          ),
        )
        .toList();
  }

  @override
  Future<void> updateRoomStatus(String roomId, String status) async {
    final existing = rooms[roomId];
    if (existing != null) {
      rooms[roomId] = RoomRecord(
        id: existing.id,
        roomCode: existing.roomCode,
        tableName: existing.tableName,
        variant: existing.variant,
        minStake: existing.minStake,
        maxStake: existing.maxStake,
        maxPlayers: existing.maxPlayers,
        isPrivate: existing.isPrivate,
        fillWithAi: existing.fillWithAi,
        hostProfileId: existing.hostProfileId,
        status: status,
        createdAt: existing.createdAt,
      );
    }
  }

  @override
  Future<void> insertRoomPlayer({
    required String roomId,
    required String profileId,
    required int seatIndex,
  }) async {
    final seats = roomSeats.putIfAbsent(roomId, () => []);
    if (seats.any((s) => s.profileId == profileId)) return;
    final bot = availableBots
        .where((b) => b.profileId == profileId)
        .firstOrNull;
    seats.add(
      SeatProfile(
        profileId: profileId,
        seatIndex: seatIndex,
        displayName: bot?.displayName ?? profileId,
        avatarAsset: bot?.avatarAsset ?? 'assets/images/online_avatar_1.png',
        chips: chipsByProfile[profileId] ?? bot?.chips ?? 25000,
        rating: bot?.rating ?? 1000,
        isBot: bot != null,
      ),
    );
  }

  @override
  Future<void> removeRoomPlayer({
    required String roomId,
    required String profileId,
  }) async {
    roomSeats[roomId]?.removeWhere((s) => s.profileId == profileId);
  }

  @override
  Future<List<ClaimedBot>> claimBots({
    required String roomId,
    required int count,
    required int minChips,
  }) async {
    final picked = <ClaimedBot>[];
    for (final bot in availableBots) {
      if (picked.length >= count) break;
      final balance = chipsByProfile[bot.profileId] ?? bot.chips;
      if (!claimedBotIds.contains(bot.profileId) && balance >= minChips) {
        claimedBotIds.add(bot.profileId);
        picked.add(bot);
      }
    }
    return picked;
  }

  @override
  Future<void> releaseBot(
    String profileId, {
    int cooldownMinSec = 60,
    int cooldownMaxSec = 300,
  }) async {
    claimedBotIds.remove(profileId);
    releasedBotIds.add(profileId);
  }

  @override
  Future<void> holdRoundEscrows({
    required String roomId,
    required int roundNumber,
    required Map<String, int> bootsByProfileId,
    required String tableName,
  }) async {
    heldEscrows.add(bootsByProfileId);
    for (final entry in bootsByProfileId.entries) {
      chipsByProfile[entry.key] =
          (chipsByProfile[entry.key] ?? 25000) - entry.value;
    }
  }

  @override
  Future<void> settleRound({
    required String roomId,
    required int roundNumber,
    required List<SettlementSeatDelta> seats,
    required bool hasHumanParticipant,
  }) async {
    settlements.add(seats);
    for (final s in seats) {
      chipsByProfile[s.profileId] =
          (chipsByProfile[s.profileId] ?? 25000) +
          s.settlementDeltaFromPostBoot;
    }
  }

  @override
  Future<int> topUpLowBankrollBots() async {
    topUpCalls++;
    return 0;
  }
}

void main() {
  ClaimedBot makeBot(String id, String name) => ClaimedBot(
        profileId: id,
        displayName: name,
        avatarAsset: 'assets/images/online_avatar_1.png',
        chips: 30000,
        rating: 1120,
        archetype: 'balanced',
        params: BotProfileParams.balanced,
        thinkMeanMs: 1200,
        thinkSigma: 0.2,
      );

  RoomRecord makeRoom({
    String id = 'room-1',
    bool isPrivate = false,
    bool fillWithAi = true,
    int maxPlayers = 5,
  }) =>
      RoomRecord(
        id: id,
        tableName: 'Royal Table',
        variant: 'Classic',
        minStake: 100,
        maxStake: 3200,
        maxPlayers: maxPlayers,
        isPrivate: isPrivate,
        fillWithAi: fillWithAi,
        hostProfileId: 'human-1',
        status: 'waiting',
        createdAt: DateTime.utc(2026, 11, 15, 10, 0),
      );

  SeatProfile makeHuman(String id, int seatIndex, {int chips = 25000}) =>
      SeatProfile(
        profileId: id,
        seatIndex: seatIndex,
        displayName: 'Player $id',
        avatarAsset: 'assets/images/avatar_2.png',
        chips: chips,
        rating: 1050,
        isBot: false,
      );

  group('Phase 4 Authoritative Worker & Matchmaking', () {
    test(
      'staggers Bot #1 at 8-12s and Bot #2 at +4-8s then deals 3-handed without leaking cards',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 15, 10, 0));
        final backend = _FakeServerBackend()
          ..availableBots.addAll([
            makeBot('bot-1', 'Vikram S'),
            makeBot('bot-2', 'Priya M'),
          ])
          ..rooms['room-1'] = makeRoom()
          ..roomSeats['room-1'] = [makeHuman('human-1', 0)]
          ..chipsByProfile['human-1'] = 25000;

        final factory = _FakeTransportFactory();
        final actor = RoomActor(
          room: backend.rooms['room-1']!,
          backend: backend,
          transport: factory.create('room-1'),
          botRunner: HumanizedBotRunner(
            random: Random(7),
            disableRandomFaults: true,
          ),
          scheduleTask: clock.schedule,
          nowUtc: clock.nowUtc,
          random: Random(7),
        );

        await actor.start();
        final transport = factory.transportsByRoom['room-1']!;
        transport.pushPresence({'human-1'});

        // Before 8 seconds: still waiting with 0 bots.
        await clock.advance(const Duration(milliseconds: 7900));
        expect(actor.botCount, 0);
        expect(actor.tableState, isNull);

        // Within 8-12s window: Bot #1 joins (still 2 seats -> waits for #2).
        await clock.advance(const Duration(milliseconds: 4200));
        expect(actor.botCount, 1);
        expect(actor.tableState, isNull);

        // Within +4-8s window: Bot #2 joins -> 3 seats -> deals Hand #1!
        await clock.advance(const Duration(milliseconds: 8100));
        expect(actor.botCount, 2);
        expect(actor.totalSeatCount, 3);
        expect(actor.tableState, isNotNull);
        expect(actor.tableState!.roundNumber, 1);
        expect(backend.rooms['room-1']!.status, 'playing');
        expect(backend.heldEscrows, hasLength(1));

        final latestPublic = transport.publicStates.last.toPublicJson();
        expect(latestPublic.containsKey('myCards'), isFalse);
        expect((latestPublic['seats'] as List).length, 3);
      },
    );

    test(
      'cancels pending bot timer when real humans fill the table first',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 15, 10, 0));
        final backend = _FakeServerBackend()
          ..availableBots.addAll([
            makeBot('bot-1', 'Vikram S'),
            makeBot('bot-2', 'Priya M'),
          ])
          ..rooms['room-1'] = makeRoom()
          ..roomSeats['room-1'] = [makeHuman('human-1', 0)]
          ..chipsByProfile['human-1'] = 25000;

        final factory = _FakeTransportFactory();
        final actor = RoomActor(
          room: backend.rooms['room-1']!,
          backend: backend,
          transport: factory.create('room-1'),
          botRunner: HumanizedBotRunner(
            random: Random(11),
            disableRandomFaults: true,
          ),
          scheduleTask: clock.schedule,
          nowUtc: clock.nowUtc,
          random: Random(11),
        );

        await actor.start();
        factory.transportsByRoom['room-1']!.pushPresence({'human-1'});

        await clock.advance(const Duration(seconds: 4));
        backend.roomSeats['room-1']!.addAll([
          makeHuman('human-2', 1),
          makeHuman('human-3', 2),
        ]);
        backend.chipsByProfile['human-2'] = 25000;
        backend.chipsByProfile['human-3'] = 25000;

        await actor.syncWithDatabase();
        factory.transportsByRoom['room-1']!
            .pushPresence({'human-1', 'human-2', 'human-3'});

        await clock.advance(const Duration(seconds: 20));
        expect(actor.botCount, 0);
        expect(backend.claimedBotIds, isEmpty);
        expect(actor.tableState?.roundNumber, 1);
        expect(actor.tableState?.players.length, 3);
      },
    );

    test(
      'swaps out a bot after current hand finishes when another human arrives',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 15, 10, 0));
        final backend = _FakeServerBackend()
          ..availableBots.addAll([
            makeBot('bot-1', 'Vikram S'),
            makeBot('bot-2', 'Priya M'),
          ])
          ..rooms['room-1'] = makeRoom()
          ..roomSeats['room-1'] = [makeHuman('human-1', 0)]
          ..chipsByProfile['human-1'] = 25000;

        final factory = _FakeTransportFactory();
        final actor = RoomActor(
          room: backend.rooms['room-1']!,
          backend: backend,
          transport: factory.create('room-1'),
          botRunner: HumanizedBotRunner(
            random: Random(3),
            disableRandomFaults: true,
          ),
          scheduleTask: clock.schedule,
          nowUtc: clock.nowUtc,
          random: Random(3),
        );

        await actor.start();
        final transport = factory.transportsByRoom['room-1']!;
        transport.pushPresence({'human-1'});

        // Deal 3-handed (human-1 + bot-1 + bot-2).
        await clock.advance(const Duration(seconds: 21));
        expect(actor.botCount, 2);
        expect(actor.tableState?.isRoundOver, isFalse);

        // Second human arrives mid-hand; bots finish hand, then one swaps out!
        backend.roomSeats['room-1']!.add(makeHuman('human-2', 3));
        backend.chipsByProfile['human-2'] = 25000;
        await actor.syncWithDatabase();
        transport.pushPresence({'human-1', 'human-2'});

        // Complete the hand by letting turns time out or fold humans if active.
        var safety = 0;
        while ((actor.tableState != null && !actor.tableState!.isRoundOver) &&
            safety < 30) {
          safety++;
          final active = actor.tableState!.activeTurnPlayer;
          if (active != null && active.id == 'human-1') {
            transport.pushAction(
              const RoomActionMessage(playerId: 'human-1', action: 'pack'),
            );
            await clock.advance(const Duration(milliseconds: 50));
          } else {
            await clock.advance(const Duration(seconds: 5));
          }
        }

        // After round ends and round break completes, swapped bot is released.
        await clock.advance(const Duration(seconds: 6));
        expect(backend.releasedBotIds, isNotEmpty);
        expect(actor.botCount, lessThanOrEqualTo(1));
      },
    );

    test(
      'enforces 25s Presence disconnect grace while allowing immediate explicit leave',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 15, 10, 0));
        final backend = _FakeServerBackend()
          ..rooms['room-1'] = makeRoom(isPrivate: true, fillWithAi: false)
          ..roomSeats['room-1'] = [
            makeHuman('human-1', 0),
            makeHuman('human-2', 1),
          ]
          ..chipsByProfile['human-1'] = 25000
          ..chipsByProfile['human-2'] = 25000;

        final factory = _FakeTransportFactory();
        final actor = RoomActor(
          room: backend.rooms['room-1']!,
          backend: backend,
          transport: factory.create('room-1'),
          botRunner: HumanizedBotRunner(disableRandomFaults: true),
          scheduleTask: clock.schedule,
          nowUtc: clock.nowUtc,
          random: Random(5),
        );

        await actor.start();
        final transport = factory.transportsByRoom['room-1']!;
        transport.pushPresence({'human-1', 'human-2'});
        await clock.advance(const Duration(milliseconds: 100));
        expect(actor.tableState?.roundNumber, 1);

        // Brief disconnect for human-1 (20s < 25s grace): reconnect saves seat!
        transport.pushPresence({'human-2'});
        await clock.advance(const Duration(seconds: 20));
        expect(actor.humanCount, 2);
        expect(actor.isClosed, isFalse);

        transport.pushPresence({'human-1', 'human-2'});
        await clock.advance(const Duration(seconds: 10));
        expect(actor.humanCount, 2);

        // Sustained disconnect (>25s): auto-packs human-1 and removes seat!
        transport.pushPresence({'human-2'});
        await clock.advance(const Duration(seconds: 26));
        expect(actor.humanCount, 1);
        expect(actor.tableState?.isRoundOver, isTrue);

        // Explicit leave by last human immediately closes the room at +0s.
        transport.pushAction(
          const RoomActionMessage(playerId: 'human-2', action: 'leave'),
        );
        await clock.advance(const Duration(milliseconds: 20));
        expect(actor.isClosed, isTrue);
        expect(backend.rooms['room-1']!.status, 'closed');
      },
    );

    test(
      'auto-packs idle player when 25s turnDeadline expires',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 15, 10, 0));
        final backend = _FakeServerBackend()
          ..rooms['room-1'] = makeRoom(isPrivate: true, fillWithAi: false)
          ..roomSeats['room-1'] = [
            makeHuman('human-1', 0),
            makeHuman('human-2', 1),
          ]
          ..chipsByProfile['human-1'] = 25000
          ..chipsByProfile['human-2'] = 25000;

        final factory = _FakeTransportFactory();
        final actor = RoomActor(
          room: backend.rooms['room-1']!,
          backend: backend,
          transport: factory.create('room-1'),
          botRunner: HumanizedBotRunner(disableRandomFaults: true),
          scheduleTask: clock.schedule,
          nowUtc: clock.nowUtc,
          random: Random(9),
        );

        await actor.start();
        final transport = factory.transportsByRoom['room-1']!;
        transport.pushPresence({'human-1', 'human-2'});
        await clock.advance(const Duration(milliseconds: 50));

        final activeId = actor.tableState!.activeTurnPlayer!.id;
        await clock.advance(const Duration(seconds: 25, milliseconds: 50));

        expect(actor.tableState!.isRoundOver, isTrue);
        expect(actor.tableState!.findPlayerById(activeId)!.hasPacked, isTrue);
      },
    );

    test(
      'never claims bots in Private Room with fillWithAi=false',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 15, 10, 0));
        final backend = _FakeServerBackend()
          ..availableBots.addAll([
            makeBot('bot-1', 'Vikram S'),
            makeBot('bot-2', 'Priya M'),
          ])
          ..rooms['room-1'] = makeRoom(isPrivate: true, fillWithAi: false)
          ..roomSeats['room-1'] = [makeHuman('human-1', 0)]
          ..chipsByProfile['human-1'] = 25000;

        final factory = _FakeTransportFactory();
        final actor = RoomActor(
          room: backend.rooms['room-1']!,
          backend: backend,
          transport: factory.create('room-1'),
          botRunner: HumanizedBotRunner(disableRandomFaults: true),
          scheduleTask: clock.schedule,
          nowUtc: clock.nowUtc,
          random: Random(1),
        );

        await actor.start();
        final transport = factory.transportsByRoom['room-1']!;
        transport.pushPresence({'human-1'});

        await clock.advance(const Duration(seconds: 60));
        expect(actor.botCount, 0);
        expect(backend.claimedBotIds, isEmpty);
        expect(actor.tableState, isNull);

        // Once friend joins, deals 2-handed immediately.
        backend.roomSeats['room-1']!.add(makeHuman('human-2', 1));
        backend.chipsByProfile['human-2'] = 25000;
        await actor.syncWithDatabase();
        transport.pushPresence({'human-1', 'human-2'});
        await clock.advance(const Duration(milliseconds: 50));

        expect(actor.tableState?.roundNumber, 1);
        expect(actor.botCount, 0);
      },
    );

    test(
      'WorkerCoordinator resets bot locks, refunds escrows on startup, and runs top-ups',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 15, 10, 0));
        final backend = _FakeServerBackend();
        final factory = _FakeTransportFactory();

        final coordinator = WorkerCoordinator(
          backend: backend,
          transportFactory: factory,
          scheduleTask: clock.schedule,
          nowUtc: clock.nowUtc,
          random: Random(42),
        );

        await coordinator.start();
        expect(backend.resetLocksCalls, 1);
        expect(backend.heartbeatCount, 1);

        await clock.advance(const Duration(seconds: 31));
        expect(backend.heartbeatCount, 2);

        await clock.advance(const Duration(minutes: 10));
        expect(backend.topUpCalls, greaterThanOrEqualTo(1));

        await coordinator.stop();
      },
    );

    test(
      'RoomActor relays rate-limited human chat and emoji reactions and schedules occasional bot replies',
      () async {
        final clock = _FakeClock(DateTime.utc(2026, 11, 15, 10, 0));
        final backend = _FakeServerBackend()
          ..availableBots.add(makeBot('bot-1', 'Vikram S'))
          ..rooms['room-1'] = makeRoom(fillWithAi: true)
          ..roomSeats['room-1'] = [makeHuman('human-1', 0)]
          ..chipsByProfile['human-1'] = 25000;

        final factory = _FakeTransportFactory();
        final actor = RoomActor(
          room: backend.rooms['room-1']!,
          backend: backend,
          transport: factory.create('room-1'),
          botRunner: HumanizedBotRunner(disableRandomFaults: true),
          scheduleTask: clock.schedule,
          nowUtc: clock.nowUtc,
          random: Random(7),
          botChatReplyProbability: 1.0,
        );

        await actor.start();
        final transport = factory.transportsByRoom['room-1']!;
        transport.pushPresence({'human-1'});

        // Advance 12s so bot-1 joins seat.
        await clock.advance(const Duration(seconds: 12));
        expect(actor.botCount, 1);

        // Human sends a quick reaction and a spam follow-up within 100ms.
        transport.pushAction(
          const RoomActionMessage(
            playerId: 'human-1',
            action: 'reaction',
            text: '🔥',
            isQuickReaction: true,
          ),
        );
        transport.pushAction(
          const RoomActionMessage(
            playerId: 'human-1',
            action: 'chat',
            text: 'Spam within cooldown should be dropped',
          ),
        );
        await clock.advance(const Duration(milliseconds: 100));

        expect(transport.publicChats.length, 1);
        expect(transport.publicChats.first.senderId, 'human-1');
        expect(transport.publicChats.first.text, '🔥');
        expect(transport.publicChats.first.isQuickReaction, isTrue);

        // Advance 2.5s so bot reply fires and cooldown clears.
        await clock.advance(const Duration(milliseconds: 2500));
        expect(transport.publicChats.length, 2);
        expect(transport.publicChats.last.senderId, 'bot-1');
        expect(transport.publicChats.last.senderName, 'Vikram S');

        // After cooldown, human text chat is relayed cleanly.
        transport.pushAction(
          const RoomActionMessage(
            playerId: 'human-1',
            action: 'chat',
            text: 'Well played!',
          ),
        );
        await clock.advance(const Duration(milliseconds: 100));
        expect(transport.publicChats.length, 3);
        expect(transport.publicChats.last.text, 'Well played!');
        expect(transport.publicChats.last.isQuickReaction, isFalse);

        await actor.closeRoom();
      },
    );
  });
}
