import 'package:flutter/material.dart';

/// Top bar for the Teen Patti table with back button, stakes, and utility
/// action buttons (chat, stats, settings).
class TableTopBar extends StatelessWidget {
  const TableTopBar({
    super.key,
    required this.tableName,
    required this.minStake,
    required this.maxStake,
    required this.onBackTap,
    required this.onChatTap,
    required this.onStatsTap,
    required this.onSettingsTap,
  });

  final String tableName;
  final int minStake;
  final int maxStake;
  final VoidCallback onBackTap;
  final VoidCallback onChatTap;
  final VoidCallback onStatsTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹$minStake / ₹$maxStake',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
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
            tooltip: 'Stats',
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
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
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
    );
  }
}

