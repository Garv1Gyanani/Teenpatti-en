import 'dart:math';

import '../../../../core/models/game_user.dart';
import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/game_table_config.dart';
import '../../domain/entities/table_player.dart';
import '../../domain/entities/table_state.dart';
import '../../domain/repositories/game_table_repository.dart';
import '../../domain/services/table_player_agent.dart';
import '../../domain/services/teen_patti_engine.dart';
import '../agents/offline_teen_patti_bot.dart';

/// [GameTableRepository] running real Teen Patti rules against automated agents.
///
/// Offline tables run [OfflineTeenPattiBot] instances, while future online AI
/// agents using the same [GameUser] model can plug into [agentsByPlayerId] via
/// [TablePlayerAgent].
class GameTableRepositoryImpl implements GameTableRepository {
  GameTableRepositoryImpl({
    Random? random,
    TeenPattiEngine? engine,
    TablePlayerAgent? defaultBotAgent,
    Map<String, TablePlayerAgent>? agentsByPlayerId,
    List<GameUser>? initialUsers,
    GameTableConfig? config,
    AppSessionStore? sessionStore,
    String? tableName,
    int? minStake,
    int? maxStake,
    int? initialDealerIndex,
    bool? isPractice,
  })  : _engine = engine ?? TeenPattiEngine(random: random),
        _agentsByPlayerId = agentsByPlayerId ?? const {},
        _sessionStore = sessionStore,
        isPracticeMode = isPractice ?? (config?.usesPracticeWallet ?? false),
        tableName = tableName ?? config?.tableName ?? 'Teen Patti',
        minStake = minStake ?? config?.minStake ?? 100,
        maxStake = maxStake ?? config?.maxStake ?? 3200,
        variant = config?.variant ?? 'Classic' {
    final resolvedUsers = initialUsers ??
        _buildConfiguredSeats(
          config: config,
          sessionStore: sessionStore,
          resolvedMinStake: this.minStake,
          isPractice: isPracticeMode,
        );
    _initialUsers = resolvedUsers;
    this.initialDealerIndex = initialDealerIndex ?? (resolvedUsers.length - 1);
    _defaultBotAgent =
        defaultBotAgent ?? OfflineTeenPattiBot(engine: _engine, random: random);
  }

  static const GameUser _defaultLocalUser = GameUser(
    id: 'local',
    name: 'Garv',
    chips: 25000,
    avatarAsset: 'assets/images/splash_character.png',
    kind: ParticipantKind.human,
  );

  static const List<GameUser> _defaultBots = [
    GameUser(
      id: 'bot_rohit',
      name: 'Rohit',
      chips: 18500,
      avatarAsset: 'assets/images/avatar_2.png',
      kind: ParticipantKind.clientBot,
      personaTag: 'aggressive',
    ),
    GameUser(
      id: 'bot_sneha',
      name: 'Sneha',
      chips: 22400,
      avatarAsset: 'assets/images/avatar_3.png',
      kind: ParticipantKind.clientBot,
      personaTag: 'balanced',
    ),
    GameUser(
      id: 'bot_aryan',
      name: 'Aryan',
      chips: 31200,
      avatarAsset: 'assets/images/avatar_4.png',
      kind: ParticipantKind.clientBot,
      personaTag: 'tight',
    ),
    GameUser(
      id: 'bot_meera',
      name: 'Meera',
      chips: 15800,
      avatarAsset: 'assets/images/avatar_5.png',
      kind: ParticipantKind.clientBot,
      personaTag: 'bluffer',
    ),
    GameUser(
      id: 'bot_kabir',
      name: 'Kabir',
      chips: 19600,
      avatarAsset: 'assets/images/avatar_2.png',
      kind: ParticipantKind.clientBot,
      personaTag: 'balanced',
    ),
    GameUser(
      id: 'bot_ananya',
      name: 'Ananya',
      chips: 27000,
      avatarAsset: 'assets/images/avatar_3.png',
      kind: ParticipantKind.clientBot,
      personaTag: 'aggressive',
    ),
  ];

  static List<GameUser> _buildConfiguredSeats({
    required GameTableConfig? config,
    required AppSessionStore? sessionStore,
    required int resolvedMinStake,
    bool isPractice = false,
  }) {
    final targetSeats = (config?.maxPlayers ?? 7).clamp(2, 7);
    final localUser =
        sessionStore?.toLocalGameUser(isPractice: isPractice) ??
            _defaultLocalUser;
    final opponentsNeeded = targetSeats - 1;
    final minBotStack = max(15000, resolvedMinStake * 80);

    final opponents = <GameUser>[];
    final takenNames = <String>{localUser.name.toLowerCase()};

    final custom = config?.customOpponents;
    if (custom != null) {
      for (final friend in custom) {
        if (opponents.length >= opponentsNeeded) break;
        opponents.add(
          friend.copyWith(chips: max(friend.chips, minBotStack)),
        );
        takenNames.add(friend.name.toLowerCase());
      }
    }

    for (final bot in _defaultBots) {
      if (opponents.length >= opponentsNeeded) break;
      if (takenNames.contains(bot.name.toLowerCase())) continue;
      opponents.add(bot.copyWith(chips: max(bot.chips, minBotStack)));
      takenNames.add(bot.name.toLowerCase());
    }

    return [localUser, ...opponents];
  }

  final TeenPattiEngine _engine;
  final Map<String, TablePlayerAgent> _agentsByPlayerId;
  final AppSessionStore? _sessionStore;
  late final List<GameUser> _initialUsers;
  late final TablePlayerAgent _defaultBotAgent;

  final bool isPracticeMode;
  final String tableName;
  final int minStake;
  final int maxStake;
  final String variant;
  late final int initialDealerIndex;

  int _lastRecordedRoundNumber = 0;

