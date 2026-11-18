import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/session/app_session_store.dart';
import '../../data/repositories/game_table_repository_impl.dart';
import '../../data/repositories/online_game_table_repository.dart';
import '../../domain/entities/table_chat_message.dart';
import '../../domain/entities/table_hand_history.dart';
import '../../domain/entities/table_state.dart';
import '../../domain/repositories/game_table_repository.dart';
import '../../domain/services/teen_patti_engine.dart';
import '../../domain/services/teen_patti_hand_evaluator.dart';
import '../../domain/usecases/advance_ai_turn_usecase.dart';
import '../../domain/usecases/deal_new_hand_usecase.dart';
import '../../domain/usecases/get_table_state_usecase.dart';
import '../../domain/usecases/perform_player_action_usecase.dart';
import '../../domain/usecases/resolve_side_show_usecase.dart';
import '../../domain/usecases/see_cards_usecase.dart';

/// Coordinates Teen Patti table turns, 2x stake raises, turn timer auto-pack,
/// low-chip bailouts, hand history, table chat/reactions, and AI/online sync.
class GameTableController extends ChangeNotifier {
  GameTableController({
    required GetTableStateUseCase getTableStateUseCase,
    required PerformPlayerActionUseCase performPlayerActionUseCase,
    DealNewHandUseCase? dealNewHandUseCase,
    SeeCardsUseCase? seeCardsUseCase,
    AdvanceAiTurnUseCase? advanceAiTurnUseCase,
    ResolveSideShowUseCase? resolveSideShowUseCase,
    AppSessionStore? sessionStore,
    OnlineGameTableRepository? onlineRepository,
    bool isPracticeMode = false,
    int configuredMinStake = 100,
    Duration botTurnDelay = const Duration(milliseconds: 650),
    Duration? turnTimeout = const Duration(seconds: 15),
  })  : _getTableStateUseCase = getTableStateUseCase,
        _performPlayerActionUseCase = performPlayerActionUseCase,
        _dealNewHandUseCase = dealNewHandUseCase,
        _seeCardsUseCase = seeCardsUseCase,
        _advanceAiTurnUseCase = advanceAiTurnUseCase,
        _resolveSideShowUseCase = resolveSideShowUseCase,
        _sessionStore = sessionStore,
        _onlineRepository = onlineRepository,
        _isOnlineMode = onlineRepository != null,
        _isPracticeMode = isPracticeMode,
        _configuredMinStake = configuredMinStake,
        _botTurnDelay = botTurnDelay,
        _turnTimeout = turnTimeout;

  /// Convenience constructor wiring all use cases to a shared [repository].
  factory GameTableController.forRepository({
    required GameTableRepository repository,
    AppSessionStore? sessionStore,
    bool? isPracticeMode,
    Duration botTurnDelay = const Duration(milliseconds: 650),
    Duration? turnTimeout = const Duration(seconds: 15),
  }) {
    final impl = repository is GameTableRepositoryImpl ? repository : null;
    final onlineRepo =
        repository is OnlineGameTableRepository ? repository : null;
    return GameTableController(
      getTableStateUseCase: GetTableStateUseCase(repository: repository),
      performPlayerActionUseCase: PerformPlayerActionUseCase(
        repository: repository,
      ),
      dealNewHandUseCase: DealNewHandUseCase(repository: repository),
      seeCardsUseCase: SeeCardsUseCase(repository: repository),
      advanceAiTurnUseCase: AdvanceAiTurnUseCase(repository: repository),
      resolveSideShowUseCase: ResolveSideShowUseCase(repository: repository),
      sessionStore: sessionStore ?? impl?.sessionStore ?? onlineRepo?.sessionStore,
      onlineRepository: onlineRepo,
      isPracticeMode: isPracticeMode ?? impl?.isPracticeMode ?? false,
      configuredMinStake:
          impl?.minStake ?? onlineRepo?.config.minStake ?? 100,
      botTurnDelay: botTurnDelay,
      turnTimeout: onlineRepo != null ? const Duration(seconds: 25) : turnTimeout,
    );
  }

