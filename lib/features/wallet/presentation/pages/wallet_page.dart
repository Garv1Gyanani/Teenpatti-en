import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ace_card.dart';
import '../../../../core/widgets/subpage_background_waves.dart';
import '../../../../core/widgets/subpage_header.dart';
import '../controllers/wallet_controller.dart';
import '../widgets/transaction_history_card.dart';
import '../widgets/wallet_balance_hero_card.dart';

/// Chip Wallet screen matching the Ace Society design.
class WalletPage extends StatefulWidget {
  const WalletPage({
    super.key,
    required this.controller,
  });

  final WalletController controller;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadWallet();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openDailyRewards() {
    widget.controller.markFreeChipsClaimed();
    Navigator.of(context).pushNamed(AppRoutes.dailyRewards);
  }

  void _handleWatchAndEarn() {
    final earned = widget.controller.claimWatchAndEarn();
    if (earned != null) {
      _showFeedback('Earned +₹${formatIndianNumber(earned)} Chips!');
    }
  }

  Future<void> _showBuyChipsSheet() async {
    const packs = [
      (price: 99, chips: 25000, tag: 'Starter'),
      (price: 249, chips: 75000, tag: 'Popular'),
      (price: 499, chips: 200000, tag: 'Best Value'),
      (price: 999, chips: 500000, tag: 'VIP Stack'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Buy Chips',
                style: AppTextStyles.modalHeading,
              ),
              const SizedBox(height: 4),
              const Text(
                'Select a chip bundle to top up your stack',
                style: TextStyle(fontSize: 13, color: AppColors.mutedText),
              ),
              const SizedBox(height: 14),
              ...packs.map(
                (pack) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AceCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const PokerChipBadge(size: 34),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${formatIndianNumber(pack.chips)} Chips',
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                              Text(
                                pack.tag,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            widget.controller.purchaseChips(
                              priceInr: pack.price,
                              chipAmount: pack.chips,
                            );
                            _showFeedback(
                              'Added ${formatIndianNumber(pack.chips)} Chips!',
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.forestGreen,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            '₹${pack.price}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: SubpageBackgroundWaves(),
          ),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final wallet = widget.controller.data;
                if (widget.controller.isLoading || wallet == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                    ),
                  );
                }

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SubpageHeader(
                        title: 'Chip Wallet',
                        subtitle:
                            'Manage your chips, claim freebies and view transactions',
                        onBackTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 18),

                      WalletBalanceHeroCard(balance: wallet.balance),
                      const SizedBox(height: 16),

                      // Claim Free Chips & Buy Chips buttons
                      Row(
                        children: [
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: FilledButton.icon(
                                    onPressed: _openDailyRewards,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFE7EFE5),
                                      foregroundColor: AppColors.forestGreen,
                                      shape: const StadiumBorder(),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.card_giftcard_rounded,
                                      size: 20,
                                    ),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Claim Free Chips',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (wallet.hasClaimableFreeChips)
                                  Positioned(
                                    top: 2,
                                    right: 12,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE03E2D),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _showBuyChipsSheet,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.forestGreen,
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 22),
                                label: const Text(
                                  'Buy Chips',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3-Column Freebies Strip Card
                      AceCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _FreebieTile(
                                  icon: Icons.card_giftcard_rounded,
                                  iconColor: const Color(0xFFD89A2B),
                                  title: 'Daily Claim',
                                  badgeText:
                                      '₹${formatIndianNumber(wallet.dailyClaimAmount)}',
                                  onTap: _openDailyRewards,
                                ),
                              ),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: AppColors.inputBorder
                                    .withValues(alpha: 0.45),
                              ),
                              Expanded(
                                child: _FreebieTile(
                                  icon: Icons.event_available_outlined,
                                  iconColor: AppColors.forestGreen,
                                  title: 'Streak Bonus',
                                  badgeText:
                                      'Up to ₹${formatIndianNumber(wallet.streakBonusUpTo)}',
                                  onTap: _openDailyRewards,
                                ),
                              ),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: AppColors.inputBorder
                                    .withValues(alpha: 0.45),
                              ),
                              Expanded(
                                child: _FreebieTile(
                                  icon: Icons.smart_display_outlined,
                                  iconColor: AppColors.forestGreen,
                                  title: 'Watch & Earn',
                                  badgeText:
                                      '₹${formatIndianNumber(wallet.watchEarnAmount)}',
                                  onTap: _handleWatchAndEarn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TransactionHistoryCard(
                        transactions: widget.controller.visibleTransactions,
                        showAll: widget.controller.showAllTransactions,
                        onViewAllTap:
                            widget.controller.toggleShowAllTransactions,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FreebieTile extends StatelessWidget {
  const _FreebieTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.badgeText,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String badgeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: iconColor),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF14281D),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE7EFE5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  badgeText,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
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
