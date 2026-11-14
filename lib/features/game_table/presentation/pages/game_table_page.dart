import 'package:flutter/material.dart';

import '../../domain/entities/table_state.dart';
import '../controllers/game_table_controller.dart';
import '../widgets/face_up_card_fan.dart';
import '../widgets/player_seat_widget.dart';
import '../widgets/round_result_dialog.dart';
import '../widgets/table_action_bar.dart';
import '../widgets/table_felt_oval.dart';
import '../widgets/table_pot_badge.dart';
import '../widgets/table_top_bar.dart';

class GameTablePage extends StatefulWidget {
  const GameTablePage({
    super.key,
    required this.controller,
  });

  final GameTableController controller;

  @override
  State<GameTablePage> createState() => _GameTablePageState();
}

class _GameTablePageState extends State<GameTablePage> {
  bool _isResultDialogOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.loadTable();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final feedback = widget.controller.lastActionFeedback;
    if (feedback != null) {
      widget.controller.clearFeedback();
    }

    final result = widget.controller.state?.roundResult;
    if (result != null && !_isResultDialogOpen) {
      _isResultDialogOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return RoundResultDialog(
              result: result,
              onBackToLobby: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).maybePop();
              },
              onPlayAgain: () {
                Navigator.of(dialogContext).pop();
                widget.controller.dealNewHand();
              },
            );
          },
        ).whenComplete(() {
          _isResultDialogOpen = false;
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
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              if (widget.controller.isLoading || table == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              return Column(
                children: [
                  TableTopBar(
                    tableName: table.tableName,
                    minStake: table.minStake,
                    maxStake: table.maxStake,
                    onBackTap: () => Navigator.of(context).maybePop(),
                    onChatTap: () => _showFeedback('Table chat coming soon.'),
                    onStatsTap: () =>
                        _showFeedback('Hand history coming soon.'),
                    onSettingsTap: () =>
                        _showFeedback('Table settings coming soon.'),
                  ),
                  Expanded(
                    child: _TableArena(table: table),
                  ),
                  TableActionBar(
                    blindAmount: table.blindAmount,
                    chaalAmount: table.chaalAmount,
                    hasPacked: table.localPlayer.hasPacked,
                    isDisabled: widget.controller.isActing,
                    onAction: widget.controller.performAction,
                    onDealNewHand: widget.controller.dealNewHand,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TableArena extends StatelessWidget {
  const _TableArena({required this.table});

  final TableState table;

  @override
  Widget build(BuildContext context) {
    final opponents = table.players.where((p) => !p.isLocalPlayer).toList();
    final localPlayer = table.localPlayer;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final tableWidth = (w * 0.84).clamp(260.0, 400.0);
        final tableHeight = (h * 0.84).clamp(360.0, 620.0);
        final tableLeft = (w - tableWidth) / 2;
        final tableTop = (h - tableHeight) / 2 - 4;

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

            // Center Pot badge + live action status pill
            Positioned(
              left: 0,
              right: 0,
              top: tableTop + tableHeight * 0.27,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TablePotBadge(potAmount: table.potAmount),
                  if (table.lastActionLabel != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        table.lastActionLabel!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
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
                child: OpponentSeatWidget(player: opponents[0]),
              ),

            // Opponent 1 (Top-Right)
            if (opponents.length > 1)
              Positioned(
                right: tableLeft + tableWidth * 0.04,
                top: tableTop + 6,
                child: OpponentSeatWidget(player: opponents[1]),
              ),

            // Opponent 2 (Middle-Left)
            if (opponents.length > 2)
              Positioned(
                left: (tableLeft - 12).clamp(4.0, w),
                top: tableTop + tableHeight * 0.27,
                child: OpponentSeatWidget(player: opponents[2]),
              ),

            // Opponent 3 (Middle-Right)
            if (opponents.length > 3)
              Positioned(
                right: (tableLeft - 12).clamp(4.0, w),
                top: tableTop + tableHeight * 0.27,
                child: OpponentSeatWidget(player: opponents[3]),
              ),

            // Opponent 4 (Bottom-Left)
            if (opponents.length > 4)
              Positioned(
                left: tableLeft + 4,
                top: tableTop + tableHeight * 0.53,
                child: OpponentSeatWidget(player: opponents[4]),
              ),

            // Opponent 5 (Bottom-Right)
            if (opponents.length > 5)
              Positioned(
                right: tableLeft + 4,
                top: tableTop + tableHeight * 0.53,
                child: OpponentSeatWidget(player: opponents[5]),
              ),

            // Local Player turn badge + face-up cards + highlighted seat
            Positioned(
              left: 0,
              right: 0,
              top: tableTop + tableHeight - 134,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (localPlayer.isActiveTurn && !localPlayer.hasPacked)
                    const _YourTurnBadge(),
                  const SizedBox(height: 6),
                  if (!localPlayer.hasPacked)
                    FaceUpCardFan(cards: localPlayer.cards),
                  Transform.translate(
                    offset: Offset(0, localPlayer.hasPacked ? 8 : -10),
                    child: LocalPlayerSeatWidget(player: localPlayer),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _YourTurnBadge extends StatelessWidget {
  const _YourTurnBadge();

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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 14,
            color: Color(0xFF143521),
          ),
          SizedBox(width: 5),
          Text(
            'Your Turn',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF143521),
            ),
          ),
        ],
      ),
    );
  }
}
