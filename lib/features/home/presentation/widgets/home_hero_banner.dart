import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/club_suit_painter.dart';

/// Split hero banner featuring the dealer portrait on the left and the
/// "Your Teen Patti Club" call-to-action on the right.
class HomeHeroBanner extends StatelessWidget {
  const HomeHeroBanner({
    super.key,
    required this.onPlayNow,
  });

  final VoidCallback onPlayNow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = (constraints.maxWidth * 0.48).clamp(150.0, 220.0);
        final circleSize = imageWidth * 0.80;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: imageWidth,
              height: imageWidth * 0.94,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    bottom: imageWidth * 0.04,
                    child: Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.sageGreen.withValues(alpha: 0.48),
                            AppColors.forestGreen.withValues(alpha: 0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Image.asset(
                      AppAssets.splashCharacter,
                      width: imageWidth * 0.96,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    height: imageWidth * 0.16,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.creamBackground.withValues(alpha: 0.0),
                              AppColors.creamBackground,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your Teen Patti\nClub',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: ['Times New Roman', 'serif'],
                      fontSize: 23,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 1,
                        color: AppColors.forestGreen.withValues(alpha: 0.6),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CustomPaint(
                            painter: ClubSuitPainter(
                              color: AppColors.forestGreen,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 1,
                        color: AppColors.forestGreen.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: onPlayNow,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forestGreen,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text(
                        'Play Now',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

