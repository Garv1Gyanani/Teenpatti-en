import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Card displaying the player's QR code icon, invite code, copy action, and
/// "Join Friend" pill CTA.
class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({
    super.key,
    required this.inviteCode,
    required this.onCopyCode,
    required this.onJoinFriend,
  });

  final String inviteCode;
  final VoidCallback onCopyCode;
  final VoidCallback onJoinFriend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.72),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            const Icon(
              Icons.qr_code_2_rounded,
              size: 38,
              color: AppColors.forestGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'My Invite Code',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            inviteCode,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: AppColors.forestGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onCopyCode,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            VerticalDivider(
              width: 18,
              thickness: 1,
              color: AppColors.inputBorder.withValues(alpha: 0.8),
            ),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: onJoinFriend,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  elevation: 0,
                ),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text(
                  'Join Friend',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
