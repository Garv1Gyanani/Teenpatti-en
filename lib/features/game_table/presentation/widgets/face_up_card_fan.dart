import 'package:flutter/material.dart';

import '../../domain/entities/playing_card.dart';

/// Three fanned face-up playing cards with a subtle deal entrance and
/// tap-to-lift interaction.
class FaceUpCardFan extends StatefulWidget {
  const FaceUpCardFan({
    super.key,
    required this.cards,
  });

  final List<PlayingCard> cards;

  @override
  State<FaceUpCardFan> createState() => _FaceUpCardFanState();
}

class _FaceUpCardFanState extends State<FaceUpCardFan> {
  bool _isLifted = false;

  @override
  Widget build(BuildContext context) {
    const angles = [-0.14, 0.0, 0.14];
    const offsets = [Offset(-24, 3), Offset(0, 0), Offset(24, 3)];

    return GestureDetector(
      onTap: () => setState(() => _isLifted = !_isLifted),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isLifted ? -6 : 0, 0),
        width: 118,
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: List.generate(widget.cards.length.clamp(0, 3), (index) {
            final card = widget.cards[index];
            return Transform.translate(
              offset: offsets[index],
              child: Transform.rotate(
                angle: angles[index],
                child: _PlayingCardTile(card: card),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _PlayingCardTile extends StatelessWidget {
  const _PlayingCardTile({required this.card});

  final PlayingCard card;

  @override
  Widget build(BuildContext context) {
    final color =
        card.isRed ? const Color(0xFFD62828) : const Color(0xFF181C1A);

    return Container(
      width: 38,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFDCD8CD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.rank,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Center(
            child: Text(
              card.suitSymbol,
              style: TextStyle(
                fontSize: 18,
                height: 1.0,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
