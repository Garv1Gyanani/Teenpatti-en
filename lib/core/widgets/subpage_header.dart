import 'package:flutter/material.dart';

import '../audio/app_audio_cue.dart';
import '../audio/app_audio_service.dart';
import '../audio/app_haptic_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'ace_press_scale.dart';
import 'club_suit_painter.dart';

/// Circular cream-white header action button with subtle border and shadow.
class AceCircleIconButton extends StatelessWidget {
  const AceCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = AcePressScale(
      child: Material(
        color: AppColors.inputFill,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: CircleBorder(
          side: BorderSide(
            color: AppColors.inputBorder.withValues(alpha: 0.75),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            AppAudioService.instance.play(AppAudioCue.uiTap);
            AppHapticService.selection();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: AppColors.forestGreen,
              size: 20,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Shared secondary page header featuring top-left back button, centered
/// club suit emblem, serif title, optional subtitle, and optional top-right button.
class SubpageHeader extends StatelessWidget {
  const SubpageHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBackTap,
    this.trailingIcon,
    this.onTrailingTap,
    this.trailingTooltip,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBackTap;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final String? trailingTooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: AceCircleIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBackTap,
            tooltip: 'Back',
          ),
        ),
        if (trailingIcon != null && onTrailingTap != null)
          Align(
            alignment: Alignment.topRight,
            child: AceCircleIconButton(
              icon: trailingIcon!,
              onTap: onTrailingTap!,
              tooltip: trailingTooltip,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              const SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(
                  painter: ClubSuitPainter(color: AppColors.forestGreen),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.screenTitle,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.pageSubheading,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
