import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Overlaid non-blocking animation layer that flies chip tokens from acting seats
/// into the center pot on bets, and sweeps pot chips toward the winner on showdown.
class ChipFlightOverlay extends StatefulWidget {
  const ChipFlightOverlay({
    super.key,
    required this.roundNumber,
    required this.seatAnchors,
    required this.playerContributions,
    required this.isRoundOver,
    this.winnerPlayerId,
    this.potAnchor = const Alignment(0, -0.18),
  });

  final int roundNumber;
  final Map<String, Alignment> seatAnchors;
  final Map<String, int> playerContributions;
  final bool isRoundOver;
  final String? winnerPlayerId;
  final Alignment potAnchor;

  @override
  State<ChipFlightOverlay> createState() => _ChipFlightOverlayState();
}

class _ChipFlightOverlayState extends State<ChipFlightOverlay>
    with TickerProviderStateMixin {
  final List<_ChipFlight> _flights = <_ChipFlight>[];

  @override
  void didUpdateWidget(covariant ChipFlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final roundChanged = oldWidget.roundNumber != widget.roundNumber;
    if (roundChanged) {
      // Clear stale flights cleanly on fresh round transitions.
      _clearFlights();
    }

    // Launch a chip flight toward the center pot whenever any seat's
    // total round contribution increases, including fresh-round Boot bets.
    for (final entry in widget.playerContributions.entries) {
      final previous =
          roundChanged ? 0 : (oldWidget.playerContributions[entry.key] ?? 0);
      if (entry.value > previous) {
        final fromAnchor = widget.seatAnchors[entry.key];
        if (fromAnchor != null) {
          _launchFlight(
            from: fromAnchor,
            to: widget.potAnchor,
            duration: const Duration(milliseconds: 360),
            goldAccent: false,
          );
        }
      }
    }

    // Sweep a small celebratory burst of chips from pot to winner on round completion.
    if (!oldWidget.isRoundOver &&
        widget.isRoundOver &&
        widget.winnerPlayerId != null) {
      final toAnchor = widget.seatAnchors[widget.winnerPlayerId!];
      if (toAnchor != null) {
        for (var i = 0; i < 3; i++) {
          _launchFlight(
            from: widget.potAnchor,
            to: toAnchor,
            duration: Duration(milliseconds: 440 + i * 70),
            beginDelayFraction: i * 0.14,
            goldAccent: true,
          );
        }
      }
    }
  }

  void _launchFlight({
    required Alignment from,
    required Alignment to,
    required Duration duration,
    double beginDelayFraction = 0.0,
    required bool goldAccent,
  }) {
    if (_flights.length >= 10) {
      final oldest = _flights.removeAt(0);
      oldest.controller.dispose();
    }

    final controller = AnimationController(vsync: this, duration: duration);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        beginDelayFraction.clamp(0.0, 0.7),
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );

    final flight = _ChipFlight(
      from: from,
      to: to,
      goldAccent: goldAccent,
      controller: controller,
      animation: animation,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _flights.remove(flight);
        });
        flight.controller.dispose();
      }
    });

    setState(() {
      _flights.add(flight);
    });
    controller.forward();
  }

  void _clearFlights() {
    for (final flight in _flights) {
      flight.controller.dispose();
    }
    _flights.clear();
  }

  @override
  void dispose() {
    _clearFlights();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_flights.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return AnimatedBuilder(
            animation: Listenable.merge(
              _flights.map((f) => f.animation).toList(growable: false),
            ),
            builder: (context, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final flight in _flights)
                    _buildFlyingChip(flight, width, height),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFlyingChip(_ChipFlight flight, double width, double height) {
    final t = flight.animation.value;
    if (t <= 0) return const SizedBox.shrink();

    final start = Offset(
      (flight.from.x + 1) * 0.5 * width,
      (flight.from.y + 1) * 0.5 * height,
    );
    final end = Offset(
      (flight.to.x + 1) * 0.5 * width,
      (flight.to.y + 1) * 0.5 * height,
    );
    final arcLift = math.sin(t * math.pi) * 24.0;
    final pos = Offset.lerp(start, end, t)! - Offset(0, arcLift);
    final opacity = t < 0.85 ? 1.0 : ((1.0 - t) / 0.15).clamp(0.0, 1.0);
    final scale = 0.85 + 0.25 * math.sin(t * math.pi);

    return Positioned(
      left: pos.dx - 11,
      top: pos.dy - 11,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: flight.goldAccent
                  ? const Color(0xFFD8B252)
                  : const Color(0xFF285F3C),
              border: Border.all(
                color: const Color(0xFFF6F2E7),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF6F2E7).withValues(alpha: 0.8),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipFlight {
  _ChipFlight({
    required this.from,
    required this.to,
    required this.goldAccent,
    required this.controller,
    required this.animation,
  });

  final Alignment from;
  final Alignment to;
  final bool goldAccent;
  final AnimationController controller;
  final Animation<double> animation;
}
