import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

/// Shown when the local player's chip stack falls below the table's minimum
/// boot stake, offering instant free relief chips or Chip Wallet top-up.
class LowChipsBailoutDialog extends StatelessWidget {
  const LowChipsBailoutDialog({
    super.key,
    required this.currentChips,
    required this.requiredBoot,
    required this.reliefAmount,
    required this.onClaimRelief,
    required this.onOpenWallet,
    required this.onLeaveTable,
  });

  final int currentChips;
  final int requiredBoot;
  final int reliefAmount;
  final VoidCallback onClaimRelief;
  final VoidCallback onOpenWallet;
  final VoidCallback onLeaveTable;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.creamBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFFE7EFE5),
                child: Icon(
                  Icons.toll_rounded,
                  size: 28,
                  color: AppColors.forestGreen,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Low Chip Stack',
              textAlign: TextAlign.center,
              style: AppTextStyles.modalHeading,
            ),
            const SizedBox(height: 8),
            Text(
              'You have ₹${formatIndianNumber(currentChips)} chips, and this table requires a ₹${formatIndianNumber(requiredBoot)} boot to deal the next hand.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: onClaimRelief,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.card_giftcard_rounded, size: 19),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Claim Free Relief (+₹${formatIndianNumber(reliefAmount)})',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onOpenWallet,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forestGreen,
                  side: const BorderSide(color: AppColors.forestGreen),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: const Text(
                  'Buy Chips in Wallet',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onLeaveTable,
              child: const Text(
                'Back to Lobby',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