  static const List<String> quickEmojis = ['👏', '🔥', '😎', '😂', '🙏', '💎'];

  static const List<String> quickPhrases = [
    'Well played!',
    'Good luck!',
    'Raising stakes!',
    'Show your cards!',
    'Nice bluff!',
    'One more hand!',
  ];

  static const List<String> _botReplyPool = [
    'Good luck! 🍀',
    'Well played! 👏',
    'Let\'s raise it! 🔥',
    'Nice hand! 😎',
    'See you at Showdown!',
  ];

  final GetTableStateUseCase _getTableStateUseCase;
  final PerformPlayerActionUseCase _performPlayerActionUseCase;
  final DealNewHandUseCase? _dealNewHandUseCase;
  final SeeCardsUseCase? _seeCardsUseCase;
  final AdvanceAiTurnUseCase? _advanceAiTurnUseCase;
  final ResolveSideShowUseCase? _resolveSideShowUseCase;
  final AppSessionStore? _sessionStore;
  final OnlineGameTableRepository? _onlineRepository;
  final bool _isOnlineMode;
  final bool _isPracticeMode;
  final int _configuredMinStake;
  final Duration _botTurnDelay;
  final Duration? _turnTimeout;
  final TeenPattiEngine _rulesHelper = TeenPattiEngine();
  final Random _chatRng = Random();

  StreamSubscription<TableState>? _onlineSub;
  StreamSubscription<TableChatMessage>? _onlineChatSub;
  Timer? _botTurnTimer;
  Timer? _localTurnTimer;
  Timer? _botChatTimer;
  DateTime? _lastOnlineChatAt;
  final Map<String, Timer> _reactionTimers = {};

  TableState? _state;
  bool _isLoading = false;
  bool _isActing = false;
  bool _isRaiseSelected = false;
  bool _isTurnTimerPaused = false;
  bool _needsLowChipBailout = false;
  int _turnTimerGeneration = 0;
  int _lastHistoryRound = 0;
  String? _lastActionFeedback;
  String? _onlineStatusError;
  bool _disposed = false;

  final List<TableHandHistoryEntry> _handHistory = [];
  final List<TableChatMessage> _chatMessages = [];
  final Map<String, String> _activeSeatReactions = {};

  TableState? get state => _state;
  bool get isLoading => _isLoading;
  bool get isActing => _isActing;
  String? get lastActionFeedback => _lastActionFeedback;
  String? get onlineStatusError => _onlineStatusError;
  bool get isOnlineMode => _isOnlineMode;
  String? get onlineRoomCode => _onlineRepository?.roomCode;
  bool get isWaitingForOpponents =>
      _isOnlineMode &&
      !_needsLowChipBailout &&
      _onlineStatusError == null &&
      (_state == null || _state!.roundNumber <= 0);
  Duration? get turnTimeout {
    if (_isOnlineMode) {
      final deadline = _state?.turnDeadline;
      if (deadline != null) {
        final diff = deadline.difference(DateTime.now().toUtc());
        if (diff.inMilliseconds > 1000) {
          return diff > const Duration(seconds: 25)
              ? const Duration(seconds: 25)
              : diff;
        }
        return const Duration(seconds: 1);
      }
      return const Duration(seconds: 25);
    }
    return _turnTimeout;
  }
  int get turnTimerGeneration => _turnTimerGeneration;
  bool get isTurnTimerPaused => _isTurnTimerPaused;
  bool get needsLowChipBailout => _needsLowChipBailout;

  List<TableHandHistoryEntry> get handHistory =>
      List.unmodifiable(_handHistory);

  List<TableChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  Map<String, String> get activeSeatReactions =>
      Map.unmodifiable(_activeSeatReactions);

  int get requiredBootStake => _state?.minStake ?? _configuredMinStake;

