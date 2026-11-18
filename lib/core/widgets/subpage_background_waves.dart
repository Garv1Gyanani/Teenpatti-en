import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Decorative layered forest-green and sage-green curved corner waves used across
/// secondary Ace Society screens (Settings, Wallet, Profile, Rewards, Private Room, Friends).
class SubpageBackgroundWaves extends StatelessWidget {
  const SubpageBackgroundWaves({
    super.key,
    this.showBottomWaves = true,
  });

  final bool showBottomWaves;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SubpageWavesPainter(showBottomWaves: showBottomWaves),
      size: Size.infinite,
    );
  }
}

/// Paints the compact top-left curved wave and optional bottom-right wave.
class SubpageWavesPainter extends CustomPainter {
  const SubpageWavesPainter({
    this.showBottomWaves = true,
  });

  final bool showBottomWaves;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top-left pale sage outer crescent
    final topSagePath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.345, 0)
      ..cubicTo(
        w * 0.24,
        h * 0.048,
        w * 0.12,
        h * 0.088,
        0,
        h * 0.114,
      )
      ..close();

    canvas.drawPath(
      topSagePath,
      Paint()..color = const Color(0xFFB3C5B6),
    );

    // Top-left rich forest green inner curve
    final topForestPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.265, 0)
      ..cubicTo(
        w * 0.185,
        h * 0.044,
        w * 0.095,
        h * 0.078,
        0,
        h * 0.10,
      )
      ..close();

    canvas.drawPath(
      topForestPath,
      Paint()..color = AppColors.forestGreen,
    );

    if (!showBottomWaves) return;

    // Bottom-right pale sage outer curve
    final bottomSagePath = Path()
      ..moveTo(w * 0.56, h)
      ..cubicTo(
        w * 0.72,
        h * 0.968,
        w * 0.88,
        h * 0.972,
        w,
        h * 0.938,
      )
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(
      bottomSagePath,
      Paint()..color = const Color(0xFFB7C9BA),
    );

    // Bottom-right dark forest green inner curve
    final bottomForestPath = Path()
      ..moveTo(w * 0.65, h)
      ..cubicTo(
        w * 0.78,
        h * 0.985,
        w * 0.91,
        h * 0.974,
        w,
        h * 0.952,
      )
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(
      bottomForestPath,
      Paint()..color = AppColors.forestGreen,
    );
  }

  @override
  bool shouldRepaint(covariant SubpageWavesPainter oldDelegate) {
    return oldDelegate.showBottomWaves != showBottomWaves;
  }
}
