import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/models/game_user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/router/deep_link_parser.dart';
import '../../../../core/session/app_session_store.dart';
import '../../../../core/session/supabase_sync_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ace_card.dart';
import '../../../../core/widgets/subpage_background_waves.dart';
import '../../../../core/widgets/subpage_header.dart';
import '../../../game_table/domain/entities/game_table_config.dart';
import '../../domain/entities/private_room_state.dart';
import '../controllers/private_room_controller.dart';
import '../widgets/private_room_table_card.dart';

/// Private Room screen matching the Ace Society design.
class PrivateRoomPage extends StatefulWidget {
  const PrivateRoomPage({
    super.key,
    required this.controller,
    this.sessionStore,
  });

  final PrivateRoomController controller;
  final AppSessionStore? sessionStore;

  @override
  State<PrivateRoomPage> createState() => _PrivateRoomPageState();
}

class _PrivateRoomPageState extends State<PrivateRoomPage> {
  static const List<int> _bootOptions = [50, 100, 250, 500, 1000];
  static const List<int> _maxPlayerOptions = [2, 4, 6];
  static const List<String> _variantOptions = [
    'Classic',
    'Muflis',
    'AK47',
    'Joker',
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.loadRoom();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _copyRoomCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      _showFeedback('Room code $code copied!');
    }
  }

  Future<void> _shareRoomLink(String code) async {
    final shareUrl = DeepLinkParser.buildShareableRoomUrl(code);
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (mounted) {
      _showFeedback('Shareable room link copied: $shareUrl');
    }
  }

  Future<void> _showInviteFriendDialog(int seatIndex) async {
    final session = widget.sessionStore ?? AppSessionStore.instance;
    final friends = session.friends;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Invite Friend to Table',
            style: AppTextStyles.modalHeading,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: friends
                    .map(
                      (friend) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: AssetImage(friend.avatarAsset),
                        ),
                        title: Text(
                          friend.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestGreen,
                          ),
                        ),
                        subtitle: Text(
                          friend.statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: friend.isOnline
                                ? AppColors.forestGreen
                                : AppColors.mutedText,
                          ),
                        ),
                        trailing: FilledButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            widget.controller.seatFriend(
                              seatIndex: seatIndex,
                              name: friend.name,
                              avatarAsset: friend.avatarAsset,
                            );
                            final currentRoom = widget.controller.state;
                            if (currentRoom != null) {
                              unawaited(
                                session.sendTableInviteToFriend(
                                  friend: friend,
                                  roomCode: currentRoom.roomCode,
                                  variant: currentRoom.gameVariant,
                                  minStake: currentRoom.bootAmount,
                                ),
                              );
                            }
                            _showFeedback('${friend.name} joined the table!');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.forestGreen,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Invite'),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  static const List<String> _seatPersonas = [
    'balanced',
    'aggressive',
    'tight',
    'bluffer',
    'balanced',
  ];

  Future<void> _showJoinByCodeDialog() async {
    final codeController = TextEditingController();
    final enteredCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Join Private Room',
            style: TextStyle(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Room Code',
              hintText: 'e.g. 9F7K2D',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(codeController.text.trim().toUpperCase()),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
    codeController.dispose();

    if (!mounted || enteredCode == null || enteredCode.isEmpty) return;
    final session = AppSessionStore.instance;
    if (!session.supabaseClient.isConfigured) {
      _showFeedback('Connect Supabase backend to join an online room code.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await session.prepareOnlineSession();
      final ticket = await session.supabaseClient.joinRoomByCode(enteredCode);
      if (!mounted || ticket == null) return;
      await Navigator.of(context).pushNamed(
        AppRoutes.gameTable,
        arguments: GameTableConfig(
          tableName: ticket.tableName,
          minStake: ticket.minStake,
          maxStake: ticket.maxStake,
          maxPlayers: ticket.maxPlayers,
          entryChips: ticket.minStake,
          variant: ticket.variant,
          isOnline: true,
          roomId: ticket.roomId,
          roomCode: ticket.roomCode,
          fillWithAi: ticket.fillWithAi,
        ),
      );
    } on OnlineMatchmakingException catch (err) {
      if (mounted) _showFeedback(err.message);
    } catch (_) {
      if (mounted) _showFeedback('Could not join room $enteredCode.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _startGame(PrivateRoomState room) async {
    if (_isSubmitting) return;
    final session = AppSessionStore.instance;
    if (session.supabaseClient.isConfigured) {
      setState(() => _isSubmitting = true);
      try {
        await session.prepareOnlineSession();
        final ticket = await session.supabaseClient.createPrivateRoom(
          tableName: 'Private Club',
          variant: room.gameVariant,
          minStake: room.bootAmount,
          maxStake: room.bootAmount * 32,
          maxPlayers: room.maxPlayers,
          fillWithAi: room.fillWithAi,
        );
        if (!mounted || ticket == null) return;
        await Navigator.of(context).pushNamed(
          AppRoutes.gameTable,
          arguments: GameTableConfig(
            tableName: ticket.tableName,
            minStake: ticket.minStake,
            maxStake: ticket.maxStake,
            maxPlayers: ticket.maxPlayers,
            entryChips: ticket.minStake,
            variant: ticket.variant,
            autoNextRound: room.autoNextRound,
            isOnline: true,
            roomId: ticket.roomId,
            roomCode: ticket.roomCode,
            fillWithAi: ticket.fillWithAi,
          ),
        );
      } on OnlineMatchmakingException catch (err) {
        if (mounted) _showFeedback(err.message);
      } catch (_) {
        if (mounted) _showFeedback('Could not start online private room.');
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }

    final opponentStack = max(25000, room.bootAmount * 120);
    final seatedFriends = room.seats
        .where((s) => s.isOccupied && !s.isHost && s.seatIndex < room.maxPlayers)
        .map(
          (s) => GameUser(
            id: 'friend_${s.seatIndex}',
            name: s.playerName!,
            chips: opponentStack,
            avatarAsset: s.avatarAsset ?? AppAssets.avatar2,
            kind: ParticipantKind.clientBot,
            personaTag: _seatPersonas[s.seatIndex % _seatPersonas.length],
          ),
        )
        .toList(growable: false);

    await Navigator.of(context).pushNamed(
      AppRoutes.gameTable,
      arguments: GameTableConfig(
        tableName: 'Private • ${room.roomCode}',
        minStake: room.bootAmount,
        maxStake: room.bootAmount * 32,
        maxPlayers: room.maxPlayers,
        entryChips: room.bootAmount,
        variant: room.gameVariant,
        autoNextRound: room.autoNextRound,
        customOpponents: seatedFriends,
        fillWithAi: room.fillWithAi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: SubpageBackgroundWaves(),
          ),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final room = widget.controller.state;
                if (widget.controller.isLoading || room == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                    ),
                  );
                }

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SubpageHeader(
                        title: 'Private Room',
                        subtitle: 'Invite friends and play together',
                        onBackTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 16),

                      // Room Code & Share Card
                      AceCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Room Code',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.mutedText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              room.roomCode,
                                              maxLines: 1,
                                              style: const TextStyle(
                                                fontSize: 23.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.0,
                                                color: Color(0xFF14281D),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () =>
                                              _copyRoomCode(room.roomCode),
                                          behavior: HitTestBehavior.opaque,
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 20,
                                              color: Color(0xFF1D3325),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              VerticalDivider(
                                width: 24,
                                thickness: 1,
                                color: AppColors.inputBorder
                                    .withValues(alpha: 0.45),
                              ),
                              InkWell(
                                onTap: () => _shareRoomLink(room.roomCode),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Share Room',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1E2D24),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEDF2EB),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.inputBorder
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.ios_share_rounded,
                                          size: 20,
                                          color: Color(0xFF1D3325),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _isSubmitting ? null : _showJoinByCodeDialog,
                          icon: const Icon(
                            Icons.meeting_room_outlined,
                            size: 18,
                            color: AppColors.forestGreen,
                          ),
                          label: const Text(
                            'Join Room by Code',
                            style: TextStyle(
                              color: AppColors.forestGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Oval Teen Patti Table
                      PrivateRoomTableCard(
                        seats: room.seats,
                        maxPlayers: room.maxPlayers,
                        onInviteSlotTap: _showInviteFriendDialog,
                      ),
                      const SizedBox(height: 14),

                      // Room Settings Card
                      AceCard(
                        borderRadius: 20,
                        child: Column(
                          children: [
                            InkWell(
                              onTap: widget.controller.toggleSettingsExpanded,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.settings_outlined,
                                      size: 20,
                                      color: Color(0xFF1D3325),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Room Settings',
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF14281D),
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      widget.controller.isSettingsExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 22,
                                      color: const Color(0xFF1D3325),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (widget.controller.isSettingsExpanded) ...[
                              Divider(
                                height: 1,
                                color: AppColors.inputBorder
                                    .withValues(alpha: 0.38),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _SettingDropdownColumn<int>(
                                          leading: const PokerChipBadge(
                                            size: 26,
                                          ),
                                          label: 'Boot Amount',
                                          valueText:
                                              '₹${formatCommaNumber(room.bootAmount)}',
                                          options: _bootOptions,
                                          optionLabelBuilder: (v) =>
                                              '₹${formatCommaNumber(v)}',
                                          onSelected:
                                              widget.controller.setBootAmount,
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 12,
                                        thickness: 1,
                                        color: AppColors.inputBorder
                                            .withValues(alpha: 0.45),
                                      ),
                                      Expanded(
                                        child: _SettingDropdownColumn<int>(
                                          leading: const Icon(
                                            Icons.layers_outlined,
                                            size: 24,
                                            color: AppColors.forestGreen,
                                          ),
                                          label: 'Max Players',
                                          valueText: '${room.maxPlayers}',
                                          options: _maxPlayerOptions,
                                          optionLabelBuilder: (v) => '$v',
                                          onSelected:
                                              widget.controller.setMaxPlayers,
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 12,
                                        thickness: 1,
                                        color: AppColors.inputBorder
                                            .withValues(alpha: 0.45),
                                      ),
                                      Expanded(
                                        child: _SettingDropdownColumn<String>(
                                          leading: const Icon(
                                            Icons.bolt_rounded,
                                            size: 24,
                                            color: AppColors.forestGreen,
                                          ),
                                          label: 'Game Variant',
                                          valueText: room.gameVariant,
                                          options: _variantOptions,
                                          optionLabelBuilder: (v) => v,
                                          onSelected:
                                              widget.controller.setGameVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Host Controls Card
                      AceCard(
                        borderRadius: 20,
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.workspace_premium_outlined,
                                    size: 20,
                                    color: Color(0xFF1D3325),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Host Controls',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF14281D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              color:
                                  AppColors.inputBorder.withValues(alpha: 0.38),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _HostControlTile(
                                        icon: Icons.lock_outline_rounded,
                                        label: 'Lock Room',
                                        value: room.isRoomLocked,
                                        onChanged:
                                            widget.controller.toggleLockRoom,
                                      ),
                                    ),
                                    VerticalDivider(
                                      width: 12,
                                      thickness: 1,
                                      color: AppColors.inputBorder
                                          .withValues(alpha: 0.45),
                                    ),
                                    Expanded(
                                      child: _HostControlTile(
                                        icon: Icons.visibility_outlined,
                                        label: 'Spectators',
                                        value: room.allowSpectators,
                                        onChanged:
                                            widget.controller.toggleSpectators,
                                      ),
                                    ),
                                    VerticalDivider(
                                      width: 12,
                                      thickness: 1,
                                      color: AppColors.inputBorder
                                          .withValues(alpha: 0.45),
                                    ),
                                    Expanded(
                                      child: _HostControlTile(
                                        icon: Icons.shuffle_rounded,
                                        label: 'Auto Next Round',
                                        value: room.autoNextRound,
                                        onChanged: widget
                                            .controller.toggleAutoNextRound,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              color:
                                  AppColors.inputBorder.withValues(alpha: 0.38),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.smart_toy_outlined,
                                    size: 20,
                                    color: Color(0xFF1D3325),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Fill empty seats with AI',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF14281D),
                                          ),
                                        ),
                                        Text(
                                          'Keep off for friends-only tables',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AceToggleSwitch(
                                    key: const Key('fill_empty_seats_ai_toggle'),
                                    value: room.fillWithAi,
                                    onChanged:
                                        widget.controller.toggleFillWithAi,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Bottom Ready & Start Game Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: widget.controller.toggleReady,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: room.isLocalReady
                                      ? const Color(0xFFE7EFE5)
                                      : AppColors.inputFill,
                                  foregroundColor: const Color(0xFF14281D),
                                  side: BorderSide(
                                    color: AppColors.forestGreen,
                                    width: room.isLocalReady ? 1.8 : 1.1,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                icon: Icon(
                                  room.isLocalReady
                                      ? Icons.check_circle_rounded
                                      : Icons.check_rounded,
                                  size: 20,
                                  color: AppColors.forestGreen,
                                ),
                                label: Text(
                                  room.isLocalReady ? 'Ready!' : 'Ready',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                           Expanded(
                            child: SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                onPressed:
                                    _isSubmitting ? null : () => _startGame(room),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.forestGreen,
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                ),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 22,
                                ),
                                label: const Text(
                                  'Start Game',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingDropdownColumn<T> extends StatelessWidget {
  const _SettingDropdownColumn({
    required this.leading,
    required this.label,
    required this.valueText,
    required this.options,
    required this.optionLabelBuilder,
    required this.onSelected,
  });

  final Widget leading;
  final String label;
  final String valueText;
  final List<T> options;
  final String Function(T) optionLabelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      color: AppColors.inputFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => options
          .map(
            (opt) => PopupMenuItem<T>(
              value: opt,
              child: Text(
                optionLabelBuilder(opt),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.forestGreen,
                ),
              ),
            ),
          )
          .toList(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          valueText,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF14281D),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Color(0xFF1D3325),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HostControlTile extends StatelessWidget {
  const _HostControlTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: const Color(0xFF1D3325)),
            const SizedBox(width: 6),
            AceToggleSwitch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2B3D31),
            ),
          ),
        ),
      ],
    );
  }
}
