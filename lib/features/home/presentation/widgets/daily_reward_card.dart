import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Daily Reward banner card with subtle wave accent and "Claim" pill button.
class DailyRewardCard extends StatelessWidget {
  const DailyRewardCard({
    super.key,
    required this.isClaimed,
    required this.isClaiming,
    required this.onClaim,
  });

  final bool isClaimed;
  final bool isClaiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.inputBorder.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RewardWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    size: 30,
                    color: AppColors.forestGreen,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Daily Reward',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestGreen,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isClaimed
                              ? 'Free chips added to your stack!'
                              : 'Claim your free chips today!',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 38,
                    child: FilledButton(
                      onPressed: (isClaimed || isClaiming) ? null : onClaim,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forestGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.sageGreen.withValues(alpha: 0.45),
                        disabledForegroundColor: AppColors.forestGreen,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        elevation: 0,
                      ),
                      child: Text(
                        isClaimed ? 'Claimed' : 'Claim',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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

class _RewardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.48, size.height)
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.65,
        size.width * 0.78,
        size.height * 0.15,
        size.width,
        0,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = AppColors.sageGreen.withValues(alpha: 0.15),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

