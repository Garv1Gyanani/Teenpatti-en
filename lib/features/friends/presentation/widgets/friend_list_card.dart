import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/friend_member.dart';

/// Rounded card rendering the list of friends with online indicators and
/// Invite / Invite to Play pill actions.
class FriendListCard extends StatelessWidget {
  const FriendListCard({
    super.key,
    required this.friends,
    required this.onInviteTap,
    required this.onMoreTap,
  });

  final List<FriendMember> friends;
  final ValueChanged<FriendMember> onInviteTap;
  final ValueChanged<FriendMember> onMoreTap;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.inputBorder.withValues(alpha: 0.72),
          ),
        ),
        child: const Center(
          child: Text(
            'No friends match your filter.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mutedText,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.72),
          width: 1,
        ),
      ),
      child: Column(
        children: friends.asMap().entries.map((entry) {
          final index = entry.key;
          final friend = entry.value;

          return Column(
            children: [
              _FriendRow(
                friend: friend,
                onInviteTap: () => onInviteTap(friend),
                onMoreTap: () => onMoreTap(friend),
              ),
              if (index < friends.length - 1)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.inputBorder.withValues(alpha: 0.55),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.onInviteTap,
    required this.onMoreTap,
  });

  final FriendMember friend;
  final VoidCallback onInviteTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.creamBackground,
              border: Border.all(
                color: AppColors.inputBorder.withValues(alpha: 0.75),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                friend.avatarAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  friend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: friend.isOnline
                            ? const Color(0xFF2AA84A)
                            : const Color(0xFFA8ACA6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        friend.statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 136),
            child: SizedBox(
              height: 34,
              child: friend.isOnline
                  ? FilledButton.icon(
                      onPressed: onInviteTap,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            AppColors.sageGreen.withValues(alpha: 0.24),
                        foregroundColor: AppColors.forestGreen,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Invite to Play',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: onInviteTap,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.creamBackground,
                        foregroundColor: AppColors.forestGreen,
                        side: const BorderSide(
                          color: AppColors.forestGreen,
                          width: 1,
                        ),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text(
                        'Invite',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onMoreTap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: AppColors.forestGreen,
            ),
          ),
        ],
      ),
    );
  }
}
