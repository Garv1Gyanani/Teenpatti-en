import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Smooth animated circular loader matching the Ace Society splash aesthetic.
class SplashLoadingIndicator extends StatefulWidget {
  const SplashLoadingIndicator({
    super.key,
    this.size = 34,
    this.strokeWidth = 3.2,
  });

  final double size;
  final double strokeWidth;

  @override
  State<SplashLoadingIndicator> createState() => _SplashLoadingIndicatorState();
}

class _SplashLoadingIndicatorState extends State<SplashLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _SplashLoaderPainter(
              progress: _controller.value,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _SplashLoaderPainter extends CustomPainter {
  const _SplashLoaderPainter({
    required this.progress,
    required this.strokeWidth,
  });

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = AppColors.loaderTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = AppColors.forestGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final startAngle = (progress * 2 * math.pi) - math.pi / 2;
    const sweepAngle = math.pi * 1.15;

    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SplashLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

