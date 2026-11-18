import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/round_result.dart';
import 'face_down_card_fan.dart';
import 'face_up_card_fan.dart';

/// Showdown summary modal supporting both human and automated opponent wins.
class RoundResultDialog extends StatelessWidget {
  const RoundResultDialog({
    super.key,
    required this.result,
    required this.onBackToLobby,
    required this.onPlayAgain,
  });

  final RoundResult result;
  final VoidCallback onBackToLobby;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final titleText =
        result.isLocalWinner ? 'You Won!' : '${result.winner.name} Won';
    final runnersUp = result.showdownHands
        .where((entry) => !entry.isWinner)
        .toList(growable: false);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 26),
              decoration: BoxDecoration(
                color: AppColors.creamBackground,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 82,
                      child: CustomPaint(
                        painter: _ModalTopAccentPainter(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 36, 18, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            titleText,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.winnerHeading,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            result.winReason,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _WonChipsPill(amount: result.wonAmount),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 230),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _WinnerResultRow(result: result),
                                  for (final entry in runnersUp) ...[
                                    const SizedBox(height: 8),
                                    _ShowdownRunnerUpRow(summary: entry),
                                  ],
                                  for (final opponent in result.packedOpponents) ...[
                                    const SizedBox(height: 8),
                                    _PackedOpponentRow(
                                      name: opponent.name,
                                      avatarAsset: opponent.avatarAsset,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Divider(
                            color: AppColors.inputBorder.withValues(alpha: 0.7),
                            height: 18,
                          ),
                          _BalanceSummaryRow(
                            previousBalance: result.previousBalance,
                            newBalance: result.newBalance,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: OutlinedButton.icon(
                                    onPressed: onBackToLobby,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      backgroundColor: AppColors.inputFill,
                                      foregroundColor: AppColors.forestGreen,
                                      side: const BorderSide(
                                        color: AppColors.forestGreen,
                                        width: 1.15,
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                    icon: const Icon(
                                      Icons.home_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Back to Lobby',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: FilledButton.icon(
                                    onPressed: onPlayAgain,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      backgroundColor: AppColors.forestGreen,
                                      foregroundColor: Colors.white,
                                      shape: const StadiumBorder(),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      'Play Again',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Top Crown Emblem
            Positioned(
              top: 0,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.creamBackground,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 30,
                  color: Color(0xFFE7C568),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalTopAccentPainter extends CustomPainter {
  const _ModalTopAccentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final leftCurve = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.42, 0)
      ..quadraticBezierTo(w * 0.22, h * 0.35, 0, h * 0.85)
      ..close();

    final rightCurve = Path()
      ..moveTo(w, 0)
      ..lineTo(w * 0.58, 0)
      ..quadraticBezierTo(w * 0.78, h * 0.35, w, h * 0.85)
      ..close();

    final wavePaint = Paint()..color = AppColors.forestGreen;
    canvas.drawPath(leftCurve, wavePaint);
    canvas.drawPath(rightCurve, wavePaint);

    // Subtle gold confetti accents
    final confettiPaint = Paint()..color = const Color(0xFFE5C467);
    canvas.drawRect(Rect.fromLTWH(w * 0.14, h * 0.62, 10, 4), confettiPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.82, h * 0.58, 10, 4), confettiPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WonChipsPill extends StatelessWidget {
  const _WonChipsPill({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.88, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.forestGreen,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF47784F),
                border: Border.all(color: const Color(0xFFDCE7D8), width: 2),
              ),
            ),
            const SizedBox(width: 8),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: amount),
              duration: const Duration(milliseconds: 680),
              curve: Curves.easeOutCubic,
              builder: (context, displayedAmount, _) {
                return Text(
                  '+₹${formatCommaNumber(displayedAmount)}',
                  style: AppTextStyles.chipBalance.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WinnerResultRow extends StatelessWidget {
  const _WinnerResultRow({required this.result});

  final RoundResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sageGreen.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: ClipOval(
              child: Image.asset(
                result.winner.avatarAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        result.winner.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B8C48),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Winner',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  result.handLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                  ),
                ),
              ],
            ),
          ),
          if (result.winner.cards.length == 3) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              height: 42,
              child: FittedBox(
                fit: BoxFit.contain,
                child: FaceUpCardFan(cards: result.winner.cards),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShowdownRunnerUpRow extends StatelessWidget {
  const _ShowdownRunnerUpRow({required this.summary});

  final ShowdownHandSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.sageGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: ClipOval(
              child: Image.asset(
                summary.player.avatarAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                  ),
                ),
                Text(
                  summary.handLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          if (summary.player.cards.length == 3) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              height: 38,
              child: FittedBox(
                fit: BoxFit.contain,
                child: FaceUpCardFan(cards: summary.player.cards),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackedOpponentRow extends StatelessWidget {
  const _PackedOpponentRow({
    required this.name,
    required this.avatarAsset,
  });

  final String name;
  final String avatarAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.sageGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.2),
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
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.forestGreen,
              ),
            ),
          ),
          const FaceDownCardFan(cardWidth: 16, cardHeight: 24),
          const SizedBox(width: 14),
          const Text(
            'Packed',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSummaryRow extends StatelessWidget {
  const _BalanceSummaryRow({
    required this.previousBalance,
    required this.newBalance,
  });

  final int previousBalance;
  final int newBalance;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Your Balance',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.forestGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₹${formatCommaNumber(previousBalance)}',
                    style: AppTextStyles.chipBalance.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TweenAnimationBuilder<int>(
                      tween: IntTween(begin: previousBalance, end: newBalance),
                      duration: const Duration(milliseconds: 720),
                      curve: Curves.easeOutCubic,
                      builder: (context, displayedBalance, _) {
                        return Text(
                          '₹${formatCommaNumber(displayedBalance)}',
                          style: AppTextStyles.chipBalance.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forestGreen,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

