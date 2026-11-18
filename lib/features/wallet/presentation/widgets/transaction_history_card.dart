import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ace_card.dart';
import '../../domain/entities/wallet_data.dart';

/// Card displaying the Chip Wallet transaction history ledger.
class TransactionHistoryCard extends StatelessWidget {
  const TransactionHistoryCard({
    super.key,
    required this.transactions,
    required this.showAll,
    required this.onViewAllTap,
  });

  final List<ChipTransaction> transactions;
  final bool showAll;
  final VoidCallback onViewAllTap;

  @override
  Widget build(BuildContext context) {
    return AceCard(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 21,
                  color: AppColors.forestGreen,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Transaction History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF14281D),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onViewAllTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        showAll ? 'Show Less' : 'View All',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.forestGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.inputBorder.withValues(alpha: 0.35),
          ),
          for (int i = 0; i < transactions.length; i++) ...[
            _TransactionRow(transaction: transactions[i]),
            if (i < transactions.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.inputBorder.withValues(alpha: 0.35),
              ),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final ChipTransaction transaction;

  IconData get _icon => switch (transaction.type) {
        ChipTransactionType.dailyReward => Icons.card_giftcard_rounded,
        ChipTransactionType.gameWin => Icons.sports_esports_outlined,
        ChipTransactionType.chipPurchase => Icons.shopping_cart_outlined,
        ChipTransactionType.gameEntry => Icons.remove_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final badgeBg =
        isCredit ? const Color(0xFFE9F0E6) : const Color(0xFFFBECE9);
    final iconColor =
        isCredit ? AppColors.forestGreen : const Color(0xFFC93B2B);
    final amountColor =
        isCredit ? const Color(0xFF1A6832) : const Color(0xFFC93B2B);
    final amountPrefix = isCredit ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF14281D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$amountPrefix${formatIndianNumber(transaction.amount.abs())}',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
