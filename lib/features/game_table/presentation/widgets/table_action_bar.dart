import 'package:flutter/material.dart';

import '../../../../core/audio/app_audio_cue.dart';
import '../../../../core/audio/app_audio_service.dart';
import '../../../../core/audio/app_haptic_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ace_press_scale.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/table_state.dart';

/// Bottom 5-button Teen Patti action bar: Pack, Side Show, Blind, Chaal, Show,
/// plus a compact 2x Stake raise toggle & blind-turn counter strip, or a
/// "Deal New Hand" button once the local player has packed.
class TableActionBar extends StatelessWidget {
  const TableActionBar({
    super.key,
    required this.blindAmount,
    required this.chaalAmount,
    required this.hasPacked,
    required this.isDisabled,
    this.canPack = true,
    this.canSideShow = true,
    this.canBlind = true,
    this.canChaal = true,
    this.canShow = true,
    this.canRaiseStake = false,
    this.isRaiseSelected = false,
    this.onToggleRaise,
    this.blindTurnsTaken = 0,
    this.maxBlindTurns = 4,
    this.hasSeenCards = false,
    this.packedButtonLabel,
    required this.onAction,
    required this.onDealNewHand,
  });

  final int blindAmount;
  final int chaalAmount;
  final bool hasPacked;
  final bool isDisabled;
  final bool canPack;
  final bool canSideShow;
  final bool canBlind;
  final bool canChaal;
  final bool canShow;
  final bool canRaiseStake;
  final bool isRaiseSelected;
  final VoidCallback? onToggleRaise;
  final int blindTurnsTaken;
  final int maxBlindTurns;
  final bool hasSeenCards;
  final String? packedButtonLabel;
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
          child: AcePressScale(
            enabled: !isDisabled,
            audioCue: AppAudioCue.uiTap,
            enableHaptic: true,
            child: FilledButton.icon(
              onPressed: isDisabled ? null : onDealNewHand,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF0E9D8),
                foregroundColor: const Color(0xFF142E1F),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                packedButtonLabel ?? 'Deal New Hand',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final raiseDisabled = isDisabled || !canRaiseStake || onToggleRaise == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      !hasSeenCards
                          ? 'Blind ${blindTurnsTaken.clamp(0, maxBlindTurns)}/$maxBlindTurns'
                          : 'Seen Mode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.80),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: raiseDisabled ? 0.45 : 1.0,
                  child: AcePressScale(
                    enabled: !raiseDisabled,
                    pressedScale: 0.94,
                    audioCue: AppAudioCue.uiTap,
                    enableHaptic: true,
                    child: Material(
                      color: isRaiseSelected
                          ? const Color(0xFFF0E9D8)
                          : Colors.white.withValues(alpha: 0.09),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: isRaiseSelected
                              ? const Color(0xFFF0E9D8)
                              : Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
                      child: InkWell(
                        key: const Key('raise_2x_toggle'),
                        onTap: raiseDisabled ? null : onToggleRaise,
                        customBorder: const StadiumBorder(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_up_rounded,
                                size: 13,
                                color: isRaiseSelected
                                    ? const Color(0xFF142E1F)
                                    : const Color(0xFFF0E9D8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isRaiseSelected ? '2x Stake ON' : '2x Stake',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isRaiseSelected
                                      ? const Color(0xFF142E1F)
                                      : const Color(0xFFF0E9D8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 9,
                child: _ActionPillButton(
                  label: 'Pack',
                  variant: _ActionVariant.dark,
                  isDisabled: isDisabled || !canPack,
                  onTap: () => onAction(PlayerTableAction.pack),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 12,
                child: _ActionPillButton(
                  label: 'Side Show',
                  variant: _ActionVariant.dark,
                  isDisabled: isDisabled || !canSideShow,
                  onTap: () => onAction(PlayerTableAction.sideShow),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 10,
                child: _ActionPillButton(
                  label: isRaiseSelected && canBlind ? 'Blind 2x' : 'Blind',
                  subLabel: '₹${formatCommaNumber(blindAmount)}',
                  variant: _ActionVariant.dark,
                  isDisabled: isDisabled || !canBlind,
                  onTap: () => onAction(PlayerTableAction.blind),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 11,
                child: _ActionPillButton(
                  label: isRaiseSelected && canChaal ? 'Chaal 2x' : 'Chaal',
                  subLabel: '₹${formatCommaNumber(chaalAmount)}',
                  variant: _ActionVariant.cream,
                  isDisabled: isDisabled || !canChaal,
                  onTap: () => onAction(PlayerTableAction.chaal),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 10,
                child: _ActionPillButton(
                  label: 'Show',
                  variant: _ActionVariant.emerald,
                  isDisabled: isDisabled || !canShow,
                  onTap: () => onAction(PlayerTableAction.show),
                ),
              ),
            ],
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

    return AcePressScale(
      enabled: !isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Material(
          color: bgColor,
          shape: StadiumBorder(
            side: BorderSide(color: borderColor, width: 1),
          ),
          child: InkWell(
            onTap: isDisabled
                ? null
                : () {
                    AppAudioService.instance.play(
                      label == 'Pack'
                          ? AppAudioCue.packFold
                          : AppAudioCue.uiTap,
                    );
                    AppHapticService.selection();
                    onTap();
                  },
            customBorder: const StadiumBorder(),
            child: SizedBox(
              height: 46,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        style: AppTextStyles.buttonLabel.copyWith(
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
                          style: AppTextStyles.chipBalance.copyWith(
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
          ),
        ),
      ),
    );
  }
}
