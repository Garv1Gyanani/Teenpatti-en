import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/audio/app_audio_cue.dart';
import '../../../../core/audio/app_audio_service.dart';
import '../../../../core/audio/app_haptic_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/table_state.dart';
import '../controllers/game_table_controller.dart';
import '../widgets/animated_card_hand.dart';
import '../widgets/chip_flight_overlay.dart';
import '../widgets/face_down_card_fan.dart';
import '../widgets/face_up_card_fan.dart';
import '../widgets/low_chips_bailout_dialog.dart';
import '../widgets/player_seat_widget.dart';
import '../widgets/round_result_dialog.dart';
import '../widgets/table_action_bar.dart';
import '../widgets/table_chat_sheet.dart';
import '../widgets/table_felt_oval.dart';
import '../widgets/table_hand_history_sheet.dart';
import '../widgets/table_pot_badge.dart';
import '../widgets/table_top_bar.dart';

class GameTablePage extends StatefulWidget {
  const GameTablePage({
    super.key,
    required this.controller,
    this.autoNextRound = false,
  });

  final GameTableController controller;
  final bool autoNextRound;

  @override
  State<GameTablePage> createState() => _GameTablePageState();
}

class _GameTablePageState extends State<GameTablePage> {
  bool _isResultDialogOpen = false;
  bool _isSideShowDialogOpen = false;
  bool _isLeavingTable = false;
  int _lastShownResultRound = 0;
  int _lastSoundRound = 0;
  int _lastSoundPot = 0;
  bool _wasLocalTurn = false;
  bool _wasLocalSeen = false;
  Timer? _autoNextRoundTimer;
  BuildContext? _activeResultDialogContext;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.loadTable();
  }

  void _triggerStateCues(TableState state) {
    if (state.roundNumber <= 0) return;

    if (state.roundNumber != _lastSoundRound) {
      _lastSoundRound = state.roundNumber;
      _lastSoundPot = state.potAmount;
      _wasLocalSeen = state.localPlayer.hasSeenCards;
      _wasLocalTurn = state.isLocalPlayersTurn;
      AppAudioService.instance.play(AppAudioCue.cardDeal);
      return;
    }

    if (!_wasLocalSeen && state.localPlayer.hasSeenCards) {
      AppAudioService.instance.play(AppAudioCue.cardFlip);
      AppHapticService.light();
    }
    if (state.potAmount > _lastSoundPot) {
      AppAudioService.instance.play(AppAudioCue.chipToss);
    }
    if (!_wasLocalTurn && state.isLocalPlayersTurn && !state.isRoundOver) {
      AppAudioService.instance.play(AppAudioCue.turnChime);
      AppHapticService.selection();
    }

    _lastSoundPot = state.potAmount;
    _wasLocalSeen = state.localPlayer.hasSeenCards;
    _wasLocalTurn = state.isLocalPlayersTurn;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final feedback = widget.controller.lastActionFeedback;
    if (feedback != null) {
      widget.controller.clearFeedback();
      if (feedback.contains('Auto-packed')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showFeedback(feedback);
          }
        });
      }
    }

    final state = widget.controller.state;
    if (state == null) return;
    _triggerStateCues(state);

    final pendingSideShow = state.pendingSideShow;
    if (pendingSideShow != null &&
        pendingSideShow.targetId == state.localPlayer.id &&
        !_isSideShowDialogOpen) {
      final requester = state.findPlayerById(pendingSideShow.requesterId);
      if (requester != null) {
        _isSideShowDialogOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.controller.pauseTurnTimer();
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return AlertDialog(
                backgroundColor: AppColors.creamBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  'Side Show Request',
                  style: TextStyle(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: Text(
                  '${requester.name} wants to compare cards with you. Accept to compare hands (loser packs), or Decline to continue.',
                  style: const TextStyle(color: AppColors.forestGreen),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      widget.controller.respondToSideShow(accepted: false);
                    },
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      widget.controller.respondToSideShow(accepted: true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                    ),
                    child: const Text('Accept'),
                  ),
                ],
              );
            },
          ).whenComplete(() {
            _isSideShowDialogOpen = false;
            widget.controller.resumeTurnTimer();
          });
        });
      }
    }

    final result = state.roundResult;
    if (widget.controller.isOnlineMode &&
        _isResultDialogOpen &&
        result == null &&
        _activeResultDialogContext != null) {
      final dCtx = _activeResultDialogContext!;
      _activeResultDialogContext = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (dCtx.mounted && Navigator.of(dCtx).canPop()) {
          Navigator.of(dCtx).pop();
        }
      });
    }
    if (result == null && _lastShownResultRound >= state.roundNumber) {
      _lastShownResultRound = state.roundNumber - 1;
    }
    if (result != null &&
        !_isResultDialogOpen &&
        _lastShownResultRound != state.roundNumber) {
      _isResultDialogOpen = true;
      _lastShownResultRound = state.roundNumber;
      final localWon = result.winner.id == state.localPlayer.id;
      if (localWon) {
        AppAudioService.instance.duckAmbientForShowdown();
        AppAudioService.instance.play(AppAudioCue.winFlourish);
        AppHapticService.medium();
      } else {
        AppAudioService.instance.play(AppAudioCue.loseSoft);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.controller.pauseTurnTimer();
        BuildContext? activeDialogContext;
        if (widget.autoNextRound && !widget.controller.isOnlineMode) {
          _autoNextRoundTimer?.cancel();
          _autoNextRoundTimer = Timer(const Duration(seconds: 3), () {
            final dCtx = activeDialogContext;
            if (!mounted || !_isResultDialogOpen || dCtx == null) return;
            if (Navigator.of(dCtx).canPop()) {
              Navigator.of(dCtx).pop();
              widget.controller.dealNewHand();
            }
          });
        }
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            activeDialogContext = dialogContext;
            _activeResultDialogContext = dialogContext;
            return RoundResultDialog(
              result: result,
              onBackToLobby: () {
                _autoNextRoundTimer?.cancel();
                Navigator.of(dialogContext).pop();
                unawaited(_handleLeaveTable());
              },
              onPlayAgain: () {
                _autoNextRoundTimer?.cancel();
                Navigator.of(dialogContext).pop();
                if (!widget.controller.isOnlineMode) {
                  widget.controller.dealNewHand();
                }
              },
            );
          },
        ).whenComplete(() {
          _autoNextRoundTimer?.cancel();
          _isResultDialogOpen = false;
          _activeResultDialogContext = null;
          widget.controller.resumeTurnTimer();
        });
      });
    }
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 98),
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  void _openChatSheet() {
    widget.controller.pauseTurnTimer();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E291A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TableChatSheet(controller: widget.controller),
    ).whenComplete(widget.controller.resumeTurnTimer);
  }

  void _openHandHistorySheet() {
    widget.controller.pauseTurnTimer();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E291A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TableHandHistorySheet(
        entries: widget.controller.handHistory,
      ),
    ).whenComplete(widget.controller.resumeTurnTimer);
  }

  void _openSettings() {
    widget.controller.pauseTurnTimer();
    Navigator.of(context)
        .pushNamed(AppRoutes.settings)
        .whenComplete(widget.controller.resumeTurnTimer);
  }

  Future<void> _handleClaimBailout() async {
    final added = await widget.controller.claimEmergencyBailout();
    if (mounted) {
      _showFeedback('Credited +₹${formatIndianNumber(added)} relief chips!');
    }
  }

  Future<void> _handleOpenWalletFromBailout() async {
    widget.controller.pauseTurnTimer();
    await Navigator.of(context).pushNamed(AppRoutes.wallet);
    if (!mounted) return;
    widget.controller.resumeTurnTimer();
    await widget.controller.syncChipsAndResumeDeal();
  }

  Future<void> _handleLeaveTable() async {
    if (!widget.controller.isOnlineMode) {
      await Navigator.of(context).maybePop();
      return;
    }
    if (_isLeavingTable) return;
    _isLeavingTable = true;
    await widget.controller.leaveOnlineTable();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _autoNextRoundTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.controller.isOnlineMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.controller.isOnlineMode) {
          unawaited(_handleLeaveTable());
        }
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.05),
              radius: 0.95,
              colors: [
                Color(0xFF153B26),
                Color(0xFF0C2416),
                Color(0xFF07160E),
              ],
            ),
          ),
          child: SafeArea(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final table = widget.controller.state;
                final needsBailout = widget.controller.needsLowChipBailout;
                final onlineError = widget.controller.onlineStatusError;

                if (table == null) {
                  if (needsBailout) {
                    return Center(
                      child: LowChipsBailoutDialog(
                        currentChips: widget.controller.localAvailableChips,
                        requiredBoot: widget.controller.requiredBootStake,
                        reliefAmount: widget.controller.bailoutReliefAmount,
                        onClaimRelief: _handleClaimBailout,
                        onOpenWallet: _handleOpenWalletFromBailout,
                        onLeaveTable: () => unawaited(_handleLeaveTable()),
                      ),
                    );
                  }
                  if (onlineError != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E291A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                color: Color(0xFFF0E9D8),
                                size: 34,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                onlineError,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton(
                                    onPressed: () =>
                                        unawaited(_handleLeaveTable()),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white38,
                                      ),
                                    ),
                                    child: const Text('Leave'),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: widget.controller.loadTable,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFF0E9D8),
                                      foregroundColor: const Color(0xFF142E1F),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final disableControls = widget.controller.isActing ||
                    table.roundNumber <= 0 ||
                    (widget.controller.isOnlineMode &&
                        table.localPlayer.hasPacked);

                return Stack(
                  children: [
                    Column(
                      children: [
                        TableTopBar(
                          tableName: table.tableName,
                          minStake: table.minStake,
                          maxStake: table.maxStake,
                          variant: table.variant,
                          jokerCard: table.jokerCard,
                          handHistoryCount: widget.controller.handHistory.length,
                          onBackTap: () => unawaited(_handleLeaveTable()),
                          onChatTap: _openChatSheet,
                          onStatsTap: _openHandHistorySheet,
                          onSettingsTap: _openSettings,
                        ),
                        Expanded(
                          child: _TableArena(
                            table: table,
                            localHandLabel: widget.controller.localHandLabel,
                            seatReactions: widget.controller.activeSeatReactions,
                            turnDuration: widget.controller.turnTimeout ??
                                const Duration(seconds: 15),
                            turnGeneration: widget.controller.turnTimerGeneration,
                            isTimerPaused: widget.controller.isTurnTimerPaused,
                            enableTimerRing:
                                widget.controller.turnTimeout != null &&
                                    table.roundNumber > 0,
                            isWaitingForOpponents:
                                widget.controller.isWaitingForOpponents,
                            onlineRoomCode: widget.controller.onlineRoomCode,
                            onSeeCards: widget.controller.canLocalSeeCards
                                ? widget.controller.seeCards
                                : null,
                          ),
                        ),
                        TableActionBar(
                          blindAmount: widget.controller.effectiveBlindAmount,
                          chaalAmount: widget.controller.effectiveChaalAmount,
                          hasPacked: table.localPlayer.hasPacked,
                          isDisabled: disableControls,
                          canPack: widget.controller.canLocalPack,
                          canSideShow: widget.controller.canLocalSideShow,
                          canBlind: widget.controller.canLocalBlind,
                          canChaal: widget.controller.canLocalChaal,
                          canShow: widget.controller.canLocalShow,
                          canRaiseStake: widget.controller.canLocalRaiseStake,
                          isRaiseSelected: widget.controller.isRaiseSelected,
                          onToggleRaise: widget.controller.toggleRaiseStake,
                          blindTurnsTaken: table.localPlayer.blindTurnsTaken,
                          maxBlindTurns: table.maxBlindTurns,
                          hasSeenCards: table.localPlayer.hasSeenCards,
                          packedButtonLabel: widget.controller.isOnlineMode
                              ? 'Next round starting soon...'
                              : null,
                          onAction: widget.controller.performAction,
                          onDealNewHand: widget.controller.dealNewHand,
                        ),
                      ],
                    ),
                    if (needsBailout)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.62),
                          child: Center(
                            child: LowChipsBailoutDialog(
                              currentChips:
                                  widget.controller.localAvailableChips,
                              requiredBoot: widget.controller.requiredBootStake,
                              reliefAmount:
                                  widget.controller.bailoutReliefAmount,
                              onClaimRelief: _handleClaimBailout,
                              onOpenWallet: _handleOpenWalletFromBailout,
                              onLeaveTable: () => unawaited(_handleLeaveTable()),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TableArena extends StatelessWidget {
  const _TableArena({
    required this.table,
    required this.localHandLabel,
    this.seatReactions = const {},
    this.turnDuration = const Duration(seconds: 15),
    this.turnGeneration = 0,
    this.isTimerPaused = false,
    this.enableTimerRing = true,
    this.isWaitingForOpponents = false,
    this.onlineRoomCode,
    this.onSeeCards,
  });

  final TableState table;
  final String? localHandLabel;
  final Map<String, String> seatReactions;
  final Duration turnDuration;
  final int turnGeneration;
  final bool isTimerPaused;
  final bool enableTimerRing;
  final bool isWaitingForOpponents;
  final String? onlineRoomCode;
  final VoidCallback? onSeeCards;

  @override
  Widget build(BuildContext context) {
    final opponents = table.players.where((p) => !p.isLocalPlayer).toList();
    final localPlayer = table.localPlayer;
    final activeTurnPlayer = table.activeTurnPlayer;
    final feltVariantNote = table.jokerCard != null
        ? 'Wild Joker: ${table.jokerCard!.label} (All ${table.jokerCard!.rank}s Wild)'
        : (table.variant != TeenPattiVariant.classic
            ? table.variant.ruleSummary
            : null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final tableWidth = (w * 0.84).clamp(260.0, 400.0);
        final tableHeight = (h * 0.84).clamp(360.0, 620.0);
        final tableLeft = (w - tableWidth) / 2;
        final tableTop = (h - tableHeight) / 2 - 4;
        final isLocalRevealed =
            localPlayer.hasSeenCards || table.isRoundOver;

        Alignment toAlignment(double cx, double cy) {
          return Alignment(
            ((cx / w) * 2 - 1).clamp(-0.95, 0.95),
            ((cy / h) * 2 - 1).clamp(-0.95, 0.95),
          );
        }

        final seatAnchors = <String, Alignment>{
          localPlayer.id: const Alignment(0.0, 0.78),
          if (opponents.isNotEmpty)
            opponents[0].id:
                toAlignment(tableLeft + tableWidth * 0.08 + 56, tableTop + 38),
          if (opponents.length > 1)
            opponents[1].id: toAlignment(
              w - (tableLeft + tableWidth * 0.04 + 56),
              tableTop + 38,
            ),
          if (opponents.length > 2)
            opponents[2].id: toAlignment(
              (tableLeft - 12).clamp(4.0, w) + 56,
              tableTop + tableHeight * 0.27 + 32,
            ),
          if (opponents.length > 3)
            opponents[3].id: toAlignment(
              w - ((tableLeft - 12).clamp(4.0, w) + 56),
              tableTop + tableHeight * 0.27 + 32,
            ),
          if (opponents.length > 4)
            opponents[4].id: toAlignment(
              tableLeft + 4 + 56,
              tableTop + tableHeight * 0.53 + 32,
            ),
          if (opponents.length > 5)
            opponents[5].id: toAlignment(
              w - (tableLeft + 4 + 56),
              tableTop + tableHeight * 0.53 + 32,
            ),
        };
        final playerContributions = <String, int>{
          for (final player in table.players) player.id: player.totalBet,
        };
        final potAnchor = toAlignment(w / 2, tableTop + tableHeight * 0.25 + 28);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Oval felt table
            Positioned(
              left: tableLeft,
              top: tableTop,
              width: tableWidth,
              height: tableHeight,
              child: const TableFeltOval(),
            ),

            // Center Pot badge + variant/joker badge + live action status pill
            Positioned(
              left: 24,
              right: 24,
              top: tableTop + tableHeight * 0.25,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TablePotBadge(potAmount: table.potAmount),
                  if (feltVariantNote != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E9D8).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFFF0E9D8).withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        feltVariantNote,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF0E9D8),
                        ),
                      ),
                    ),
                  ],
                  if (isWaitingForOpponents) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E291A).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF9DE6A8).withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF9DE6A8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              onlineRoomCode != null && onlineRoomCode!.isNotEmpty
                                  ? 'Room $onlineRoomCode • Waiting for players...'
                                  : 'Searching for players...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF0E9D8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (table.lastActionLabel != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        table.lastActionLabel!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Opponent 0 (Top-Left)
            if (opponents.isNotEmpty)
              Positioned(
                left: tableLeft + tableWidth * 0.08,
                top: tableTop + 6,
                child: OpponentSeatWidget(
                  player: opponents[0],
                  revealCards: table.isRoundOver,
                  reactionText: seatReactions[opponents[0].id],
                  roundNumber: table.roundNumber,
                  seatIndex: 0,
                  dealFromOffset: const Offset(0.3, 0.55),
                ),
              ),

            // Opponent 1 (Top-Right)
            if (opponents.length > 1)
              Positioned(
                right: tableLeft + tableWidth * 0.04,
                top: tableTop + 6,
                child: OpponentSeatWidget(
                  player: opponents[1],
                  revealCards: table.isRoundOver,
                  reactionText: seatReactions[opponents[1].id],
                  roundNumber: table.roundNumber,
                  seatIndex: 1,
                  dealFromOffset: const Offset(-0.3, 0.55),
                ),
              ),

            // Opponent 2 (Middle-Left)
            if (opponents.length > 2)
              Positioned(
                left: (tableLeft - 12).clamp(4.0, w),
                top: tableTop + tableHeight * 0.27,
                child: OpponentSeatWidget(
                  player: opponents[2],
                  revealCards: table.isRoundOver,
                  reactionText: seatReactions[opponents[2].id],
                  roundNumber: table.roundNumber,
                  seatIndex: 2,
                  dealFromOffset: const Offset(0.55, 0.15),
                ),
              ),

            // Opponent 3 (Middle-Right)
            if (opponents.length > 3)
              Positioned(
                right: (tableLeft - 12).clamp(4.0, w),
                top: tableTop + tableHeight * 0.27,
                child: OpponentSeatWidget(
                  player: opponents[3],
                  revealCards: table.isRoundOver,
                  reactionText: seatReactions[opponents[3].id],
                  roundNumber: table.roundNumber,
                  seatIndex: 3,
                  dealFromOffset: const Offset(-0.55, 0.15),
                ),
              ),

            // Opponent 4 (Bottom-Left)
            if (opponents.length > 4)
              Positioned(
                left: tableLeft + 4,
                top: tableTop + tableHeight * 0.53,
                child: OpponentSeatWidget(
                  player: opponents[4],
                  revealCards: table.isRoundOver,
                  reactionText: seatReactions[opponents[4].id],
                  roundNumber: table.roundNumber,
                  seatIndex: 4,
                  dealFromOffset: const Offset(0.45, -0.35),
                ),
              ),

            // Opponent 5 (Bottom-Right)
            if (opponents.length > 5)
              Positioned(
                right: tableLeft + 4,
                top: tableTop + tableHeight * 0.53,
                child: OpponentSeatWidget(
                  player: opponents[5],
                  revealCards: table.isRoundOver,
                  reactionText: seatReactions[opponents[5].id],
                  roundNumber: table.roundNumber,
                  seatIndex: 5,
                  dealFromOffset: const Offset(-0.45, -0.35),
                ),
              ),

            // Local Player turn badge + blind/seen cards + highlighted seat
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: table.isLocalPlayersTurn
                        ? const _YourTurnBadge(key: ValueKey<String>('your_turn'))
                        : (!table.isRoundOver && activeTurnPlayer != null)
                            ? _OpponentTurnBadge(
                                key: ValueKey<String>(activeTurnPlayer.id),
                                name: activeTurnPlayer.name,
                              )
                            : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 6),
                  if (!localPlayer.hasPacked && table.roundNumber > 0)
                    AnimatedDealIn(
                      roundKey: table.roundNumber,
                      seatIndex: opponents.length,
                      beginOffset: const Offset(0, 0.14),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedCardRevealFlip(
                            isRevealed: isLocalRevealed,
                            hiddenChild: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: FaceDownCardFan(
                                cardWidth: 44,
                                cardHeight: 62,
                              ),
                            ),
                            revealedChild: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaceUpCardFan(cards: localPlayer.cards),
                                if (localHandLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.16),
                                        ),
                                      ),
                                      child: Text(
                                        localHandLabel!,
                                        style: AppTextStyles.playerName.copyWith(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFF0E9D8),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isLocalRevealed)
                            GestureDetector(
                              key: const Key('see_cards_button'),
                              behavior: HitTestBehavior.opaque,
                              onTap: onSeeCards,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 14,
                                ),
                                child: _SeeCardsPill(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(0, localPlayer.hasPacked ? 4 : -8),
                    child: LocalPlayerSeatWidget(
                      player: localPlayer,
                      reactionText: seatReactions[localPlayer.id],
                      roundNumber: table.roundNumber,
                      turnDuration: turnDuration,
                      turnGeneration: turnGeneration,
                      isTimerPaused: isTimerPaused,
                      enableTimerRing: enableTimerRing,
                    ),
                  ),
                ],
              ),
            ),

            // Animated chip toss & showdown winner pot sweep overlay
            Positioned.fill(
              child: ChipFlightOverlay(
                roundNumber: table.roundNumber,
                seatAnchors: seatAnchors,
                playerContributions: playerContributions,
                isRoundOver: table.isRoundOver,
                winnerPlayerId: table.roundResult?.winner.id,
                potAnchor: potAnchor,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeeCardsPill extends StatelessWidget {
  const _SeeCardsPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E9D8),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.visibility_rounded,
            size: 14,
            color: Color(0xFF142E1F),
          ),
          const SizedBox(width: 5),
          Text(
            'See Cards',
            style: AppTextStyles.buttonLabel.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF142E1F),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpponentTurnBadge extends StatelessWidget {
  const _OpponentTurnBadge({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        '$name is thinking...',
        style: AppTextStyles.playerName.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _YourTurnBadge extends StatelessWidget {
  const _YourTurnBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC2ECC7),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8BE29B).withValues(alpha: 0.45),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 14,
            color: Color(0xFF143521),
          ),
          const SizedBox(width: 5),
          Text(
            'Your Turn',
            style: AppTextStyles.buttonLabel.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF143521),
            ),
          ),
        ],
      ),
    );
  }
}
