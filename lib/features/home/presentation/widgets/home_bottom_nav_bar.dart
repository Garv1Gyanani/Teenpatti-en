import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Floating pill bottom navigation bar for the Home dashboard.
class HomeBottomNavBar extends StatelessWidget {
  const HomeBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<({IconData icon, String label})> _items = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.filter_none_rounded, label: 'Games'),
    (icon: Icons.groups_outlined, label: 'Friends'),
    (icon: Icons.card_giftcard_rounded, label: 'Rewards'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.65),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: _items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == currentIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.forestGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 21,
                      color: isSelected ? Colors.white : AppColors.forestGreen,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color:
                            isSelected ? Colors.white : AppColors.forestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