  AppSessionStore? get sessionStore => _sessionStore;

  TeenPattiVariant get parsedVariant => TeenPattiVariant.fromLabel(variant);

  TablePlayerAgent _agentFor(TablePlayer player) {
    return _agentsByPlayerId[player.id] ?? _defaultBotAgent;
  }

  @override
  Future<TableState> getInitialTableState() async {
    _lastRecordedRoundNumber = 0;
    final store = _sessionStore;
    final seats = _initialUsers.map((user) {
      final syncedUser = (user.id == 'local' && store != null)
          ? store.toLocalGameUser(isPractice: isPracticeMode)
          : user;
      return TablePlayer.fromUser(
        syncedUser,
        isLocalPlayer: syncedUser.id == 'local',
        hasGiftBadge: syncedUser.id == 'bot_kabir',
      );
    }).toList(growable: false);

    return _engine.startNewRound(
      tableName: tableName,
      minStake: minStake,
      maxStake: maxStake,
      players: seats,
      roundNumber: 1,
      dealerIndex: initialDealerIndex,
      variant: parsedVariant,
    );
  }

  @override
  Future<TableState> dealNewHand({
    required TableState currentState,
  }) async {
    final store = _sessionStore;
    final minBotRefill = max(10000, currentState.minStake * 40);
    final refreshedPlayers = currentState.players.map((p) {
      if (p.isLocalPlayer && store != null) {
        return p.copyWith(
          name: store.displayName,
          avatarAsset: store.avatarAsset,
          chips: isPracticeMode ? store.practiceChips : store.chips,
        );
      }
      if (!p.isLocalPlayer && p.chips < currentState.minStake * 4) {
        return p.copyWith(chips: minBotRefill);
      }
      return p;
    }).toList(growable: false);

    return _engine.startNewRound(
      tableName: currentState.tableName,
      minStake: currentState.minStake,
      maxStake: currentState.maxStake,
      players: refreshedPlayers,
      roundNumber: currentState.roundNumber + 1,
      dealerIndex: (currentState.dealerIndex + 1) % refreshedPlayers.length,
      variant: currentState.variant,
      maxBlindTurns: currentState.maxBlindTurns,
      potLimit: currentState.potLimit,
    );
  }

  @override
  Future<TableState> seeCards({
    required TableState currentState,
    required String playerId,
  }) async {
    return _engine.seeCards(currentState, playerId: playerId);
  }

  @override
  Future<TableState> performAction({
    required TableState currentState,
    required PlayerTableAction action,
    String? playerId,
    bool raiseStake = false,
  }) async {
    final actorId = playerId ?? currentState.localPlayer.id;
    var nextState = _engine.applyAction(
      currentState,
      playerId: actorId,
      action: action,
      raiseStake: raiseStake,
    );

    if (nextState.pendingSideShow != null) {
      nextState = await _resolveAutomatedSideShowIfNeeded(nextState);
    }
    await _recordRoundIfComplete(nextState);
    return nextState;
  }

  @override
  Future<TableState> resolveSideShow({
    required TableState currentState,
    required bool accepted,
  }) async {
    final nextState = _engine.resolveSideShow(currentState, accepted: accepted);
    await _recordRoundIfComplete(nextState);
    return nextState;
  }

  @override
  Future<TableState> performAutomatedTurn({
    required TableState currentState,
  }) async {
    if (currentState.isRoundOver || currentState.pendingSideShow != null) {
      return currentState;
    }

    final active = currentState.activeTurnPlayer;
    if (active == null || active.isLocalPlayer) {
      return currentState;
    }

    var workingState = currentState;
    var actor = active;
    final agent = _agentFor(actor);

    if (!actor.hasSeenCards) {
      final wantsToSee = await agent.shouldSeeCards(
        state: workingState,
        self: actor,
      );
      if (wantsToSee) {
        workingState = _engine.seeCards(workingState, playerId: actor.id);
        actor = workingState.findPlayerById(actor.id)!;
      }
    }

    final decision = await agent.decideAction(
      state: workingState,
      self: actor,
    );

    workingState = _engine.applyAction(
      workingState,
      playerId: actor.id,
      action: decision.action,
      raiseStake: decision.raiseStake,
    );

    if (workingState.pendingSideShow != null) {
      workingState = await _resolveAutomatedSideShowIfNeeded(workingState);
    }

    await _recordRoundIfComplete(workingState);
    return workingState;
  }

  Future<TableState> _resolveAutomatedSideShowIfNeeded(TableState state) async {
    final pending = state.pendingSideShow;
    if (pending == null) return state;

    final target = state.findPlayerById(pending.targetId);
    final requester = state.findPlayerById(pending.requesterId);
    if (target == null || requester == null || target.isLocalPlayer) {
      return state;
    }

    final accepted = await _agentFor(target).decideSideShowResponse(
      state: state,
      self: target,
      requester: requester,
    );

    return _engine.resolveSideShow(state, accepted: accepted);
  }

  Future<void> _recordRoundIfComplete(TableState state) async {
    final result = state.roundResult;
    final store = _sessionStore;
    if (result == null || store == null) return;
    if (_lastRecordedRoundNumber == state.roundNumber) return;

    _lastRecordedRoundNumber = state.roundNumber;
    final localSeat = state.localPlayer;
    await store.recordCompletedRound(
      tableName: state.tableName,
      variant: variant,
      bootAmount: state.minStake,
      roundNumber: state.roundNumber,
      previousBalance: result.previousBalance,
      newBalance: result.newBalance,
      potAmount: result.wonAmount,
      localTotalBet: localSeat.totalBet,
      isLocalWinner: result.isLocalWinner,
      handLabel: result.handLabel,
      winReason: result.winReason,
      isPractice: isPracticeMode,
    );
  }
}