  bool get isPracticeMode => _isPracticeMode;

  int get localAvailableChips {
    final store = _sessionStore;
    if (store != null) {
      return _isPracticeMode ? store.practiceChips : store.chips;
    }
    return _state?.localPlayer.chips ?? 0;
  }

  int get bailoutReliefAmount => max(2500, requiredBootStake * 10);

  bool get canLocalPack {
    final s = _state;
    if (s == null || s.roundNumber <= 0) return false;
    return s.isLocalPlayersTurn;
  }

  bool get canLocalBlind {
    final s = _state;
    if (s == null || s.roundNumber <= 0) return false;
    return _rulesHelper.canBlind(s, s.localPlayer.id);
  }

  bool get canLocalChaal {
    final s = _state;
    if (s == null || s.roundNumber <= 0) return false;
    return _rulesHelper.canChaal(s, s.localPlayer.id);
  }

  bool get canLocalSideShow {
    final s = _state;
    if (s == null || s.roundNumber <= 0) return false;
    return _rulesHelper.canSideShow(s, s.localPlayer.id);
  }

  bool get canLocalShow {
    final s = _state;
    if (s == null || s.roundNumber <= 0) return false;
    return _rulesHelper.canShow(s, s.localPlayer.id);
  }

  bool get canLocalRaiseStake {
    final s = _state;
    if (s == null || s.roundNumber <= 0 || !s.isLocalPlayersTurn) return false;
    if (!_rulesHelper.canRaiseStake(s)) return false;
    final local = s.localPlayer;
    final doubledCost =
        local.hasSeenCards ? s.chaalAmount * 2 : s.blindAmount * 2;
    return local.chips >= doubledCost;
  }

  bool get isRaiseSelected => _isRaiseSelected && canLocalRaiseStake;

  int get effectiveBlindAmount {
    final s = _state;
    if (s == null) return 0;
    return isRaiseSelected ? s.blindAmount * 2 : s.blindAmount;
  }

  int get effectiveChaalAmount {
    final s = _state;
    if (s == null) return 0;
    return isRaiseSelected ? s.chaalAmount * 2 : s.chaalAmount;
  }

  bool get canLocalSeeCards {
    final s = _state;
    if (s == null || s.isRoundOver || s.roundNumber <= 0) return false;
    final local = s.localPlayer;
    if (local.hasPacked || local.hasSeenCards) return false;
    if (_isOnlineMode) return s.players.length >= 2;
    return local.cards.length == 3;
  }

  /// Evaluated label for the local player's hand once seen or at showdown.
  String? get localHandLabel {
    final s = _state;
    if (s == null) return null;
    final local = s.localPlayer;
    if ((!local.hasSeenCards && !s.isRoundOver) || local.cards.length != 3) {
      return null;
    }
    return TeenPattiHandEvaluator.evaluate(
      local.cards,
      variant: s.variant,
      jokerCard: s.jokerCard,
    ).label;
  }

  void toggleRaiseStake() {
    if (!canLocalRaiseStake) {
      _isRaiseSelected = false;
      return;
    }
    _isRaiseSelected = !_isRaiseSelected;
    _notifySafely();
  }

  void pauseTurnTimer() {
    if (_isTurnTimerPaused) return;
    _isTurnTimerPaused = true;
    _cancelLocalTurnTimer();
    _notifySafely();
  }

  void resumeTurnTimer() {
    if (!_isTurnTimerPaused) return;
    _isTurnTimerPaused = false;
    _syncLocalTurnTimer();
    _notifySafely();
  }

