import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';

/// Displays the circular forest-green emblem with the Ace Society character
/// softly fading into the cream background at the bottom edge.
class LandingHeroEmblem extends StatelessWidget {
  const LandingHeroEmblem({
    super.key,
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final circleSize = size * 0.86;

    return SizedBox(
      width: size,
      height: size * 0.98,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: size * 0.04,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                color: AppColors.forestGreen,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Image.asset(
              AppAssets.splashCharacter,
              width: size * 0.94,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            height: size * 0.22,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.creamBackground.withValues(alpha: 0.0),
                      AppColors.creamBackground.withValues(alpha: 0.72),
                      AppColors.creamBackground,
                    ],
                    stops: const [0.0, 0.58, 1.0],
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

