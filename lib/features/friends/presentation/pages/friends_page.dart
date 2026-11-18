import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/router/deep_link_parser.dart';
import '../../../../core/session/supabase_sync_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/subpage_background_waves.dart';
import '../../../../core/widgets/subpage_header.dart';
import '../../domain/entities/friend_member.dart';
import '../controllers/friends_controller.dart';
import '../widgets/friend_list_card.dart';
import '../widgets/friends_filter_tabs.dart';
import '../widgets/invite_code_card.dart';
import '../widgets/invite_friends_banner.dart';

/// Friends directory view embedded in the Home Friends tab or standalone route.
class FriendsPage extends StatefulWidget {
  const FriendsPage({
    super.key,
    required this.controller,
    this.embedded = true,
    this.onBackTap,
  });

  final FriendsController controller;
  final bool embedded;
  final VoidCallback? onBackTap;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    widget.controller.loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      _showFeedback('Invite code $code copied!');
    }
  }

  Future<void> _shareInviteLink(String code) async {
    final shareUrl = DeepLinkParser.buildShareableRoomUrl(code);
    await Clipboard.setData(
      ClipboardData(
        text: 'Join my Ace Society circle with Player ID $code • $shareUrl',
      ),
    );
    if (mounted) {
      _showFeedback('Invite link for $code copied!');
    }
  }

  Future<void> _showJoinByCodeDialog() async {
    final codeController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add Friend or Join Room',
            style: TextStyle(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter a friend\'s Player ID (e.g. TP884210) to add them to your circle, or a 6-digit Room Code to join their table.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.mutedText,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('friends_code_input_field'),
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Player ID or Room Code (e.g. TP884210)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              key: const Key('friends_join_room_button'),
              onPressed: () {
                final entered = codeController.text.trim().toUpperCase();
                Navigator.of(dialogContext).pop();
                if (entered.isNotEmpty) {
                  Navigator.of(context).pushNamed(
                    AppRoutes.privateRoom,
                    arguments: entered,
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forestGreen,
                side: const BorderSide(color: AppColors.forestGreen),
              ),
              child: const Text('Join Room'),
            ),
            FilledButton(
              key: const Key('friends_add_friend_button'),
              onPressed: () async {
                final entered = codeController.text.trim().toUpperCase();
                Navigator.of(dialogContext).pop();
                if (entered.isEmpty) return;
                try {
                  final added = await widget.controller.addFriendByCode(entered);
                  if (mounted) {
                    _showFeedback(
                      'Added ${added.name} (${added.playerCode ?? entered}) to your Friends circle!',
                    );
                  }
                } on OnlineMatchmakingException catch (err) {
                  if (mounted) _showFeedback(err.message);
                } catch (_) {
                  if (mounted) {
                    _showFeedback('Could not add friend with code $entered.');
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
              ),
              child: const Text('Add Friend'),
            ),
          ],
        );
      },
    );
    codeController.dispose();
  }

  Future<void> _handleAcceptInvite(TableRoomInvite invite) async {
    final code = await widget.controller.respondToInvite(
      invite,
      accept: true,
    );
    if (!mounted) return;
    final targetCode = code ?? invite.roomCode;
    Navigator.of(context).pushNamed(
      AppRoutes.privateRoom,
      arguments: targetCode,
    );
  }

  Future<void> _handleDeclineInvite(TableRoomInvite invite) async {
    await widget.controller.respondToInvite(invite, accept: false);
    if (mounted) {
      _showFeedback('Declined table invite from ${invite.senderName}.');
    }
  }

  void _showFriendDetailsSheet(FriendMember friend) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: AssetImage(friend.avatarAsset),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forestGreen,
                            ),
                          ),
                          Text(
                            '${friend.playerCode ?? friend.id.toUpperCase()} • ${friend.statusText}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await widget.controller.removeFriend(friend.id);
                          if (mounted) {
                            _showFeedback(
                              'Removed ${friend.name} from Friends.',
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB43C3C),
                          side: const BorderSide(color: Color(0xFFB43C3C)),
                        ),
                        icon: const Icon(Icons.person_remove_outlined, size: 18),
                        label: const Text('Remove'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await widget.controller.sendTableInvite(
                            friend: friend,
                          );
                          if (mounted) {
                            _showFeedback(
                              'Sent table invite to ${friend.name}!',
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forestGreen,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Send Invite'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final directory = widget.controller.directory;
        if (widget.controller.isLoading || directory == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.forestGreen),
          );
        }

        final pendingInvites = widget.controller.pendingInvites;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            widget.embedded ? 6 : 10,
            16,
            widget.embedded ? 16 : 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SubpageHeader(
                title: 'Friends',
                subtitle: 'Play together, invite and grow your circle',
                onBackTap:
                    widget.onBackTap ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 16),

              InviteCodeCard(
                inviteCode: directory.inviteCode,
                onCopyCode: () => _copyInviteCode(directory.inviteCode),
                onJoinFriend: _showJoinByCodeDialog,
              ),
              const SizedBox(height: 14),

              if (pendingInvites.isNotEmpty) ...[
                _PendingRoomInvitesCard(
                  invites: pendingInvites,
                  onAccept: _handleAcceptInvite,
                  onDecline: _handleDeclineInvite,
                ),
                const SizedBox(height: 14),
              ],

              FriendsFilterTabs(
                selectedTab: widget.controller.selectedTab,
                totalCount: directory.totalCount,
                onlineCount: directory.onlineCount,
                onSelect: widget.controller.selectTab,
              ),
              const SizedBox(height: 12),

              // Search bar
              TextField(
                controller: _searchController,
                onChanged: widget.controller.updateSearch,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.forestGreen,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.inputFill,
                  hintText: 'Search friends...',
                  hintStyle: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.mutedText,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.mutedText,
                    size: 21,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: AppColors.inputBorder.withValues(alpha: 0.72),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: AppColors.forestGreen,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              FriendListCard(
                friends: widget.controller.filteredFriends,
                onInviteTap: (friend) async {
                  final navigator = Navigator.of(context);
                  await widget.controller.sendTableInvite(
                    friend: friend,
                    roomCode: friend.activeRoomCode ?? '9F7K2D',
                  );
                  if (!mounted) return;
                  if (friend.activeRoomCode != null &&
                      friend.activeRoomCode!.isNotEmpty) {
                    navigator.pushNamed(
                      AppRoutes.privateRoom,
                      arguments: friend.activeRoomCode,
                    );
                  } else if (friend.isOnline) {
                    navigator.pushNamed(AppRoutes.privateRoom);
                  } else {
                    _showFeedback('Sent table invite to ${friend.name}!');
                  }
                },
                onMoreTap: _showFriendDetailsSheet,
              ),
              const SizedBox(height: 14),

              InviteFriendsBanner(
                onShareCode: () => _shareInviteLink(directory.inviteCode),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildContent();
    }

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: SubpageBackgroundWaves(),
          ),
          SafeArea(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
}

class _PendingRoomInvitesCard extends StatelessWidget {
  const _PendingRoomInvitesCard({
    required this.invites,
    required this.onAccept,
    required this.onDecline,
  });

  final List<TableRoomInvite> invites;
  final ValueChanged<TableRoomInvite> onAccept;
  final ValueChanged<TableRoomInvite> onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.forestGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 18,
                color: AppColors.forestGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Table Invites (${invites.length})',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...invites.map(
            (invite) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: AssetImage(invite.senderAvatar),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${invite.senderName} invited you',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                              Text(
                                '${invite.tableName} (${invite.variant}) • ₹${formatIndianNumber(invite.minStake)} Boot • Code ${invite.roomCode}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          key: Key('decline_room_invite_${invite.id}'),
                          onPressed: () => onDecline(invite),
                          child: const Text('Decline'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: Key('accept_room_invite_${invite.id}'),
                          onPressed: () => onAccept(invite),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.forestGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text('Join Table'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
