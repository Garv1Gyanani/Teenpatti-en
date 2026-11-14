import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/club_suit_painter.dart';

/// Ornamental club-suit divider placed between the tagline and action buttons.
class LandingClubDivider extends StatelessWidget {
  const LandingClubDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 1.0,
          color: AppColors.forestGreen.withValues(alpha: 0.75),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CustomPaint(
              painter: ClubSuitPainter(color: AppColors.forestGreen),
            ),
          ),
        ),
        Container(
          width: 48,
          height: 1.0,
          color: AppColors.forestGreen.withValues(alpha: 0.75),
        ),
      ],
    );
  }
}

