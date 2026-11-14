import 'package:flutter/material.dart';

import '../../../../core/widgets/club_suit_painter.dart';
import '../../domain/entities/game_table_room.dart';

/// Custom-painted luxury card-room thumbnail for each table room card.
class TableRoomThumbnail extends StatelessWidget {
  const TableRoomThumbnail({
    super.key,
    required this.style,
  });

  final RoomThemeStyle style;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 72,
        height: 72,
        child: CustomPaint(
          painter: _RoomThumbnailPainter(style: style),
        ),
      ),
    );
  }
}

class _RoomThumbnailPainter extends CustomPainter {
  const _RoomThumbnailPainter({required this.style});

  final RoomThemeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final isIvory = style == RoomThemeStyle.ivory || style == RoomThemeStyle.royal;

    // Room backdrop
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isIvory
              ? const [Color(0xFFD6C9AE), Color(0xFF9E8E6E)]
              : const [Color(0xFF1B3F28), Color(0xFF0A1B10)],
        ).createShader(rect),
    );

    // Warm wall sconce glow
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.30),
      size.width * 0.32,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF6DFA2).withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // Wall emblem (club or crown)
    final emblemSize = size.width * 0.24;
    if (style == RoomThemeStyle.royal) {
      final crownPaint = Paint()
        ..color = const Color(0xFFE7CA7D)
        ..style = PaintingStyle.fill;
      final cx = size.width / 2;
      final cy = size.height * 0.30;
      final crown = Path()
        ..moveTo(cx - 10, cy + 5)
        ..lineTo(cx - 11, cy - 5)
        ..lineTo(cx - 4, cy + 1)
        ..lineTo(cx, cy - 7)
        ..lineTo(cx + 4, cy + 1)
        ..lineTo(cx + 11, cy - 5)
        ..lineTo(cx + 10, cy + 5)
        ..close();
      canvas.drawPath(crown, crownPaint);
    } else {
      canvas.save();
      canvas.translate(
        size.width / 2 - emblemSize / 2,
        size.height * 0.16,
      );
      ClubSuitPainter(
        color: isIvory ? const Color(0xFF3E3524) : const Color(0xFFE4C982),
      ).paint(canvas, Size.square(emblemSize));
      canvas.restore();
    }

    // Mini card table ellipse at bottom
    final tableRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.78),
      width: size.width * 0.84,
      height: size.height * 0.36,
    );
    canvas.drawOval(
      tableRect,
      Paint()
        ..color = isIvory
            ? const Color(0xFFEAE1CE)
            : const Color(0xFF1F5836),
    );
    canvas.drawOval(
      tableRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFFD6BA78),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomThumbnailPainter oldDelegate) {
    return oldDelegate.style != style;
  }
}

