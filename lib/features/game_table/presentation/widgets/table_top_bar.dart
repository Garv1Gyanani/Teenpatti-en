import 'package:flutter/material.dart';

import '../../domain/entities/game_variant.dart';
import '../../domain/entities/playing_card.dart';

/// Top bar for the Teen Patti table with back button, stakes, active variant
/// pill, and utility action buttons (chat, hand history, settings).
class TableTopBar extends StatelessWidget {
  const TableTopBar({
    super.key,
    required this.tableName,
    required this.minStake,
    required this.maxStake,
    this.variant = TeenPattiVariant.classic,
    this.jokerCard,
    this.handHistoryCount = 0,
    required this.onBackTap,
    required this.onChatTap,
    required this.onStatsTap,
    required this.onSettingsTap,
  });

  final String tableName;
  final int minStake;
  final int maxStake;
  final TeenPattiVariant variant;
  final PlayingCard? jokerCard;
  final int handHistoryCount;
  final VoidCallback onBackTap;
  final VoidCallback onChatTap;
  final VoidCallback onStatsTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final variantBadge = jokerCard != null
        ? 'Joker ${jokerCard!.label}'
        : (variant != TeenPattiVariant.classic ? variant.shortBadge : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _TableCircleIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBackTap,
            tooltip: 'Leave Table',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tableName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '₹$minStake / ₹$maxStake',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    if (variantBadge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0E9D8).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                const Color(0xFFF0E9D8).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          variantBadge,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF0E9D8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _TableCircleIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            onTap: onChatTap,
            tooltip: 'Chat',
          ),
          const SizedBox(width: 8),
          _TableCircleIconButton(
            icon: Icons.bar_chart_rounded,
            onTap: onStatsTap,
            tooltip: 'Hand History',
            badgeCount: handHistoryCount,
          ),
          const SizedBox(width: 8),
          _TableCircleIconButton(
            icon: Icons.settings_outlined,
            onTap: onSettingsTap,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _TableCircleIconButton extends StatelessWidget {
  const _TableCircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.07),
          shape: CircleBorder(
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Tooltip(
              message: tooltip,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF9DF0B8),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF0E291A), width: 1.2),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E291A),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

