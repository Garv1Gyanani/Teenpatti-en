import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/friend_preview.dart';

/// "Friends" section header + horizontal avatar strip + "Add Friend" action.
class FriendsStrip extends StatelessWidget {
  const FriendsStrip({
    super.key,
    required this.friends,
    required this.onSeeAllTap,
    required this.onAddFriendTap,
    required this.onFriendTap,
  });

  final List<FriendPreview> friends;
  final VoidCallback onSeeAllTap;
  final VoidCallback onAddFriendTap;
  final ValueChanged<FriendPreview> onFriendTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Friends',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.forestGreen,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onSeeAllTap,
              behavior: HitTestBehavior.opaque,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.forestGreen,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ...friends.map(
              (friend) => _FriendAvatarTile(
                friend: friend,
                onTap: () => onFriendTap(friend),
              ),
            ),
            _AddFriendTile(onTap: onAddFriendTap),
          ],
        ),
      ],
    );
  }
}

class _FriendAvatarTile extends StatelessWidget {
  const _FriendAvatarTile({
    required this.friend,
    required this.onTap,
  });

  final FriendPreview friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.inputFill,
              border: Border.all(
                color: AppColors.inputBorder.withValues(alpha: 0.7),
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
          if (friend.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF2AA84A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.creamBackground,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddFriendTile extends StatelessWidget {
  const _AddFriendTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.sageGreen.withValues(alpha: 0.16),
          border: Border.all(
            color: AppColors.inputBorder.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_alt_1_outlined,
              size: 19,
              color: AppColors.forestGreen,
            ),
            SizedBox(height: 2),
            Text(
              'Add Friend',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
                color: AppColors.forestGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

