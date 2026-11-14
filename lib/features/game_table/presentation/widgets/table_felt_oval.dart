import 'package:flutter/material.dart';

import '../../../../core/widgets/club_suit_painter.dart';

/// Draws the padded forest-green Teen Patti oval table with champagne-gold rim,
/// inner betting-ring pinstripe, and subtle club-suit felt watermark.
class TableFeltOval extends StatelessWidget {
  const TableFeltOval({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _TableFeltPainter(),
      size: Size.infinite,
    );
  }
}

class _TableFeltPainter extends CustomPainter {
  const _TableFeltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outerRadius = Radius.circular(size.width * 0.48);
    final outerRRect = RRect.fromRectAndRadius(rect, outerRadius);

    // Outer drop shadow
    canvas.drawRRect(
      outerRRect.shift(const Offset(0, 12)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Padded dark forest rail
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A3C27),
            Color(0xFF0C2014),
          ],
        ).createShader(rect),
    );

    // Subtle top rail highlight
    canvas.drawRRect(
      outerRRect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // Champagne-gold metallic rim
    final rimRect = rect.deflate(14);
    final rimRRect = RRect.fromRectAndRadius(
      rimRect,
      Radius.circular(rimRect.width * 0.48),
    );
    canvas.drawRRect(
      rimRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD8CEAC),
            Color(0xFF8C8263),
            Color(0xFFE6DDBF),
            Color(0xFF7B7255),
          ],
        ).createShader(rimRect),
    );

    // Inner emerald felt
    final feltRect = rect.deflate(17);
    final feltRRect = RRect.fromRectAndRadius(
      feltRect,
      Radius.circular(feltRect.width * 0.48),
    );
    canvas.drawRRect(
      feltRRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.08),
          radius: 0.80,
          colors: [
            Color(0xFF205838),
            Color(0xFF143D25),
            Color(0xFF0D2A19),
          ],
        ).createShader(feltRect),
    );

    // Inner casino betting-ring pinstripe
    final innerRingRect = feltRect.deflate(22);
    final innerRingRRect = RRect.fromRectAndRadius(
      innerRingRect,
      Radius.circular(innerRingRect.width * 0.48),
    );
    canvas.drawRRect(
      innerRingRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFD6CBA8).withValues(alpha: 0.16),
    );

    // Subtle club-suit watermark in the center of the felt
    final clubSize = size.width * 0.13;
    canvas.save();
    canvas.translate(
      size.width / 2 - clubSize / 2,
      size.height * 0.48 - clubSize / 2,
    );
    ClubSuitPainter(color: Colors.white.withValues(alpha: 0.055))
        .paint(canvas, Size.square(clubSize));
    canvas.restore();

    // Subtle "ACE SOCIETY" felt imprint below watermark
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'ACE SOCIETY',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 3.4,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height * 0.48 + clubSize * 0.56,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
