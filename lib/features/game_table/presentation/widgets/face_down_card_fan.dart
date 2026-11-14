import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three fanned face-down cards displayed above opponent seats.
class FaceDownCardFan extends StatelessWidget {
  const FaceDownCardFan({
    super.key,
    this.cardWidth = 22,
    this.cardHeight = 32,
  });

  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    const angles = [-0.20, 0.0, 0.20];
    const offsets = [Offset(-10, 2), Offset(0, 0), Offset(10, 2)];

    return SizedBox(
      width: cardWidth * 2.1,
      height: cardHeight + 6,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (index) {
          return Transform.translate(
            offset: offsets[index],
            child: Transform.rotate(
              angle: angles[index] * math.pi / 2,
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF214A35),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFFE7E2D5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(2.2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

