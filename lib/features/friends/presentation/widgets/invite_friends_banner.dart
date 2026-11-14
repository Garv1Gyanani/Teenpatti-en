import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Bottom "Invite Friends" callout banner with "Share Code" pill button.
class InviteFriendsBanner extends StatelessWidget {
  const InviteFriendsBanner({
    super.key,
    required this.onShareCode,
  });

  final VoidCallback onShareCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.sageGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.72),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.group_add_outlined,
            size: 28,
            color: AppColors.forestGreen,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invite Friends',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Share your code and get more friends to play with',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: onShareCode,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                elevation: 0,
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 17),
              label: const Text(
                'Share Code',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
