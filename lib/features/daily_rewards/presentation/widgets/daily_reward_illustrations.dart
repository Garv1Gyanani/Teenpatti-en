import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/club_suit_painter.dart';

/// Paints the centered 3D cream gift box with dark forest-green ribbon & bow,
/// club emblem on front, stacked poker chips beside it, and golden sparkle lines.
class DailyRewardHeroIllustration extends StatelessWidget {
  const DailyRewardHeroIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 240,
      height: 152,
      child: CustomPaint(
        painter: _DailyRewardHeroPainter(),
      ),
    );
  }
}

class _DailyRewardHeroPainter extends CustomPainter {
  const _DailyRewardHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Warm oval ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.86),
        width: w * 0.86,
        height: h * 0.19,
      ),
      Paint()..color = const Color(0xFFEBE5D5),
    );

    // Subtle golden sparkle burst strokes
    final sparkPaint = Paint()
      ..color = const Color(0xFFE2AE3B)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.16, h * 0.34),
      Offset(w * 0.23, h * 0.40),
      sparkPaint,
    );
    canvas.drawLine(
      Offset(w * 0.21, h * 0.22),
      Offset(w * 0.26, h * 0.29),
      sparkPaint,
    );
    canvas.drawLine(
      Offset(w * 0.82, h * 0.22),
      Offset(w * 0.77, h * 0.30),
      sparkPaint,
    );
    canvas.drawLine(
      Offset(w * 0.87, h * 0.35),
      Offset(w * 0.80, h * 0.40),
      sparkPaint,
    );

    // Gift box geometry (3/4 perspective)
    final pTop = Offset(w * 0.55, h * 0.20);
    final pLeft = Offset(w * 0.35, h * 0.30);
    final pFrontTop = Offset(w * 0.52, h * 0.41);
    final pRight = Offset(w * 0.76, h * 0.30);

    final pLeftBottom = Offset(w * 0.36, h * 0.72);
    final pFrontBottom = Offset(w * 0.52, h * 0.83);
    final pRightBottom = Offset(w * 0.74, h * 0.72);

    // Box left face
    final leftFace = Path()
      ..moveTo(pLeft.dx, pLeft.dy)
      ..lineTo(pFrontTop.dx, pFrontTop.dy)
      ..lineTo(pFrontBottom.dx, pFrontBottom.dy)
      ..lineTo(pLeftBottom.dx, pLeftBottom.dy)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = const Color(0xFFEBDDC1));

    // Box right face
    final rightFace = Path()
      ..moveTo(pFrontTop.dx, pFrontTop.dy)
      ..lineTo(pRight.dx, pRight.dy)
      ..lineTo(pRightBottom.dx, pRightBottom.dy)
      ..lineTo(pFrontBottom.dx, pFrontBottom.dy)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = const Color(0xFFF6EBD4));

    // Box top lid face
    final topFace = Path()
      ..moveTo(pTop.dx, pTop.dy)
      ..lineTo(pRight.dx, pRight.dy)
      ..lineTo(pFrontTop.dx, pFrontTop.dy)
      ..lineTo(pLeft.dx, pLeft.dy)
      ..close();
    canvas.drawPath(topFace, Paint()..color = const Color(0xFFFAF2DF));

    // Slight lid overhang line
    canvas.drawLine(
      pLeft,
      pFrontTop,
      Paint()
        ..color = const Color(0xFFD5C5A3)
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      pFrontTop,
      pRight,
      Paint()
        ..color = const Color(0xFFD5C5A3)
        ..strokeWidth = 1.2,
    );

    const ribbonDark = Color(0xFF154726);
    const ribbonMid = Color(0xFF1E5B32);

    // Vertical ribbon on left face
    final leftRibbon = Path()
      ..moveTo(w * 0.42, h * 0.345)
      ..lineTo(w * 0.46, h * 0.37)
      ..lineTo(w * 0.46, h * 0.79)
      ..lineTo(w * 0.42, h * 0.76)
      ..close();
    canvas.drawPath(leftRibbon, Paint()..color = ribbonDark);

    // Vertical ribbon on right face
    final rightRibbon = Path()
      ..moveTo(w * 0.62, h * 0.36)
      ..lineTo(w * 0.665, h * 0.34)
      ..lineTo(w * 0.655, h * 0.76)
      ..lineTo(w * 0.615, h * 0.785)
      ..close();
    canvas.drawPath(rightRibbon, Paint()..color = ribbonMid);

    // Cross ribbon bands across top lid
    final topRibbon1 = Path()
      ..moveTo(w * 0.42, h * 0.345)
      ..lineTo(w * 0.64, h * 0.24)
      ..lineTo(w * 0.68, h * 0.26)
      ..lineTo(w * 0.46, h * 0.37)
      ..close();
    canvas.drawPath(topRibbon1, Paint()..color = ribbonMid);

    final topRibbon2 = Path()
      ..moveTo(w * 0.44, h * 0.255)
      ..lineTo(w * 0.485, h * 0.233)
      ..lineTo(w * 0.665, h * 0.34)
      ..lineTo(w * 0.62, h * 0.36)
      ..close();
    canvas.drawPath(topRibbon2, Paint()..color = ribbonMid);

    // Club suit emblem on front-right panel (centered around x=0.635? Wait: on left-front panel in screenshot!)
    // Actually in Image 4, the club emblem sits centered on the left face! Wait: let's look closely at Image 4:
    // Left face has the club suit, AND ribbon runs down left-center & right-center!
    // Let's draw a crisp club suit on the right face (brighter face) so it's super clean and unclipped:
    canvas.save();
    canvas.translate(w * 0.545, h * 0.53);
    const ClubSuitPainter(color: ribbonDark).paint(
      canvas,
      const Size(22, 22),
    );
    canvas.restore();

    // Sculpted ribbon bow on top of the lid
    final bowCenter = Offset(w * 0.555, h * 0.27);
    final leftBowLoop = Path()
      ..moveTo(bowCenter.dx, bowCenter.dy)
      ..cubicTo(
        bowCenter.dx - 26,
        bowCenter.dy - 28,
        bowCenter.dx - 38,
        bowCenter.dy - 4,
        bowCenter.dx - 10,
        bowCenter.dy + 4,
      )
      ..close();
    canvas.drawPath(leftBowLoop, Paint()..color = ribbonMid);

    final rightBowLoop = Path()
      ..moveTo(bowCenter.dx, bowCenter.dy)
      ..cubicTo(
        bowCenter.dx + 22,
        bowCenter.dy - 30,
        bowCenter.dx + 38,
        bowCenter.dy - 8,
        bowCenter.dx + 12,
        bowCenter.dy + 4,
      )
      ..close();
    canvas.drawPath(rightBowLoop, Paint()..color = ribbonDark);

    // Inner loop highlights
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bowCenter.dx - 16, bowCenter.dy - 8),
        width: 12,
        height: 7,
      ),
      Paint()..color = const Color(0xFF0E331A),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bowCenter.dx + 16, bowCenter.dy - 8),
        width: 12,
        height: 7,
      ),
      Paint()..color = const Color(0xFF0E331A),
    );

    // Center bow knot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: bowCenter, width: 14, height: 11),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF236639),
    );

    // Poker chips stacked beside the gift box on the left
    const chipGreen = Color(0xFF1D5631);
    const chipCream = Color(0xFFF3EBDA);

    // Tall back stack (3 chips)
    for (int i = 0; i < 3; i++) {
      _drawSingleChip(
        canvas,
        center: Offset(w * 0.34, h * 0.72 - i * 8.5),
        rx: 22,
        ry: 9.5,
        bodyColor: chipGreen,
        creamColor: chipCream,
      );
    }

    // Flat left chip
    _drawSingleChip(
      canvas,
      center: Offset(w * 0.225, h * 0.805),
      rx: 21,
      ry: 9,
      bodyColor: const Color(0xFF226137),
      creamColor: chipCream,
    );

    // Front overlapping chip
    _drawSingleChip(
      canvas,
      center: Offset(w * 0.385, h * 0.835),
      rx: 22,
      ry: 9.5,
      bodyColor: const Color(0xFF1A4E2C),
      creamColor: chipCream,
    );
  }

  void _drawSingleChip(
    Canvas canvas, {
    required Offset center,
    required double rx,
    required double ry,
    required Color bodyColor,
    required Color creamColor,
  }) {
    const thickness = 5.5;

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

    canvas.drawPath(rimPath, Paint()..color = const Color(0xFF10331C));

    for (final factor in [-0.65, 0.0, 0.65]) {
      final sx = center.dx + rx * factor;
      final dy = ry * math.sqrt((1 - factor * factor).clamp(0.0, 1.0));
      canvas.drawRect(
        Rect.fromLTWH(sx - 2.5, center.dy + dy - 1, 5, thickness),
        Paint()..color = creamColor,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      Paint()..color = bodyColor,
    );

    for (int i = 0; i < 8; i++) {
      final a = i * (math.pi / 4) + 0.2;
      canvas.drawCircle(
        Offset(
          center.dx + rx * 0.84 * math.cos(a),
          center.dy + ry * 0.84 * math.sin(a),
        ),
        2.3,
        Paint()..color = creamColor,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.46, height: ry * 1.46),
      Paint()..color = bodyColor,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.15, height: ry * 1.15),
      Paint()..color = creamColor,
    );

    canvas.save();
    canvas.translate(center.dx - rx * 0.26, center.dy - ry * 0.40);
    ClubSuitPainter(color: bodyColor)
        .paint(canvas, Size(rx * 0.52, ry * 0.80));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small poker chip pair (green or golden grand-bonus stack) used inside Day 4-7 cards.
class RewardCardChipsIllustration extends StatelessWidget {
  const RewardCardChipsIllustration({
    super.key,
    this.isGold = false,
  });

  final bool isGold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 36,
      child: CustomPaint(
        painter: _RewardCardChipsPainter(isGold: isGold),
      ),
    );
  }
}

