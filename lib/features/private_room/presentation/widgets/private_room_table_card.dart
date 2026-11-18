import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/club_suit_painter.dart';
import '../../domain/entities/private_room_state.dart';

/// Horizontal oval Teen Patti table with champagne-gold rim and 6 player seats.
class PrivateRoomTableCard extends StatelessWidget {
  const PrivateRoomTableCard({
    super.key,
    required this.seats,
    required this.maxPlayers,
    required this.onInviteSlotTap,
  });

  final List<PrivateRoomSeat> seats;
  final int maxPlayers;
  final ValueChanged<int> onInviteSlotTap;

  @override
  Widget build(BuildContext context) {
    final visibleSeats = seats.take(maxPlayers).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const totalHeight = 250.0;
        const tableTop = 22.0;
        const tableHeight = 216.0;

        return SizedBox(
          width: w,
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Emerald-green felt oval table
              Positioned(
                left: 6,
                right: 6,
                top: tableTop,
                height: tableHeight,
                child: const CustomPaint(
                  painter: _HorizontalFeltTablePainter(),
                ),
              ),

              // Center Teen Patti Private Table emblem
              const Positioned(
                left: 0,
                right: 0,
                top: tableTop + 42,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CustomPaint(
                        painter: ClubSuitPainter(
                          color: Color(0x30FFFFFF),
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Teen Patti',
                      style: AppTextStyles.tableTitleWatermark,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Private Table',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xA6FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),

              // Seat 0: Top-Left (Host)
              if (visibleSeats.isNotEmpty)
                Positioned(
                  left: w * 0.19,
                  top: 0,
                  child: _SeatNode(
                    seat: visibleSeats[0],
                    onInviteTap: () => onInviteSlotTap(0),
                  ),
                ),

              // Seat 1: Top-Right
              if (visibleSeats.length > 1)
                Positioned(
                  right: w * 0.16,
                  top: 0,
                  child: _SeatNode(
                    seat: visibleSeats[1],
                    onInviteTap: () => onInviteSlotTap(1),
                  ),
                ),

              // Seat 2: Mid-Left
              if (visibleSeats.length > 2)
                Positioned(
                  left: 2,
                  top: tableTop + 56,
                  child: _SeatNode(
                    seat: visibleSeats[2],
                    onInviteTap: () => onInviteSlotTap(2),
                  ),
                ),

              // Seat 3: Mid-Right
              if (visibleSeats.length > 3)
                Positioned(
                  right: 2,
                  top: tableTop + 56,
                  child: _SeatNode(
                    seat: visibleSeats[3],
                    onInviteTap: () => onInviteSlotTap(3),
                  ),
                ),

              // Seat 4: Bottom-Left
              if (visibleSeats.length > 4)
                Positioned(
                  left: w * 0.24,
                  bottom: 24,
                  child: _SeatNode(
                    seat: visibleSeats[4],
                    onInviteTap: () => onInviteSlotTap(4),
                  ),
                ),

              // Seat 5: Bottom-Right
              if (visibleSeats.length > 5)
                Positioned(
                  right: w * 0.24,
                  bottom: 24,
                  child: _SeatNode(
                    seat: visibleSeats[5],
                    onInviteTap: () => onInviteSlotTap(5),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HorizontalFeltTablePainter extends CustomPainter {
  const _HorizontalFeltTablePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outerRadius = Radius.circular(size.height / 2);
    final outerRRect = RRect.fromRectAndRadius(rect, outerRadius);

    // Outer drop shadow
    canvas.drawRRect(
      outerRRect.shift(const Offset(0, 8)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Dark forest padded rail
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E4C2E),
            Color(0xFF10311C),
          ],
        ).createShader(rect),
    );

    // Champagne-gold inner rim
    final rimRect = rect.deflate(10);
    final rimRRect = RRect.fromRectAndRadius(
      rimRect,
      Radius.circular(rimRect.height / 2),
    );
    canvas.drawRRect(
      rimRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE5DCBF),
            Color(0xFFA79C79),
            Color(0xFFECE3C8),
            Color(0xFF8F8464),
          ],
        ).createShader(rimRect),
    );

    // Emerald radial felt interior
    final feltRect = rect.deflate(12);
    final feltRRect = RRect.fromRectAndRadius(
      feltRect,
      Radius.circular(feltRect.height / 2),
    );
    canvas.drawRRect(
      feltRRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.06),
          radius: 0.9,
          colors: [
            Color(0xFF215E3A),
            Color(0xFF164428),
            Color(0xFF0E2F1B),
          ],
        ).createShader(feltRect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SeatNode extends StatelessWidget {
  const _SeatNode({
    required this.seat,
    required this.onInviteTap,
  });

  final PrivateRoomSeat seat;
  final VoidCallback onInviteTap;

  @override
  Widget build(BuildContext context) {
    if (!seat.isOccupied) {
      return GestureDetector(
        onTap: onInviteTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 60,
          height: 60,
          child: CustomPaint(
            painter: const _DashedCirclePainter(),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                Text(
                  'Invite',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFECE9DF),
                border: Border.all(color: Colors.white, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  seat.avatarAsset!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            if (seat.isHost)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3CC60),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 13,
                    color: Color(0xFF28200D),
                  ),
                ),
              ),
            if (seat.isHost)
              Positioned(
                bottom: -4,
                right: -14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE2BA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFCBB87F),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'Host',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2B2210),
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 3, 6, 3),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                seat.playerName!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF14281D),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seat.isOnline
                      ? const Color(0xFF28A745)
                      : const Color(0xFFA0A49E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;
    const dashCount = 16;
    const dashAngle = (2 * math.pi) / dashCount;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        rect,
        i * dashAngle,
        dashAngle * 0.56,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
