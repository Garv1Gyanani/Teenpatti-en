import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/animated_number_text.dart';

/// Center pot pill showing "Pot" label, poker chip icon, and animated amount.
class TablePotBadge extends StatelessWidget {
  const TablePotBadge({
    super.key,
    required this.potAmount,
  });

  final int potAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3E28),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: Text(
            'Pot',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0E2618).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD6CBA8).withValues(alpha: 0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF285538),
                  border: Border.all(
                    color: const Color(0xFFD5E1D2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE0D1A6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedNumberText(
                value: potAmount,
                prefix: '₹',
                animateDecrease: false,
                duration: const Duration(milliseconds: 260),
                style: AppTextStyles.chipBalance.copyWith(
                  fontSize: 19,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
