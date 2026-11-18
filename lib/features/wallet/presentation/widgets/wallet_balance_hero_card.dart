import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/club_suit_painter.dart';

/// Dark emerald-green Current Balance banner card with stacked 3D poker chips.
class WalletBalanceHeroCard extends StatelessWidget {
  const WalletBalanceHeroCard({
    super.key,
    required this.balance,
  });

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F5732),
            Color(0xFF133F22),
            Color(0xFF0C2E17),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F351B).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current Balance',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '₹${formatIndianNumber(balance)}',
                          style: const TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                            height: 1.1,
                          ),
                        ),
                        const TextSpan(
                          text: ' Chips',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 108,
            height: 76,
            child: CustomPaint(
              painter: PokerChipStackPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints two overlapping stacks of 3D green-and-cream casino poker chips
/// bearing a centered dark forest-green club emblem.
class PokerChipStackPainter extends CustomPainter {
  const PokerChipStackPainter();

  void _drawChip(
    Canvas canvas, {
    required Offset center,
    required double rx,
    required double ry,
    required double thickness,
    required Color bodyColor,
    required Color edgeLight,
    required Color faceCream,
    required Color clubColor,
  }) {
    final sideRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + thickness / 2),
      width: rx * 2,
      height: ry * 2 + thickness,
    );

    // Chip cylindrical rim
    final rimPath = Path()
      ..moveTo(center.dx - rx, center.dy)
      ..lineTo(center.dx - rx, center.dy + thickness)
      ..arcTo(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + thickness),
          width: rx * 2,
          height: ry * 2,
        ),
        math.pi,
        -math.pi,
        false,
      )
      ..lineTo(center.dx + rx, center.dy)
      ..close();

    canvas.drawPath(
      rimPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            bodyColor.withValues(alpha: 0.85),
            bodyColor,
            const Color(0xFF0A2413),
          ],
        ).createShader(sideRect),
    );

    // Cream edge stripes along front rim
    const stripeOffsets = [-0.72, -0.25, 0.25, 0.72];
    for (final factor in stripeOffsets) {
      final sx = center.dx + rx * factor;
      final dyAtX = ry * math.sqrt((1 - factor * factor).clamp(0.0, 1.0));
      final stripePath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              sx - rx * 0.1,
              center.dy + dyAtX - 1.5,
              rx * 0.2,
              thickness + 1,
            ),
            const Radius.circular(1),
          ),
        );
      canvas.drawPath(stripePath, Paint()..color = edgeLight);
    }

    // Top oval base
    final topRect = Rect.fromCenter(
      center: center,
      width: rx * 2,
      height: ry * 2,
    );
    canvas.drawOval(topRect, Paint()..color = bodyColor);

    // Cream edge notches around top ellipse
    for (int i = 0; i < 8; i++) {
      final angle = i * (math.pi / 4) + 0.18;
      final p1 = Offset(
        center.dx + rx * 0.86 * math.cos(angle),
        center.dy + ry * 0.86 * math.sin(angle),
      );
      canvas.drawCircle(p1, rx * 0.12, Paint()..color = edgeLight);
    }

    // Re-mask inner ring with body color so notches look crisp on the border
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.48, height: ry * 1.48),
      Paint()..color = bodyColor,
    );

    // Inner cream medallion
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.18, height: ry * 1.18),
      Paint()..color = faceCream,
    );

    // Dashed/thin inner accent ring
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.02, height: ry * 1.02),
      Paint()
        ..color = bodyColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Club suit centered on chip face
    final clubW = rx * 0.56;
    final clubH = ry * 0.84;
    canvas.save();
    canvas.translate(center.dx - clubW / 2, center.dy - clubH / 2);
    ClubSuitPainter(color: clubColor).paint(canvas, Size(clubW, clubH));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft cast shadow on dark green card
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.52, h * 0.78),
        width: w * 0.92,
        height: h * 0.36,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    const body = Color(0xFF1F5431);
    const creamEdge = Color(0xFFE7DFCA);
    const faceCream = Color(0xFFF3EDE0);
    const club = Color(0xFF184426);

    // Right stack (3 chips)
    for (int i = 0; i < 3; i++) {
      _drawChip(
        canvas,
        center: Offset(w * 0.67, h * 0.56 - i * 9.5),
        rx: w * 0.28,
        ry: h * 0.22,
        thickness: 6.5,
        bodyColor: body,
        edgeLight: creamEdge,
        faceCream: faceCream,
        clubColor: club,
      );
    }

    // Front-left stack (2 chips)
    for (int i = 0; i < 2; i++) {
      _drawChip(
        canvas,
        center: Offset(w * 0.34, h * 0.69 - i * 8.5),
        rx: w * 0.28,
        ry: h * 0.22,
        thickness: 6.5,
        bodyColor: const Color(0xFF235D36),
        edgeLight: creamEdge,
        faceCream: faceCream,
        clubColor: club,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
