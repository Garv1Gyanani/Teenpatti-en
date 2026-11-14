import 'package:flutter/material.dart';

import '../../domain/entities/table_state.dart';

/// Bottom 5-button Teen Patti action bar: Pack, Side Show, Blind, Chaal, Show,
/// or a "Deal New Hand" button once the local player has packed.
class TableActionBar extends StatelessWidget {
  const TableActionBar({
    super.key,
    required this.blindAmount,
    required this.chaalAmount,
    required this.hasPacked,
    required this.isDisabled,
    required this.onAction,
    required this.onDealNewHand,
  });

  final int blindAmount;
  final int chaalAmount;
  final bool hasPacked;
  final bool isDisabled;
  final ValueChanged<PlayerTableAction> onAction;
  final VoidCallback onDealNewHand;

  @override
  Widget build(BuildContext context) {
    if (hasPacked) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: isDisabled ? null : onDealNewHand,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF0E9D8),
              foregroundColor: const Color(0xFF142E1F),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text(
              'Deal New Hand',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: _ActionPillButton(
              label: 'Pack',
              variant: _ActionVariant.dark,
              isDisabled: isDisabled,
              onTap: () => onAction(PlayerTableAction.pack),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 12,
            child: _ActionPillButton(
              label: 'Side Show',
              variant: _ActionVariant.dark,
              isDisabled: isDisabled,
              onTap: () => onAction(PlayerTableAction.sideShow),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 10,
            child: _ActionPillButton(
              label: 'Blind',
              subLabel: '₹$blindAmount',
              variant: _ActionVariant.dark,
              isDisabled: isDisabled,
              onTap: () => onAction(PlayerTableAction.blind),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 11,
            child: _ActionPillButton(
              label: 'Chaal',
              subLabel: '₹$chaalAmount',
              variant: _ActionVariant.cream,
              isDisabled: isDisabled,
              onTap: () => onAction(PlayerTableAction.chaal),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 10,
            child: _ActionPillButton(
              label: 'Show',
              variant: _ActionVariant.emerald,
              isDisabled: isDisabled,
              onTap: () => onAction(PlayerTableAction.show),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ActionVariant { dark, cream, emerald }

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    this.subLabel,
    required this.variant,
    required this.isDisabled,
    required this.onTap,
  });

  final String label;
  final String? subLabel;
  final _ActionVariant variant;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = switch (variant) {
      _ActionVariant.dark => Colors.white.withValues(alpha: 0.06),
      _ActionVariant.cream => const Color(0xFFF0E9D8),
      _ActionVariant.emerald => const Color(0xFF214F33),
    };

    final fgColor = switch (variant) {
      _ActionVariant.dark => Colors.white,
      _ActionVariant.cream => const Color(0xFF142E1F),
      _ActionVariant.emerald => Colors.white,
    };

    final borderColor = switch (variant) {
      _ActionVariant.dark => Colors.white.withValues(alpha: 0.34),
      _ActionVariant.cream => const Color(0xFFF0E9D8),
      _ActionVariant.emerald => Colors.white.withValues(alpha: 0.25),
    };

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Material(
        color: bgColor,
        shape: StadiumBorder(
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 46,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: variant == _ActionVariant.cream
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: fgColor,
                    height: 1.1,
                  ),
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subLabel!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: fgColor.withValues(alpha: 0.9),
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
