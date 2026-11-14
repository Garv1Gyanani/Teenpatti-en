import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/table_player.dart';
import 'face_down_card_fan.dart';

/// Displays an opponent seat (avatar, name/chips pill, optional dealer/gift
/// badge, and fanned face-down cards).
class OpponentSeatWidget extends StatelessWidget {
  const OpponentSeatWidget({
    super.key,
    required this.player,
  });

  final TablePlayer player;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: player.hasPacked ? 0.45 : 1.0,
      child: SizedBox(
        width: 138,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 12),
              child: Container(
                width: 110,
                padding: const EdgeInsets.fromLTRB(26, 6, 8, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E2116).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (player.hasGiftBadge)
                          Icon(
                            Icons.card_giftcard_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${formatCommaNumber(player.chips)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!player.hasPacked)
              const Positioned(
                left: 14,
                top: -12,
                child: FaceDownCardFan(),
              ),
            Positioned(
              left: 0,
              top: 10,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.creamBackground,
                      border: Border.all(
                        color: const Color(0xFFE7E2D5),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        player.avatarAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
                  if (player.isDealer)
                    Positioned(
                      right: -4,
                      bottom: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EFE4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1A3A27),
                            width: 1.2,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'D',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF142D1E),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Highlighted bottom-center seat for the local player with an animated turn
/// countdown ring around the avatar.
class LocalPlayerSeatWidget extends StatefulWidget {
  const LocalPlayerSeatWidget({
    super.key,
    required this.player,
  });

  final TablePlayer player;

  @override
  State<LocalPlayerSeatWidget> createState() => _LocalPlayerSeatWidgetState();
}

class _LocalPlayerSeatWidgetState extends State<LocalPlayerSeatWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turnController;

  @override
  void initState() {
    super.initState();
    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (widget.player.isActiveTurn && !widget.player.hasPacked) {
      _turnController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant LocalPlayerSeatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isTurn = widget.player.isActiveTurn && !widget.player.hasPacked;
    if (isTurn && !_turnController.isAnimating) {
      _turnController.repeat();
    } else if (!isTurn && _turnController.isAnimating) {
      _turnController.stop();
    }
  }

  @override
  void dispose() {
    _turnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTurn = widget.player.isActiveTurn && !widget.player.hasPacked;

    return Opacity(
      opacity: widget.player.hasPacked ? 0.65 : 1.0,
      child: SizedBox(
        width: 184,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Container(
                width: 152,
                padding: const EdgeInsets.fromLTRB(34, 6, 14, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E291A).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isTurn
                        ? const Color(0xFFA7EFC1)
                        : Colors.white.withValues(alpha: 0.25),
                    width: isTurn ? 1.6 : 1,
                  ),
                  boxShadow: isTurn
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7CE8A3)
                                .withValues(alpha: 0.28),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.player.hasPacked
                          ? '${widget.player.name} (Packed)'
                          : widget.player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${formatCommaNumber(widget.player.chips)}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              child: SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isTurn)
                      AnimatedBuilder(
                        animation: _turnController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size.square(60),
                            painter: _TurnRingPainter(
                              progress: 1.0 - _turnController.value,
                            ),
                          );
                        },
                      ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.creamBackground,
                        border: Border.all(
                          color: isTurn
                              ? const Color(0xFFA7EFC1)
                              : const Color(0xFFE7E2D5),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          widget.player.avatarAsset,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnRingPainter extends CustomPainter {
  const _TurnRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..color = progress > 0.3
          ? const Color(0xFF9DF0B8)
          : const Color(0xFFF2C96D);

    canvas.drawArc(
      rect.deflate(1.5),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TurnRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
