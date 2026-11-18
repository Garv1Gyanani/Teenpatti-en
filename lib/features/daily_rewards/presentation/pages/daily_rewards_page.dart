import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ace_card.dart';
import '../../../../core/widgets/subpage_background_waves.dart';
import '../../../../core/widgets/subpage_header.dart';
import '../../domain/entities/daily_rewards_data.dart';
import '../controllers/daily_rewards_controller.dart';
import '../widgets/daily_reward_illustrations.dart';

/// Daily Rewards screen matching the Ace Society design.
/// Works both as a standalone route and embedded inside the Home Rewards tab.
class DailyRewardsPage extends StatefulWidget {
  const DailyRewardsPage({
    super.key,
    required this.controller,
    this.embedded = false,
    this.onBackTap,
    this.onRewardClaimed,
  });

  final DailyRewardsController controller;
  final bool embedded;
  final VoidCallback? onBackTap;
  final ValueChanged<int>? onRewardClaimed;

  @override
  State<DailyRewardsPage> createState() => _DailyRewardsPageState();
}

class _DailyRewardsPageState extends State<DailyRewardsPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadRewards();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _handleClaimToday() {
    final amount = widget.controller.claimTodayReward();
    if (amount == null) return;

    widget.onRewardClaimed?.call(amount);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Claimed +₹${formatIndianNumber(amount)} Daily Reward!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildScrollContent() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final data = widget.controller.data;
        if (widget.controller.isLoading || data == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.forestGreen),
          );
        }

        final featured = widget.controller.featuredDays;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            widget.embedded ? 6 : 10,
            16,
            widget.embedded ? 16 : 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SubpageHeader(
                title: 'Daily Rewards',
                subtitle: 'Claim your daily reward and keep the streak going!',
                onBackTap:
                    widget.onBackTap ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 6),

              const Center(child: DailyRewardHeroIllustration()),
              const SizedBox(height: 8),

              // Current Streak | Next Reward Card
              AceCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 32,
                              color: Color(0xFFD99023),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Current Streak',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.mutedText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${data.currentStreakDays} Days',
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF14281D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      VerticalDivider(
                        width: 16,
                        thickness: 1,
                        color: AppColors.inputBorder.withValues(alpha: 0.45),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.card_giftcard_rounded,
                              size: 30,
                              color: AppColors.forestGreen,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Next Reward',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.mutedText,
                                    ),
                                  ),
                                  Text(
                                    'Day ${data.nextRewardDay}',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF14281D),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE7EFE5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '₹${formatIndianNumber(data.nextRewardAmount)} Chips',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.forestGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 7-Day Stepper
              _SevenDayStepper(days: data.days),
              const SizedBox(height: 18),

              // 4-Day Cards Grid (Day 4..7)
              Row(
                children: featured.asMap().entries.map((entry) {
                  final index = entry.key;
                  final day = entry.value;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == featured.length - 1 ? 0 : 8,
                      ),
                      child: _RewardDayCard(day: day),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Primary CTA Button
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: data.isTodayClaimed ? null : _handleClaimToday,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.sageGreen.withValues(alpha: 0.45),
                    disabledForegroundColor: AppColors.forestGreen,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  icon: Icon(
                    data.isTodayClaimed
                        ? Icons.check_circle_outline_rounded
                        : Icons.card_giftcard_rounded,
                    size: 22,
                  ),
                  label: Text(
                    data.isTodayClaimed
                        ? "Today's Reward Claimed"
                        : "Claim Today's Reward",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Summary Card
              AceCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.toll_outlined,
                              size: 26,
                              color: Color(0xFF1D3325),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Total Rewards Earned',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.mutedText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '₹${formatIndianNumber(data.totalRewardsEarned)} Chips',
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF14281D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      VerticalDivider(
                        width: 16,
                        thickness: 1,
                        color: AppColors.inputBorder.withValues(alpha: 0.45),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 24,
                              color: Color(0xFF1D3325),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Streak Record',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.mutedText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${data.streakRecordDays} Days',
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF14281D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
    if (widget.embedded) {
      return _buildScrollContent();
    }

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: SubpageBackgroundWaves(),
          ),
          SafeArea(
            child: _buildScrollContent(),
          ),
        ],
      ),
    );
  }
}

class _SevenDayStepper extends StatelessWidget {
  const _SevenDayStepper({required this.days});

  final List<DailyRewardDay> days;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: List.generate(days.length * 2 - 1, (idx) {
              if (idx.isOdd) {
                final leftDay = days[idx ~/ 2];
                final isCompletedLine =
                    leftDay.status == DailyRewardCardStatus.claimed;
                return Expanded(
                  child: Container(
                    height: 3.5,
                    color: isCompletedLine
                        ? AppColors.forestGreen
                        : const Color(0xFFE4E1D7),
                  ),
                );
              }

              final day = days[idx ~/ 2];
              final isCurrent = day.status == DailyRewardCardStatus.current;
              final isDone = day.status == DailyRewardCardStatus.claimed;

              return Container(
                width: isCurrent ? 28 : 24,
                height: isCurrent ? 28 : 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDone || isCurrent)
                      ? const Color(0xFF1A5A30)
                      : AppColors.inputFill,
                  border: Border.all(
                    color: isCurrent
                        ? Colors.white
                        : (isDone
                            ? const Color(0xFF1A5A30)
                            : const Color(0xFFD5D3CA)),
                    width: isCurrent ? 2 : 1.5,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(0xFF83B76B)
                                .withValues(alpha: 0.45),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: (isDone || isCurrent)
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: days.map((day) {
            final isCurrent = day.status == DailyRewardCardStatus.current;
            final isLocked = day.status == DailyRewardCardStatus.locked;
            return Expanded(
              child: Text(
                'Day ${day.dayNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent
                      ? const Color(0xFF14281D)
                      : (isLocked
                          ? AppColors.mutedText
                          : const Color(0xFF2B3D31)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RewardDayCard extends StatelessWidget {
  const _RewardDayCard({required this.day});

  final DailyRewardDay day;

  @override
  Widget build(BuildContext context) {
    final isCurrent = day.status == DailyRewardCardStatus.current;
    final isClaimed = day.status == DailyRewardCardStatus.claimed;
    final isGrand = day.isGrandBonus;

    final cardBg = isGrand
        ? const Color(0xFFFDF2E2)
        : (isCurrent ? const Color(0xFFF6FAF4) : AppColors.inputFill);
    final borderColor = isCurrent
        ? const Color(0xFF39884E)
        : (isGrand
            ? const Color(0xFFE7CCA2)
            : AppColors.inputBorder.withValues(alpha: 0.65));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 152,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isCurrent ? 1.7 : 1,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: const Color(0xFF39884E).withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: AppColors.forestGreen,
                    child: Text(
                      'Day ${day.dayNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      'Day ${day.dayNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E2D24),
                      ),
                    ),
                  ),
                const Spacer(),
                Center(
                  child: RewardCardChipsIllustration(isGold: isGrand),
                ),
                const Spacer(),
                Text(
                  '₹${formatIndianNumber(day.amount)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF14281D),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: (isClaimed || isCurrent)
                      ? Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? const Color(0xFF1F6E36)
                                : const Color(0xFF164324),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: Color(0xFF646C66),
                        ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        if (isGrand)
          Positioned(
            top: -3,
            right: -3,
            child: ClipPath(
              clipper: _CornerRibbonClipper(),
              child: Container(
                width: 34,
                height: 34,
                color: const Color(0xFFCFA243),
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(top: 5, right: 5),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CornerRibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
