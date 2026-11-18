import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/table_hand_history.dart';

/// In-table modal bottom sheet displaying session summary and round-by-round
/// Teen Patti hand history.
class TableHandHistorySheet extends StatelessWidget {
  const TableHandHistorySheet({
    super.key,
    required this.entries,
  });

  final List<TableHandHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final wins = entries.where((e) => e.isLocalWinner).length;
    final totalNet =
        entries.fold<int>(0, (sum, item) => sum + item.localNetChips);
    final netPrefix = totalNet >= 0 ? '+₹' : '-₹';

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.history_edu_rounded,
                    color: Color(0xFFF0E9D8),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Table Hand History',
                      style: AppTextStyles.modalHeadingCream,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatMiniColumn(
                        label: 'Hands',
                        value: '${entries.length}',
                      ),
                    ),
                    Expanded(
                      child: _StatMiniColumn(
                        label: 'Won',
                        value: '$wins',
                      ),
                    ),
                    Expanded(
                      child: _StatMiniColumn(
                        label: 'Session Net',
                        value: '$netPrefix${formatIndianNumber(totalNet.abs())}',
                        valueColor: totalNet >= 0
                            ? const Color(0xFF9DF0B8)
                            : const Color(0xFFF29B8E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'Complete your first hand at this table to inspect winning cards, pot sizes, and turn-by-turn actions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _HandHistoryCard(entry: entries[index]);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatMiniColumn extends StatelessWidget {
  const _StatMiniColumn({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _HandHistoryCard extends StatelessWidget {
  const _HandHistoryCard({required this.entry});

  final TableHandHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final deltaPrefix = entry.localNetChips >= 0 ? '+₹' : '-₹';
    final deltaColor = entry.localNetChips >= 0
        ? const Color(0xFF9DF0B8)
        : const Color(0xFFF29B8E);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isLocalWinner
              ? const Color(0xFF9DF0B8).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E9D8).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Round #${entry.roundNumber} • ${entry.variant.displayName}'
                  '${entry.jokerCard != null ? ' (${entry.jokerCard!.label})' : ''}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF0E9D8),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$deltaPrefix${formatIndianNumber(entry.localNetChips.abs())}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: deltaColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.winnerName} won ₹${formatIndianNumber(entry.potAmount)} • ${entry.winningHandLabel}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.winReason,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          if (entry.showdownHands.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: entry.showdownHands.map((summary) {
                final cardsText =
                    summary.player.cards.map((c) => c.label).join(' ');
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${summary.player.name}: $cardsText',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: summary.isWinner
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: summary.isWinner
                          ? const Color(0xFF9DF0B8)
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (entry.actionLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.actionLog.take(6).join('  •  '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.58),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
