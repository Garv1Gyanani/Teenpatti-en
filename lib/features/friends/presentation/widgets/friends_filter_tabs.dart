import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/friend_member.dart';

/// Segmented pill filter bar for All Friends, Online, and Recently Played.
class FriendsFilterTabs extends StatelessWidget {
  const FriendsFilterTabs({
    super.key,
    required this.selectedTab,
    required this.totalCount,
    required this.onlineCount,
    required this.onSelect,
  });

  final FriendsFilterTab selectedTab;
  final int totalCount;
  final int onlineCount;
  final ValueChanged<FriendsFilterTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.72),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: _SegmentItem(
              label: 'All Friends ($totalCount)',
              isSelected: selectedTab == FriendsFilterTab.all,
              onTap: () => onSelect(FriendsFilterTab.all),
            ),
          ),
          Expanded(
            flex: 9,
            child: _SegmentItem(
              label: 'Online ($onlineCount)',
              isSelected: selectedTab == FriendsFilterTab.online,
              onTap: () => onSelect(FriendsFilterTab.online),
            ),
          ),
          Expanded(
            flex: 11,
            child: _SegmentItem(
              label: 'Recently Played',
              isSelected: selectedTab == FriendsFilterTab.recentlyPlayed,
              onTap: () => onSelect(FriendsFilterTab.recentlyPlayed),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.forestGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.forestGreen,
          ),
        ),
      ),
    );
  }
}
