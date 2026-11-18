import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/audio/app_audio_cue.dart';
import '../../../../core/audio/app_audio_service.dart';
import '../../../../core/audio/app_haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/animated_number_text.dart';
import '../../domain/entities/table_player.dart';
import 'animated_card_hand.dart';
import 'face_down_card_fan.dart';
import 'face_up_card_fan.dart';

/// Displays an opponent seat (avatar, name/chips pill, optional dealer/gift
/// badge, live action badge, fanned cards, and floating chat reaction bubble).
class OpponentSeatWidget extends StatelessWidget {
  const OpponentSeatWidget({
    super.key,
    required this.player,
    this.revealCards = false,
    this.reactionText,
    this.roundNumber = 0,
    this.seatIndex = 0,
    this.dealFromOffset = const Offset(0, 0.35),
  });

  final TablePlayer player;
  final bool revealCards;
  final String? reactionText;
  final int roundNumber;
  final int seatIndex;
  final Offset dealFromOffset;

  @override
  Widget build(BuildContext context) {
    final isTurn = player.isActiveTurn && !player.hasPacked;
    final showRevealedFan =
        revealCards && !player.hasPacked && player.cards.length == 3;
    final actionBadge = player.lastActionText ??
        (player.hasPacked
            ? 'Packed'
            : (player.hasSeenCards ? 'Seen' : 'Blind'));
    final rawCalloutAction = player.lastActionText;
    final calloutTriggerKey =
        '$roundNumber|${player.id}|$rawCalloutAction|${player.totalBet}|${player.hasPacked}|${player.hasSeenCards}';

    return SizedBox(
      width: 138,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: player.hasPacked ? 0.48 : 1.0,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 12),
              child: Container(
                width: 112,
                padding: const EdgeInsets.fromLTRB(26, 6, 8, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E2116).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isTurn
                        ? const Color(0xFF9DE6A8)
                        : Colors.white.withValues(alpha: 0.16),
                    width: isTurn ? 1.8 : 1,
                  ),
                  boxShadow: isTurn
                      ? [
                          BoxShadow(
                            color: const Color(0xFF8BE29B)
                                .withValues(alpha: 0.36),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
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
                            style: AppTextStyles.playerName.copyWith(
                              fontSize: 12.5,
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
                    AnimatedNumberText(
                      value: player.chips,
                      prefix: '₹',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.chipBalance.copyWith(
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.9, end: 1.0)
                              .animate(animation),
                          child: child,
                        ),
                      ),
                      child: Align(
                        key: ValueKey<String>(actionBadge),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          actionBadge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isTurn
                                ? const Color(0xFF9DE6A8)
                                : const Color(0xFFD5E4D8),
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!player.hasPacked)
              Positioned(
                left: showRevealedFan ? 6 : 14,
                top: showRevealedFan ? -20 : -12,
                child: AnimatedDealIn(
                  roundKey: roundNumber,
                  seatIndex: seatIndex,
                  beginOffset: dealFromOffset,
                  child: AnimatedCardRevealFlip(
                    isRevealed: showRevealedFan,
                    hiddenChild: const FaceDownCardFan(),
                    revealedChild: player.cards.length == 3
                        ? SizedBox(
                            width: 54,
                            height: 30,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: FaceUpCardFan(cards: player.cards),
                            ),
                          )
                        : const FaceDownCardFan(),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              top: 12,
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
                        color: isTurn
                            ? const Color(0xFF9DE6A8)
                            : const Color(0xFFE7E2D5),
                        width: isTurn ? 2.4 : 2,
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
          if (reactionText != null)
            Positioned(
              right: 0,
              top: -18,
              child: _SeatReactionBubble(text: reactionText!),
            )
          else if (rawCalloutAction != null &&
              rawCalloutAction.trim().isNotEmpty)
            Positioned(
              right: 2,
              top: -20,
              child: IgnorePointer(
                child: _SeatActionCalloutPill(
                  rawAction: rawCalloutAction,
                  triggerKey: calloutTriggerKey,
                ),
              ),
            ),
        ],
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
    this.reactionText,
    this.roundNumber = 0,
    this.turnDuration = const Duration(seconds: 15),
    this.turnGeneration = 0,
    this.isTimerPaused = false,
    this.enableTimerRing = true,
  });

  final TablePlayer player;
  final String? reactionText;
  final int roundNumber;
  final Duration turnDuration;
  final int turnGeneration;
  final bool isTimerPaused;
  final bool enableTimerRing;

  @override
  State<LocalPlayerSeatWidget> createState() => _LocalPlayerSeatWidgetState();
}

class _LocalPlayerSeatWidgetState extends State<LocalPlayerSeatWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turnController;
  bool _warnedForTurn = false;

  bool get _isTurn =>
      widget.enableTimerRing &&
      widget.player.isActiveTurn &&
      !widget.player.hasPacked;

  @override
  void initState() {
    super.initState();
    _turnController = AnimationController(
      vsync: this,
      duration: widget.turnDuration,
    )..addListener(_onTurnProgressTick);
    if (_isTurn && !widget.isTimerPaused) {
      _turnController.forward(from: 0.0);
    }
  }

  void _onTurnProgressTick() {
    if (!_isTurn || widget.isTimerPaused || _warnedForTurn) return;
    final totalSeconds =
        math.max(1.0, widget.turnDuration.inMilliseconds / 1000.0);
    final crimsonThreshold = math.min(5.0, totalSeconds * 0.45);
    final remainingSeconds = (1.0 - _turnController.value) * totalSeconds;
    if (_turnController.isAnimating && remainingSeconds <= crimsonThreshold) {
      _warnedForTurn = true;
      AppAudioService.instance.play(AppAudioCue.timerWarn);
      AppHapticService.light();
    }
  }

  @override
  void didUpdateWidget(covariant LocalPlayerSeatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_turnController.duration != widget.turnDuration) {
      _turnController.duration = widget.turnDuration;
    }

    final wasTurn = oldWidget.enableTimerRing &&
        oldWidget.player.isActiveTurn &&
        !oldWidget.player.hasPacked;
    final isTurn = _isTurn;
    final generationChanged = oldWidget.turnGeneration != widget.turnGeneration;

    if (!isTurn) {
      _warnedForTurn = false;
      if (_turnController.isAnimating) {
        _turnController.stop();
      }
      _turnController.value = 0.0;
    } else if (widget.isTimerPaused) {
      if (_turnController.isAnimating) {
        _turnController.stop();
      }
    } else if (!wasTurn || generationChanged) {
      _warnedForTurn = false;
      _turnController.forward(from: 0.0);
    } else if (oldWidget.isTimerPaused && !_turnController.isAnimating) {
      if (_turnController.value < 1.0) {
        _turnController.forward();
      }
    }
  }

