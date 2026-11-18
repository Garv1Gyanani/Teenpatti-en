import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/session/app_session_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ace_brand_header.dart';
import '../../../../core/widgets/chip_balance_pill.dart';
import '../../../game_table/domain/entities/game_table_config.dart';
import '../../domain/entities/game_table_room.dart';
import '../controllers/table_lobby_controller.dart';
import '../widgets/table_lobby_stats_bar.dart';
import '../widgets/table_lobby_tier_chips.dart';
import '../widgets/table_room_card.dart';

/// Choose a Table lobby view (embedded in the Games tab or standalone route).
class TableLobbyPage extends StatefulWidget {
  const TableLobbyPage({
    super.key,
    required this.controller,
    required this.chips,
    required this.onBackTap,
    required this.onAddChipsTap,
  });

  final TableLobbyController controller;
  final int chips;
  final VoidCallback onBackTap;
  final VoidCallback onAddChipsTap;

  @override
  State<TableLobbyPage> createState() => _TableLobbyPageState();
}

class _TableLobbyPageState extends State<TableLobbyPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadTables();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _handleJoinRoom(GameTableRoom room) {
    if (widget.chips < room.entryChips) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Need ₹${formatIndianNumber(room.entryChips)} chips to join ${room.name}.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Add Chips',
              onPressed: widget.onAddChipsTap,
            ),
          ),
        );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.gameTable,
      arguments: GameTableConfig(
        tableName: room.name,
        minStake: room.smallBlind,
        maxStake: room.bigBlind * 16,
        maxPlayers: room.maxSeats,
        entryChips: room.entryChips,
        isOnline: AppSessionStore.instance.supabaseClient.isConfigured,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final displayedTables = widget.controller.filteredTables;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar: Back button + "Choose a Table" + Chip pill
              Row(
                children: [
                  Material(
                    color: AppColors.inputFill,
                    shape: const CircleBorder(
                      side: BorderSide(color: AppColors.inputBorder, width: 1),
                    ),
                    child: InkWell(
                      onTap: widget.onBackTap,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.forestGreen,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Choose a Table',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.screenBarTitle,
                    ),
                  ),
                  ChipBalancePill(
                    chips: widget.chips,
                    onAddTap: widget.onAddChipsTap,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Hero row: dealer portrait + ACE SOCIETY + subtitle
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 138,
                    height: 126,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.sageGreen.withValues(alpha: 0.48),
                                AppColors.forestGreen.withValues(alpha: 0.24),
                              ],
                            ),
                          ),
                        ),
                        Image.asset(
                          AppAssets.splashCharacter,
                          width: 134,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: -1,
                          height: 20,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.creamBackground
                                        .withValues(alpha: 0.0),
                                    AppColors.creamBackground,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AceBrandHeader(
                          clubSize: 20,
                          titleStyle: AppTextStyles.brandCompact,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pick your seat and join the table',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              const TableLobbyStatsBar(),
              const SizedBox(height: 12),

              TableLobbyTierChips(
                selectedTier: widget.controller.selectedTier,
                onSelect: widget.controller.selectTier,
              ),
              const SizedBox(height: 14),

              // Available Tables header + filter toggle
              Row(
                children: [
                  const Text(
                    'Available Tables',
                    style: AppTextStyles.sectionHeading,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.controller.toggleOpenOnly,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: AppColors.forestGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.controller.showOpenOnly
                              ? 'Open Seats'
                              : 'All Tables',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.forestGreen,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.forestGreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (widget.controller.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                    ),
                  ),
                )
              else
                ...displayedTables.map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TableRoomCard(
                      room: room,
                      onJoin: () => _handleJoinRoom(room),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
