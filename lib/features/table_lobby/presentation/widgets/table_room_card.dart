import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/game_table_room.dart';
import 'table_room_thumbnail.dart';

/// Card representing a joinable Teen Patti table room in the lobby.
class TableRoomCard extends StatelessWidget {
  const TableRoomCard({
    super.key,
    required this.room,
    required this.onJoin,
  });

  final GameTableRoom room;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final available = room.availableSeats;
    final seatLabel = room.isFull
        ? 'Table Full'
        : '$available ${available == 1 ? 'seat' : 'seats'} available';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.72),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          TableRoomThumbnail(style: room.themeStyle),
          const SizedBox(width: 10),
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardHeading,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.forestGreen,
                        border: Border.all(
                          color: const Color(0xFF9EB59B),
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${formatCommaNumber(room.entryChips)} chips',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Blinds: ${formatCommaNumber(room.smallBlind)} / ${formatCommaNumber(room.bigBlind)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _SeatAvatarRow(
                  maxSeats: room.maxSeats,
                  seatedAvatars: room.seatedAvatars,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 13,
                      color: AppColors.forestGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${room.seatedCount}/${room.maxSeats} seated',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  seatLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: room.isFull
                        ? AppColors.mutedText
                        : AppColors.forestGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: room.isFull ? null : onJoin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.inputBorder.withValues(alpha: 0.75),
                disabledForegroundColor: AppColors.mutedText,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 0,
              ),
              child: const Text(
                'Join',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatAvatarRow extends StatelessWidget {
  const _SeatAvatarRow({
    required this.maxSeats,
    required this.seatedAvatars,
  });

  final int maxSeats;
  final List<String> seatedAvatars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxSeats, (index) {
        final hasPlayer = index < seatedAvatars.length;
        return Padding(
          padding: EdgeInsets.only(right: index == maxSeats - 1 ? 0 : 2),
          child: Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasPlayer
                  ? AppColors.creamBackground
                  : AppColors.sageGreen.withValues(alpha: 0.14),
              border: Border.all(
                color: AppColors.inputBorder.withValues(alpha: 0.8),
                width: 0.8,
              ),
            ),
            child: hasPlayer
                ? ClipOval(
                    child: Image.asset(
                      seatedAvatars[index],
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }
}