class _RewardCardChipsPainter extends CustomPainter {
  const _RewardCardChipsPainter({required this.isGold});

  final bool isGold;

  void _paintMiniChip(
    Canvas canvas, {
    required Offset center,
    required double rx,
    required double ry,
    required Color bodyColor,
    required Color darkColor,
    required Color creamColor,
  }) {
    const t = 3.5;
    final rim = Path()
      ..moveTo(center.dx - rx, center.dy)
      ..lineTo(center.dx - rx, center.dy + t)
      ..arcTo(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + t),
          width: rx * 2,
          height: ry * 2,
        ),
        math.pi,
        -math.pi,
        false,
      )
      ..lineTo(center.dx + rx, center.dy)
      ..close();
    canvas.drawPath(rim, Paint()..color = darkColor);

    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      Paint()..color = bodyColor,
    );
    for (int i = 0; i < 6; i++) {
      final a = i * (math.pi / 3);
      canvas.drawCircle(
        Offset(
          center.dx + rx * 0.82 * math.cos(a),
          center.dy + ry * 0.82 * math.sin(a),
        ),
        1.5,
        Paint()..color = creamColor,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.4, height: ry * 1.4),
      Paint()..color = bodyColor,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.05, height: ry * 1.05),
      Paint()..color = creamColor,
    );
    canvas.save();
    canvas.translate(center.dx - rx * 0.25, center.dy - ry * 0.36);
    ClubSuitPainter(color: darkColor)
        .paint(canvas, Size(rx * 0.5, ry * 0.72));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (isGold) {
      const goldBody = Color(0xFFD0982A);
      const goldDark = Color(0xFF9C6D14);
      const cream = Color(0xFFFFF4DC);

      // Left stack (3 gold chips)
      for (int i = 0; i < 3; i++) {
        _paintMiniChip(
          canvas,
          center: Offset(w * 0.32, h * 0.66 - i * 5.0),
          rx: 12,
          ry: 5.5,
          bodyColor: goldBody,
          darkColor: goldDark,
          creamColor: cream,
        );
      }
      // Right taller stack (4 gold chips)
      for (int i = 0; i < 4; i++) {
        _paintMiniChip(
          canvas,
          center: Offset(w * 0.68, h * 0.64 - i * 5.0),
          rx: 12.5,
          ry: 5.8,
          bodyColor: const Color(0xFFDEA635),
          darkColor: goldDark,
          creamColor: cream,
        );
      }
      // Front single chip
      _paintMiniChip(
        canvas,
        center: Offset(w * 0.48, h * 0.77),
        rx: 11.5,
        ry: 5.2,
        bodyColor: goldBody,
        darkColor: goldDark,
        creamColor: cream,
      );
      return;
    }

    const greenBody = Color(0xFF1F5832);
    const greenDark = Color(0xFF11381F);
    const cream = Color(0xFFF3EBDA);

    _paintMiniChip(
      canvas,
      center: Offset(w * 0.62, h * 0.45),
      rx: 13.5,
      ry: 6.5,
      bodyColor: greenBody,
      darkColor: greenDark,
      creamColor: cream,
    );
    _paintMiniChip(
      canvas,
      center: Offset(w * 0.38, h * 0.63),
      rx: 13.5,
      ry: 6.5,
      bodyColor: const Color(0xFF25663A),
      darkColor: greenDark,
      creamColor: cream,
    );
  }

  @override
  bool shouldRepaint(covariant _RewardCardChipsPainter oldDelegate) {
    return oldDelegate.isGold != isGold;
  }
}
