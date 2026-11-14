import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/club_suit_painter.dart';
import '../controllers/friends_controller.dart';
import '../widgets/friend_list_card.dart';
import '../widgets/friends_filter_tabs.dart';
import '../widgets/invite_code_card.dart';
import '../widgets/invite_friends_banner.dart';

/// Friends directory view embedded in the Home Friends tab.
class FriendsPage extends StatefulWidget {
  const FriendsPage({
    super.key,
    required this.controller,
    required this.onBackTap,
  });

  final FriendsController controller;
  final VoidCallback onBackTap;

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

  Future<void> _showJoinByCodeDialog() async {
    final codeController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.creamBackground,
          title: const Text(
            'Join Friend',
            style: TextStyle(color: AppColors.forestGreen),
          ),
          content: TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Enter invite code (e.g. A7K9D4)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final entered = codeController.text.trim();
                if (entered.isNotEmpty) {
                  _showFeedback('Joining friend room $entered...');
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
              ),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
    codeController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final directory = widget.controller.directory;
        if (widget.controller.isLoading || directory == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.forestGreen),
          );
        }

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar with back button and centered club + Friends title
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: AppColors.inputFill,
                      shape: const CircleBorder(
                        side: BorderSide(
                          color: AppColors.inputBorder,
                          width: 1,
                        ),
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
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CustomPaint(
                          painter:
                              ClubSuitPainter(color: AppColors.forestGreen),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Friends',
                        style: AppTextStyles.pageHeading,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Play together, invite and grow your circle',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.pageSubheading,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              InviteCodeCard(
                inviteCode: directory.inviteCode,
                onCopyCode: () => _copyInviteCode(directory.inviteCode),
                onJoinFriend: _showJoinByCodeDialog,
              ),
              const SizedBox(height: 14),

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
                onInviteTap: (friend) => _showFeedback(
                  'Sent table invite to ${friend.name}!',
                ),
                onMoreTap: (friend) => _showFeedback(
                  '${friend.name} • ${friend.statusText}',
                ),
              ),
              const SizedBox(height: 14),

              InviteFriendsBanner(
                onShareCode: () => _copyInviteCode(directory.inviteCode),
              ),
            ],
          ),
        );
      },
    );
  }
}
