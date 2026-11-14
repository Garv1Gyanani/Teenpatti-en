import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/game_table_room.dart';

/// Filter pills for Beginner, Classic, and High Stakes tables.
class TableLobbyTierChips extends StatelessWidget {
  const TableLobbyTierChips({
    super.key,
    required this.selectedTier,
    required this.onSelect,
  });

  final TableTier? selectedTier;
  final ValueChanged<TableTier> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TierPill(
            label: 'Beginner',
            icon: Icons.menu_book_outlined,
            isSelected: selectedTier == TableTier.beginner,
            onTap: () => onSelect(TableTier.beginner),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TierPill(
            label: 'Classic',
            icon: Icons.style_outlined,
            isSelected: selectedTier == TableTier.classic,
            onTap: () => onSelect(TableTier.classic),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TierPill(
            label: 'High Stakes',
            icon: Icons.workspace_premium_outlined,
            isSelected: selectedTier == TableTier.highStakes,
            onTap: () => onSelect(TableTier.highStakes),
          ),
        ),
      ],
    );
  }
}

class _TierPill extends StatelessWidget {
  const _TierPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Material(
        color: isSelected ? AppColors.forestGreen : AppColors.inputFill,
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected ? AppColors.forestGreen : AppColors.inputBorder,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.forestGreen,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.forestGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

