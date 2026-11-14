import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/chip_balance_pill.dart';

/// Top-left curved green wave background for the Home player header.
class HomeHeaderWavePainter extends CustomPainter {
  const HomeHeaderWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sagePath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.56, 0)
      ..cubicTo(
        w * 0.44,
        h * 0.42,
        w * 0.24,
        h * 0.78,
        0,
        h * 0.96,
      )
      ..close();

    canvas.drawPath(sagePath, Paint()..color = AppColors.sageGreen);

    final forestPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.50, 0)
      ..cubicTo(
        w * 0.38,
        h * 0.36,
        w * 0.20,
        h * 0.70,
        0,
        h * 0.86,
      )
      ..close();

    canvas.drawPath(forestPath, Paint()..color = AppColors.forestGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Top bar displaying player avatar, name, level progress, chip pill, and
/// notification bell.
class HomeTopHeader extends StatelessWidget {
  const HomeTopHeader({
    super.key,
    required this.playerName,
    required this.avatarAsset,
    required this.level,
    required this.levelProgress,
    required this.chips,
    required this.hasUnreadNotifications,
    required this.onAddChipsTap,
    required this.onNotificationTap,
    required this.onProfileTap,
  });

  final String playerName;
  final String avatarAsset;
  final int level;
  final double levelProgress;
  final int chips;
  final bool hasUnreadNotifications;
  final VoidCallback onAddChipsTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onProfileTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    gradient: const RadialGradient(
                      colors: [
                        AppColors.avatarBackdropLight,
                        AppColors.forestGreen,
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      avatarAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lv. $level',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 66,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: levelProgress.clamp(0.0, 1.0),
                          backgroundColor: Colors.black26,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFC5D8C1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          ChipBalancePill(
            chips: chips,
            onAddTap: onAddChipsTap,
          ),
          const SizedBox(width: 10),
          _NotificationBellButton(
            hasUnread: hasUnreadNotifications,
            onTap: onNotificationTap,
          ),
        ],
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.hasUnread,
    required this.onTap,
  });

  final bool hasUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputFill,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.inputBorder, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.forestGreen,
                size: 22,
              ),
              if (hasUnread)
                Positioned(
                  top: 8,
                  right: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD93829),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.inputFill, width: 1.2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