  Future<void> loadTable() async {
    _cancelBotTimer();
    _cancelLocalTurnTimer();
    _isRaiseSelected = false;
    _onlineStatusError = null;

    if (_onlineRepository != null) {
      _isLoading = true;
      _notifySafely();
      try {
        await _onlineRepository.prepareSession();
      } catch (err) {
        _onlineStatusError = err.toString();
        _isLoading = false;
        _notifySafely();
        return;
      }
    }

    if (_sessionStore != null && localAvailableChips < _configuredMinStake) {
      _needsLowChipBailout = true;
      _isLoading = false;
      _notifySafely();
      return;
    }

    _needsLowChipBailout = false;
    _isLoading = true;
    _notifySafely();
    if (_onlineRepository != null) {
      _onlineSub ??= _onlineRepository.stateStream.listen(_onOnlineStateUpdated);
      _onlineChatSub ??=
          _onlineRepository.chatStream.listen(_onOnlineChatReceived);
    }
    try {
      final initial = await _getTableStateUseCase();
      if (!_isOnlineMode || _state == null || _state!.roundNumber <= 0) {
        _state = initial;
      }
      _lastActionFeedback = _state?.lastActionLabel;
      final s = _state;
      if (s != null && _chatMessages.isEmpty) {
        _chatMessages.add(
          TableChatMessage(
            id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
            senderId: 'dealer',
            senderName: 'Club Dealer',
            senderAvatar: AppAssets.splashCharacter,
            text:
                'Welcome to ${s.tableName} (${s.variant.shortBadge})! ${s.variant.ruleSummary}',
            timestamp: DateTime.now(),
          ),
        );
      }
      _recordHandHistoryIfNeeded(_state);
    } catch (err) {
      if (_isOnlineMode) {
        _onlineStatusError = err.toString();
      } else {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _syncLocalTurnTimer();
      _notifySafely();
    }
    if (!_isOnlineMode) {
      await _scheduleAutomatedTurnsIfNeeded();
    }
  }

  void _onOnlineStateUpdated(TableState nextState) {
    if (_disposed) return;
    final prev = _state;
    final turnChanged = prev == null ||
        prev.roundNumber != nextState.roundNumber ||
        prev.turnCount != nextState.turnCount ||
        prev.activeTurnIndex != nextState.activeTurnIndex;

    _state = nextState;
    _onlineStatusError = null;
    if (nextState.lastActionLabel != null &&
        nextState.lastActionLabel != prev?.lastActionLabel) {
      _lastActionFeedback = nextState.lastActionLabel;
    }
    if (!canLocalRaiseStake) {
      _isRaiseSelected = false;
    }
    if (turnChanged && nextState.isLocalPlayersTurn) {
      _turnTimerGeneration++;
    }
    _recordHandHistoryIfNeeded(nextState);
    _syncLocalTurnTimer();
    _notifySafely();
  }

  /// Explicitly leaves an online room before navigating back to the lobby.
  Future<void> leaveOnlineTable() async {
    _cancelBotTimer();
    _cancelLocalTurnTimer();
    final repo = _onlineRepository;
    if (repo != null) {
      await repo.leaveTable();
    }
  }

  Future<void> seeCards() async {
    final current = _state;
    if (current == null || _isActing || !canLocalSeeCards) return;

    _isActing = true;
    _notifySafely();
    try {
      final useCase = _seeCardsUseCase;
      final updated = useCase != null
          ? await useCase(
              currentState: current,
              playerId: current.localPlayer.id,
            )
          : _rulesHelper.seeCards(current, playerId: current.localPlayer.id);
      _state = updated;
      _lastActionFeedback = updated.lastActionLabel;
      if (!canLocalRaiseStake) {
        _isRaiseSelected = false;
      }
    } finally {
      _isActing = false;
      _syncLocalTurnTimer();
      _notifySafely();
    }
  }

  Future<void> performAction(
    PlayerTableAction action, {
    bool? raiseStake,
  }) async {
    final current = _state;
    if (current == null || _isActing || !current.isLocalPlayersTurn) return;

    final effectiveRaise = raiseStake ?? isRaiseSelected;
    _isRaiseSelected = false;
    _cancelBotTimer();
    _cancelLocalTurnTimer();
    _isActing = true;
    _notifySafely();
    try {
      final updated = await _performPlayerActionUseCase(
        currentState: current,
        action: action,
        playerId: current.localPlayer.id,
        raiseStake: effectiveRaise,
      );
      _state = updated;
      _lastActionFeedback = updated.lastActionLabel;
      _recordHandHistoryIfNeeded(updated);
    } finally {
      _isActing = false;
      _syncLocalTurnTimer();
      _notifySafely();
    }
    await _scheduleAutomatedTurnsIfNeeded();
  }

  Future<void> respondToSideShow({required bool accepted}) async {
    final current = _state;
    if (current == null || _isActing || current.pendingSideShow == null) return;

    _isRaiseSelected = false;
    _cancelBotTimer();
    _cancelLocalTurnTimer();
    _isActing = true;
    _notifySafely();
    try {
      final useCase = _resolveSideShowUseCase;
      final updated = useCase != null
          ? await useCase(currentState: current, accepted: accepted)
          : _rulesHelper.resolveSideShow(current, accepted: accepted);
      _state = updated;
      _lastActionFeedback = updated.lastActionLabel;
      _recordHandHistoryIfNeeded(updated);
    } finally {
      _isActing = false;
      _syncLocalTurnTimer();
      _notifySafely();
    }
    await _scheduleAutomatedTurnsIfNeeded();
  }

  Future<void> dealNewHand() async {
    _cancelBotTimer();
    _cancelLocalTurnTimer();
    _isRaiseSelected = false;

    final current = _state;
    if (current == null) {
      await loadTable();
      return;
    }

    final availableChips =
        _sessionStore != null ? localAvailableChips : current.localPlayer.chips;
    if (availableChips < current.minStake) {
      _needsLowChipBailout = true;
      _notifySafely();
      return;
    }

    _needsLowChipBailout = false;
    _isLoading = true;
    _notifySafely();
    try {
      final useCase = _dealNewHandUseCase;
      _state = useCase != null
          ? await useCase(currentState: current)
          : await _getTableStateUseCase();
      _lastActionFeedback = _state?.lastActionLabel;
      _recordHandHistoryIfNeeded(_state);
    } finally {
      _isLoading = false;
      _syncLocalTurnTimer();
      _notifySafely();
    }
    await _scheduleAutomatedTurnsIfNeeded();
  }

  /// Credits emergency bailout chips and immediately resumes dealing.
  Future<int> claimEmergencyBailout() async {
    final amount = bailoutReliefAmount;
    final store = _sessionStore;
    if (store != null) {
      if (_isPracticeMode) {
        await store.claimPracticeReliefChips(amount: amount);
      } else {
        await store.claimBailoutChips(amount: amount);
      }
    } else if (_state != null) {
      final current = _state!;
      final toppedUpPlayers = current.players
          .map(
            (p) => p.isLocalPlayer ? p.copyWith(chips: p.chips + amount) : p,
          )
          .toList(growable: false);
      _state = current.copyWith(players: toppedUpPlayers);
    }

    _needsLowChipBailout = false;
    if (_state == null) {
      await loadTable();
    } else {
      await dealNewHand();
    }
    return amount;
  }

  /// Re-checks balance after returning from Chip Wallet and resumes play if funded.
  Future<void> syncChipsAndResumeDeal() async {
    final available = localAvailableChips;
    if (available < requiredBootStake) {
      _needsLowChipBailout = true;
      _notifySafely();
      return;
    }
    _needsLowChipBailout = false;
    if (_state == null) {
      await loadTable();
    } else {
      await dealNewHand();
    }
  }

  /// Sends a quick emoji reaction from the local player with a floating bubble.
  void sendQuickReaction(String emoji) {
    _appendLocalChat(emoji, isQuickReaction: true);
  }

  /// Sends a text or quick-phrase message from the local player.
  void sendChatMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _appendLocalChat(trimmed, isQuickReaction: false);
  }

