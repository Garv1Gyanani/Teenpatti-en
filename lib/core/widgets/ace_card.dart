import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/app_audio_cue.dart';
import '../theme/app_colors.dart';
import 'ace_press_scale.dart';

/// Standard Ace Society rounded card container with warm ivory surface,
/// subtle border, and soft elevation shadow.
///
/// Provide [onTap] to make the card interactive with ripple feedback and an
/// optional spring [AcePressScale] press response.
class AceCard extends StatelessWidget {
  const AceCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.backgroundColor = AppColors.inputFill,
    this.borderColor,
    this.borderWidth = 1,
    this.boxShadow,
    this.onTap,
    this.enablePressScale = true,
    this.audioCue = AppAudioCue.uiTap,
    this.enableHaptic = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool enablePressScale;
  final AppAudioCue? audioCue;
  final bool enableHaptic;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        borderColor ?? AppColors.inputBorder.withValues(alpha: 0.65);
    final effectiveShadows = boxShadow ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ];

    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: effectiveBorderColor,
            width: borderWidth,
          ),
          boxShadow: effectiveShadows,
        ),
        child: child,
      );
    }

    final radius = BorderRadius.circular(borderRadius);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: effectiveShadows,
      ),
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: effectiveBorderColor,
            width: borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );

    if (!enablePressScale) {
      return card;
    }

    return AcePressScale(
      audioCue: audioCue,
      enableHaptic: enableHaptic,
      child: card,
    );
  }
}

/// Custom pill toggle switch styled in Ace Society forest green.
class AceToggleSwitch extends StatelessWidget {
  const AceToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.forestGreen : const Color(0xFFD6D5CE),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Crisp vector poker chip ring icon with alternating forest-green & cream edge notches.
class PokerChipBadge extends StatelessWidget {
  const PokerChipBadge({
    super.key,
    this.size = 38,
    this.primaryColor = AppColors.forestGreen,
    this.accentColor = const Color(0xFFF3EFE3),
  });

  final double size;
  final Color primaryColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PokerChipBadgePainter(
          primaryColor: primaryColor,
          accentColor: accentColor,
        ),
      ),
    );
  }
}

class _PokerChipBadgePainter extends CustomPainter {
  const _PokerChipBadgePainter({
    required this.primaryColor,
    required this.accentColor,
  });

  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    canvas.drawCircle(center, outerRadius, Paint()..color = primaryColor);

    // 8 radial cream edge blocks
    final notchPaint = Paint()..color = accentColor;
    for (int i = 0; i < 8; i++) {
      final angle = i * (math.pi / 4);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final rect = Rect.fromCenter(
        center: Offset(0, -outerRadius * 0.78),
        width: size.width * 0.15,
        height: size.height * 0.24,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        notchPaint,
      );
      canvas.restore();
    }

    // Inner dashed/ring & center medallion
    canvas.drawCircle(
      center,
      outerRadius * 0.54,
      Paint()..color = accentColor,
    );
    canvas.drawCircle(
      center,
      outerRadius * 0.42,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _PokerChipBadgePainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
