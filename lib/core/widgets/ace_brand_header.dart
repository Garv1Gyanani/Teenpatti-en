import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'club_suit_painter.dart';

/// Displays the club suit emblem, "ACE SOCIETY" title, and "TEEN PATTI"
/// subtitle flanked by horizontal rules.
class AceBrandHeader extends StatelessWidget {
  const AceBrandHeader({
    super.key,
    this.clubSize = 28,
    this.titleStyle,
  });

  final double clubSize;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: clubSize,
          height: clubSize,
          child: const CustomPaint(
            painter: ClubSuitPainter(color: AppColors.forestGreen),
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'ACE SOCIETY',
            style: titleStyle ?? AppTextStyles.brandTitle,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 1.2,
              color: AppColors.forestGreen,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'TEEN PATTI',
                style: AppTextStyles.brandSubtitle,
              ),
            ),
            Container(
              width: 44,
              height: 1.2,
              color: AppColors.forestGreen,
            ),
          ],
        ),
      ],
    );
  }
}

