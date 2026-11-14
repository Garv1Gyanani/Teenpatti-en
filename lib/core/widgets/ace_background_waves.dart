import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'club_suit_painter.dart';

/// Decorative top-left and bottom-right layered green waves with a subtle
/// club-suit watermark, shared across Ace Society onboarding screens.
class AceBackgroundWaves extends StatelessWidget {
  const AceBackgroundWaves({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _AceWavesPainter(),
      size: Size.infinite,
    );
  }
}

class _AceWavesPainter extends CustomPainter {
  const _AceWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final topSagePath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.44, 0)
      ..cubicTo(
        w * 0.30,
        h * 0.06,
        w * 0.16,
        h * 0.105,
        0,
        h * 0.135,
      )
      ..close();

    canvas.drawPath(
      topSagePath,
      Paint()..color = AppColors.sageGreen,
    );

    final topForestPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.32, 0)
      ..cubicTo(
        w * 0.22,
        h * 0.05,
        w * 0.12,
        h * 0.085,
        0,
        h * 0.108,
      )
      ..close();

    canvas.drawPath(
      topForestPath,
      Paint()..color = AppColors.forestGreen,
    );

    final bottomMutedPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.955)
      ..cubicTo(
        w * 0.25,
        h * 0.895,
        w * 0.48,
        h * 0.915,
        w * 0.72,
        h * 0.855,
      )
      ..lineTo(w, h * 0.85)
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(
      bottomMutedPath,
      Paint()..color = AppColors.mutedOliveGreen,
    );

    final bottomForestPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.968)
      ..cubicTo(
        w * 0.22,
        h * 0.945,
        w * 0.44,
        h * 0.92,
        w * 0.68,
        h * 0.838,
      )
      ..cubicTo(
        w * 0.83,
        h * 0.788,
        w * 0.93,
        h * 0.785,
        w,
        h * 0.798,
      )
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(
      bottomForestPath,
      Paint()..color = AppColors.forestGreen,
    );

    final clubSize = w * 0.34;
    canvas.save();
    canvas.translate(w * 0.63, h * 0.842);
    const ClubSuitPainter(color: AppColors.watermarkGreen)
        .paint(canvas, Size.square(clubSize));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

