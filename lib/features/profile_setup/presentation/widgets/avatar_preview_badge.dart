import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Circular preview of the currently selected avatar with a radial green
/// backdrop and a bottom-right edit badge.
class AvatarPreviewBadge extends StatelessWidget {
  const AvatarPreviewBadge({
    super.key,
    required this.assetPath,
    required this.onEditTap,
    this.diameter = 132,
  });

  final String assetPath;
  final VoidCallback onEditTap;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 0.72,
                colors: [
                  AppColors.avatarBackdropLight,
                  AppColors.forestGreen,
                ],
              ),
            ),
            child: ClipOval(
              child: Padding(
                padding: EdgeInsets.only(top: diameter * 0.08),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.inputBorder, width: 1),
              ),
              elevation: 2,
              shadowColor: Colors.black26,
              child: InkWell(
                onTap: onEditTap,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

