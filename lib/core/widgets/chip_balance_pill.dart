import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Forest-green chip balance pill with poker chip icon and `+` action button.
class ChipBalancePill extends StatelessWidget {
  const ChipBalancePill({
    super.key,
    required this.chips,
    required this.onAddTap,
  });

  final int chips;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PokerChipIcon(),
          const SizedBox(width: 8),
          Text(
            formatCommaNumber(chips),
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.creamBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 19,
                color: AppColors.forestGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PokerChipIcon extends StatelessWidget {
  const _PokerChipIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF47784F),
        border: Border.all(
          color: const Color(0xFFDCE7D8),
          width: 2.2,
        ),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFDFC88B),
          ),
        ),
      ),
    );
  }
}

