import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Three-column summary bar displaying Entry Level, Chip Range, and Players Online.
class TableLobbyStatsBar extends StatelessWidget {
  const TableLobbyStatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sageGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            const Expanded(
              child: _StatColumn(
                icon: Icons.style_outlined,
                label: 'Entry Level',
                value: 'From 1,000 chips',
              ),
            ),
            VerticalDivider(
              width: 12,
              thickness: 1,
              color: AppColors.inputBorder.withValues(alpha: 0.8),
            ),
            const Expanded(
              child: _StatColumn(
                icon: Icons.monetization_on_outlined,
                label: 'Chip Range',
                value: '1,000 – 50,000',
              ),
            ),
            VerticalDivider(
              width: 12,
              thickness: 1,
              color: AppColors.inputBorder.withValues(alpha: 0.8),
            ),
            const Expanded(
              child: _StatColumn(
                icon: Icons.groups_outlined,
                label: 'Players Online',
                value: '12,840',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: AppColors.forestGreen),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedText,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forestGreen,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

