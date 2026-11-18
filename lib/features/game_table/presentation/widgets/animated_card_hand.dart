import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Staggers each seat's cards flying/scaling into place when a new hand is dealt.
///
/// Uses an [Interval] curve on a single finite [AnimationController] so there
/// are no dangling timers during widget disposal or `flutter test` pump cycles.
class AnimatedDealIn extends StatefulWidget {
  const AnimatedDealIn({
    super.key,
    required this.roundKey,
    required this.seatIndex,
    required this.child,
    this.beginOffset = const Offset(0, -0.45),
  });

  final int roundKey;
  final int seatIndex;
  final Widget child;
  final Offset beginOffset;

  @override
  State<AnimatedDealIn> createState() => _AnimatedDealInState();
}

class _AnimatedDealInState extends State<AnimatedDealIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _initController();
    if (widget.roundKey > 0) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1.0;
    }
  }

  void _initController() {
    final delayMs = (widget.seatIndex.clamp(0, 6)) * 35;
    const baseMs = 220;
    final totalMs = delayMs + baseMs;
    final beginInterval = totalMs == 0 ? 0.0 : delayMs / totalMs;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(beginInterval, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedDealIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roundKey != widget.roundKey && widget.roundKey > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) {
        final t = _curved.value;
        final offset = Offset.lerp(widget.beginOffset, Offset.zero, t)!;
        final scale = 0.8 + 0.2 * t;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: FractionalTranslation(
            translation: offset,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Flips smoothly on the Y-axis between blind [hiddenChild] and seen [revealedChild].
class AnimatedCardRevealFlip extends StatefulWidget {
  const AnimatedCardRevealFlip({
    super.key,
    required this.isRevealed,
    required this.hiddenChild,
    required this.revealedChild,
    this.duration = const Duration(milliseconds: 280),
  });

  final bool isRevealed;
  final Widget hiddenChild;
  final Widget revealedChild;
  final Duration duration;

  @override
  State<AnimatedCardRevealFlip> createState() => _AnimatedCardRevealFlipState();
}

class _AnimatedCardRevealFlipState extends State<AnimatedCardRevealFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flip;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.isRevealed ? 1.0 : 0.0,
    );
    _flip = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedCardRevealFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.isRevealed == widget.isRevealed) return;
    if (widget.isRevealed) {
      _controller.forward(from: 0);
    } else {
      // New blind hand resets immediately before deal-in runs.
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final t = _flip.value;
        final angle = t * math.pi;
        final showingFront = t >= 0.5;
        final displayAngle = showingFront ? angle - math.pi : angle;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateY(displayAngle),
          child: showingFront ? widget.revealedChild : widget.hiddenChild,
        );
      },
    );
  }
}