  void _appendLocalChat(String content, {required bool isQuickReaction}) {
    final now = DateTime.now();
    if (_isOnlineMode) {
      final last = _lastOnlineChatAt;
      if (last != null &&
          now.difference(last) < const Duration(milliseconds: 1000)) {
        return;
      }
      _lastOnlineChatAt = now;
    }

    final local = _state?.localPlayer;
    final senderId =
        local?.id ?? _sessionStore?.supabaseClient.authUserId ?? 'local';
    final senderName =
        local?.name ?? _sessionStore?.displayName ?? 'You';
    final senderAvatar =
        local?.avatarAsset ?? _sessionStore?.avatarAsset ?? AppAssets.avatar2;

    final msg = TableChatMessage(
      id: 'msg_${now.millisecondsSinceEpoch}_${_chatMessages.length}',
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      text: content,
      timestamp: now,
      isLocal: true,
      isQuickReaction: isQuickReaction,
    );
    _chatMessages.add(msg);
    _showSeatBubble(senderId, content);
    _notifySafely();

    if (_isOnlineMode && _onlineRepository != null) {
      unawaited(
        _onlineRepository.sendChatOrReaction(
          text: content,
          isQuickReaction: isQuickReaction,
          playerId: senderId,
        ),
      );
      return;
    }

    _maybeScheduleBotChatReply();
  }

