import 'package:flutter/material.dart';

/// Paints a balanced playing-card club suit (♣) centered within its bounds.
class ClubSuitPainter extends CustomPainter {
  const ClubSuitPainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final lobeRadius = w * 0.245;
    final topLobeCenter = Offset(cx, h * 0.26);
    final leftLobeCenter = Offset(cx - w * 0.23, h * 0.54);
    final rightLobeCenter = Offset(cx + w * 0.23, h * 0.54);

    final path = Path()
      ..addOval(Rect.fromCircle(center: topLobeCenter, radius: lobeRadius))
      ..addOval(Rect.fromCircle(center: leftLobeCenter, radius: lobeRadius))
      ..addOval(Rect.fromCircle(center: rightLobeCenter, radius: lobeRadius))
      ..addOval(
        Rect.fromCircle(
          center: Offset(cx, h * 0.48),
          radius: lobeRadius * 0.65,
        ),
      );

    final stemPath = Path()
      ..moveTo(cx - w * 0.04, h * 0.52)
      ..lineTo(cx + w * 0.04, h * 0.52)
      ..quadraticBezierTo(
        cx + w * 0.06,
        h * 0.78,
        cx + w * 0.16,
        h * 0.94,
      )
      ..lineTo(cx - w * 0.16, h * 0.94)
      ..quadraticBezierTo(
        cx - w * 0.06,
        h * 0.78,
        cx - w * 0.04,
        h * 0.52,
      )
      ..close();

    path.addPath(stemPath, Offset.zero);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ClubSuitPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