  @override
  void dispose() {
    _turnController.removeListener(_onTurnProgressTick);
    _turnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTurn = widget.player.isActiveTurn && !widget.player.hasPacked;
    final rawCalloutAction = widget.player.lastActionText;
    final calloutTriggerKey =
        '${widget.roundNumber}|${widget.player.id}|$rawCalloutAction|${widget.player.totalBet}|${widget.player.hasPacked}|${widget.player.hasSeenCards}';

    return SizedBox(
      width: 184,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: widget.player.hasPacked ? 0.65 : 1.0,
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
                      style: AppTextStyles.playerName.copyWith(
                        fontSize: 13.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedNumberText(
                      value: widget.player.chips,
                      prefix: '₹',
                      style: AppTextStyles.chipBalance.copyWith(
                        fontSize: 14.5,
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
                    if (_isTurn)
                      AnimatedBuilder(
                        animation: _turnController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size.square(60),
                            painter: _TurnRingPainter(
                              progress: 1.0 - _turnController.value,
                              turnDuration: widget.turnDuration,
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
          if (widget.reactionText != null)
            Positioned(
              right: 0,
              top: -26,
              child: _SeatReactionBubble(text: widget.reactionText!),
            )
          else if (rawCalloutAction != null &&
              rawCalloutAction.trim().isNotEmpty)
            Positioned(
              right: 2,
              top: -26,
              child: IgnorePointer(
                child: _SeatActionCalloutPill(
                  rawAction: rawCalloutAction,
                  triggerKey: calloutTriggerKey,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Formats a table player's last action label into a concise uppercase callout.
String formatSeatActionCallout(String rawAction) {
  final trimmed = rawAction.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed == 'Packed') return 'PACK';
  if (trimmed == 'Auto-Packed') return 'AUTO PACK';
  if (trimmed == 'Side Show Won') return 'WON SHOW';
  if (trimmed == 'Side Show Lost') return 'LOST SHOW';
  if (trimmed == 'Declined Show') return 'DECLINED';
  return trimmed.replaceAll(' ₹', ' +').replaceAll('₹', '+').toUpperCase();
}

/// Returns the turn countdown arc color for [progress] (`1.0 -> 0.0`):
/// emerald-gold while > 9s remain, amber <= 9s, and crimson <= 5s.
Color turnRingColorForProgress(double progress, Duration turnDuration) {
  final totalSeconds =
      math.max(1.0, turnDuration.inMilliseconds / 1000.0);
  final remainingSeconds = progress.clamp(0.0, 1.0) * totalSeconds;
  final crimsonThreshold = math.min(5.0, totalSeconds * 0.45);
  final amberThreshold =
      math.max(crimsonThreshold + 1.5, math.min(9.0, totalSeconds * 0.62));
  if (remainingSeconds <= crimsonThreshold) {
    return const Color(0xFFE55353);
  }
  if (remainingSeconds <= amberThreshold) {
    return const Color(0xFFF2C96D);
  }
  return const Color(0xFF9DF0B8);
}

/// Auto-fading floating action callout pill displayed briefly above a seat.
class _SeatActionCalloutPill extends StatefulWidget {
  const _SeatActionCalloutPill({
    required this.rawAction,
    required this.triggerKey,
  });

  final String rawAction;
  final Object triggerKey;

  @override
  State<_SeatActionCalloutPill> createState() => _SeatActionCalloutPillState();
}

class _SeatActionCalloutPillState extends State<_SeatActionCalloutPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _slideY;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 56,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);
    _slideY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 6.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 52,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -8.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _triggerCallout();
  }

  void _triggerCallout() {
    final formatted = formatSeatActionCallout(widget.rawAction);
    if (formatted.isEmpty) {
      _label = '';
      _controller.reset();
      return;
    }
    _label = formatted;
    _controller.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant _SeatActionCalloutPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.triggerKey != widget.triggerKey ||
        oldWidget.rawAction != widget.rawAction) {
      _triggerCallout();
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
      animation: _controller,
      builder: (context, _) {
        if (_label.isEmpty ||
            _controller.status == AnimationStatus.dismissed ||
            _controller.status == AnimationStatus.completed) {
          return const SizedBox.shrink();
        }

        final isPackTone = _label.contains('PACK') ||
            _label.contains('LOST') ||
            _label.contains('DECLINED');
        final isGoldTone = _label.contains('SHOW');

        final Color fillColor;
        final Color borderColor;
        final Color textColor;
        if (isPackTone) {
          fillColor = const Color(0xFF4F1818);
          borderColor = const Color(0xFFE57373);
          textColor = const Color(0xFFFFEAEA);
        } else if (isGoldTone) {
          fillColor = const Color(0xFF153823);
          borderColor = const Color(0xFFE7C568);
          textColor = const Color(0xFFF6E7BC);
        } else {
          fillColor = const Color(0xFF163D26);
          borderColor = const Color(0xFF9DF0B8);
          textColor = const Color(0xFFF5F3EA);
        }

        return Transform.translate(
          offset: Offset(0, _slideY.value),
          child: Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: borderColor, width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.36),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: textColor,
                  height: 1.1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeatReactionBubble extends StatelessWidget {
  const _SeatReactionBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0E9D8),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF142E1F),
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _TurnRingPainter extends CustomPainter {
  const _TurnRingPainter({
    required this.progress,
    required this.turnDuration,
  });

  final double progress;
  final Duration turnDuration;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ringColor = turnRingColorForProgress(progress, turnDuration);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..color = ringColor;

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
    return oldDelegate.progress != progress ||
        oldDelegate.turnDuration != turnDuration;
  }
}