  void _onOnlineChatReceived(TableChatMessage incoming) {
    if (_disposed) return;
    final localId =
        _state?.localPlayer.id ?? _sessionStore?.supabaseClient.authUserId;
    final isFromSelf =
        incoming.isLocal || (localId != null && incoming.senderId == localId);
    if (isFromSelf) {
      // Optimistic local message & bubble were already displayed on send.
      return;
    }

    _chatMessages.add(incoming);
    _showSeatBubble(incoming.senderId, incoming.text);
    _notifySafely();
  }

  void _maybeScheduleBotChatReply() {
    final s = _state;
    if (_disposed ||
        _isOnlineMode ||
        s == null ||
        _botTurnDelay == Duration.zero) {
      return;
    }
    final activeBots = s.players
        .where((p) => !p.isLocalPlayer && !p.hasPacked)
        .toList(growable: false);
    if (activeBots.isEmpty || _chatRng.nextDouble() > 0.55) return;

    _botChatTimer?.cancel();
    _botChatTimer = Timer(const Duration(milliseconds: 900), () {
      if (_disposed) return;
      final bot = activeBots[_chatRng.nextInt(activeBots.length)];
      final reply = _botReplyPool[_chatRng.nextInt(_botReplyPool.length)];
      _chatMessages.add(
        TableChatMessage(
          id: 'bot_msg_${DateTime.now().millisecondsSinceEpoch}',
          senderId: bot.id,
          senderName: bot.name,
          senderAvatar: bot.avatarAsset,
          text: reply,
          timestamp: DateTime.now(),
        ),
      );
      _showSeatBubble(bot.id, reply);
      _notifySafely();
    });
  }

  void _showSeatBubble(String playerId, String content) {
    _reactionTimers[playerId]?.cancel();
    _activeSeatReactions[playerId] = content;
    _reactionTimers[playerId] = Timer(const Duration(milliseconds: 2600), () {
      _reactionTimers.remove(playerId);
      if (_activeSeatReactions.remove(playerId) != null) {
        _notifySafely();
      }
    });
  }

  void _recordHandHistoryIfNeeded(TableState? s) {
    final result = s?.roundResult;
    if (s == null || result == null) return;
    if (_lastHistoryRound == s.roundNumber) return;

    _lastHistoryRound = s.roundNumber;
    final entry = TableHandHistoryEntry(
      roundNumber: s.roundNumber,
      variant: s.variant,
      jokerCard: s.jokerCard,
      winnerName: result.winner.name,
      winnerAvatar: result.winner.avatarAsset,
      isLocalWinner: result.isLocalWinner,
      potAmount: result.wonAmount,
      localNetChips: result.newBalance - result.previousBalance,
      winningHandLabel: result.handLabel,
      winReason: result.winReason,
      showdownHands: result.showdownHands,
      actionLog: List.unmodifiable(s.roundActionLog),
    );
    _handHistory.insert(0, entry);
    if (_handHistory.length > 30) {
      _handHistory.removeLast();
    }
  }

