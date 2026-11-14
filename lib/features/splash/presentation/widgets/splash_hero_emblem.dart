import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';

/// Displays the circular forest-green emblem with the Ace Society character
/// emerging from the top and smoothly clipped along a gentle convex arc at the
/// bottom.
class SplashHeroEmblem extends StatelessWidget {
  const SplashHeroEmblem({
    super.key,
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final circleSize = size * 0.88;
    final imageSize = size;

    return ClipPath(
      clipper: const _BottomConvexArcClipper(),
      child: SizedBox(
        width: imageSize,
        height: imageSize * 0.96,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: imageSize * 0.03,
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
                width: imageSize * 0.94,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomConvexArcClipper extends CustomClipper<Path> {
  const _BottomConvexArcClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.96)
      ..quadraticBezierTo(w * 0.5, h * 0.80, 0, h * 0.96)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

