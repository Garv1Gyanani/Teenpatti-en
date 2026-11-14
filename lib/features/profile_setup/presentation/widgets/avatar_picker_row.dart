import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/avatar_option.dart';

/// Horizontal row of circular avatar choices with selection ring & checkmark.
class AvatarPickerRow extends StatelessWidget {
  const AvatarPickerRow({
    super.key,
    required this.avatars,
    required this.selectedAvatarId,
    required this.onSelect,
  });

  final List<AvatarOption> avatars;
  final String selectedAvatarId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose an Avatar', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: avatars.map((avatar) {
            final isSelected = avatar.id == selectedAvatarId;
            return _AvatarCircleItem(
              avatar: avatar,
              isSelected: isSelected,
              onTap: () => onSelect(avatar.id),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AvatarCircleItem extends StatelessWidget {
  const _AvatarCircleItem({
    required this.avatar,
    required this.isSelected,
    required this.onTap,
  });

  final AvatarOption avatar;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 58,
            height: 58,
            padding: EdgeInsets.all(isSelected ? 2.5 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? AppColors.forestGreen
                    : AppColors.inputBorder.withValues(alpha: 0.7),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: ClipOval(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const RadialGradient(
                          colors: [
                            AppColors.avatarBackdropLight,
                            AppColors.forestGreen,
                          ],
                        )
                      : null,
                  color: isSelected ? null : AppColors.inputFill,
                ),
                child: Image.asset(
                  avatar.assetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.creamBackground,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