  void clearFeedback() {
    _lastActionFeedback = null;
    _notifySafely();
  }

  void cancelPendingTurns() {
    _cancelBotTimer();
    _cancelLocalTurnTimer();
  }

  void _syncLocalTurnTimer() {
    _cancelLocalTurnTimer();
    final s = _state;
    final timeout = _turnTimeout;
    if (_disposed ||
        _isOnlineMode ||
        _isTurnTimerPaused ||
        timeout == null ||
        s == null ||
        !s.isLocalPlayersTurn) {
      return;
    }

    _turnTimerGeneration++;
    _localTurnTimer = Timer(timeout, () {
      unawaited(_handleLocalTurnTimeout());
    });
  }

  Future<void> _handleLocalTurnTimeout() async {
    final current = _state;
    if (_disposed ||
        _isOnlineMode ||
        _isTurnTimerPaused ||
        _isActing ||
        current == null ||
        !current.isLocalPlayersTurn) {
      return;
    }
    await performAction(PlayerTableAction.pack, raiseStake: false);
    if (!_disposed && _state != null) {
      _lastActionFeedback = 'Turn time expired — Auto-packed';
      _notifySafely();
    }
  }

  Future<void> _scheduleAutomatedTurnsIfNeeded() async {
    if (_disposed || _isOnlineMode || _advanceAiTurnUseCase == null) return;

    final current = _state;
    if (!_shouldRunAutomatedTurn(current)) return;

    if (_botTurnDelay == Duration.zero) {
      while (!_disposed && _shouldRunAutomatedTurn(_state)) {
        await _executeSingleAutomatedTurn();
      }
      return;
    }

    _cancelBotTimer();
    final delay = _state!.localPlayer.hasPacked
        ? Duration(
            milliseconds: _botTurnDelay.inMilliseconds.clamp(0, 220),
          )
        : _botTurnDelay;

    _botTurnTimer = Timer(delay, () {
      _executeSingleAutomatedTurn();
    });
  }

  bool _shouldRunAutomatedTurn(TableState? s) {
    if (s == null || s.isRoundOver || s.pendingSideShow != null) {
      return false;
    }
    final active = s.activeTurnPlayer;
    return active != null && !active.isLocalPlayer;
  }

  Future<void> _executeSingleAutomatedTurn() async {
    final advance = _advanceAiTurnUseCase;
    final current = _state;
    if (_disposed || advance == null || !_shouldRunAutomatedTurn(current)) {
      return;
    }

    final updated = await advance(currentState: current!);
    if (_disposed) return;

    _state = updated;
    _lastActionFeedback = updated.lastActionLabel;
    _recordHandHistoryIfNeeded(updated);
    _syncLocalTurnTimer();
    _notifySafely();

    if (_botTurnDelay > Duration.zero) {
      unawaited(_scheduleAutomatedTurnsIfNeeded());
    }
  }

  void _cancelBotTimer() {
    _botTurnTimer?.cancel();
    _botTurnTimer = null;
  }

  void _cancelLocalTurnTimer() {
    _localTurnTimer?.cancel();
    _localTurnTimer = null;
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_onlineSub?.cancel() ?? Future<void>.value());
    _onlineSub = null;
    unawaited(_onlineChatSub?.cancel() ?? Future<void>.value());
    _onlineChatSub = null;
    if (_onlineRepository != null) {
      unawaited(_onlineRepository.leaveTable());
    }
    _cancelBotTimer();
    _cancelLocalTurnTimer();
    _botChatTimer?.cancel();
    for (final timer in _reactionTimers.values) {
      timer.cancel();
    }
    _reactionTimers.clear();
    super.dispose();
  }
}
