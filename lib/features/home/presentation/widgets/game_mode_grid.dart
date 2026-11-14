import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/game_mode_item.dart';

/// Four-card horizontal selector for Teen Patti game modes.
class GameModeGrid extends StatelessWidget {
  const GameModeGrid({
    super.key,
    required this.modes,
    required this.selectedMode,
    required this.onSelect,
  });

  final List<GameModeItem> modes;
  final GameModeType selectedMode;
  final ValueChanged<GameModeType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: modes.asMap().entries.map((entry) {
        final index = entry.key;
        final mode = entry.value;
        final isSelected = mode.type == selectedMode;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == modes.length - 1 ? 0 : 8),
            child: _GameModeCard(
              mode: mode,
              isSelected: isSelected,
              onTap: () => onSelect(mode.type),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GameModeCard extends StatelessWidget {
  const _GameModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final GameModeItem mode;
  final bool isSelected;
  final VoidCallback onTap;

  IconData _iconFor(GameModeType type) {
    return switch (type) {
      GameModeType.classic => Icons.style_rounded,
      GameModeType.privateTable => Icons.groups_outlined,
      GameModeType.practice => Icons.workspace_premium_outlined,
      GameModeType.variants => Icons.filter_none_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.sageGreen.withValues(alpha: 0.24)
          : AppColors.inputFill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 104,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.sageGreen.withValues(alpha: 0.55)
                  : AppColors.inputBorder.withValues(alpha: 0.75),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconFor(mode.type),
                size: 28,
                color: AppColors.forestGreen,
              ),
              const SizedBox(height: 8),
              Text(
                mode.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                  color: AppColors.forestGreen,
                ),
              ),
              if (mode.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  mode.subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

