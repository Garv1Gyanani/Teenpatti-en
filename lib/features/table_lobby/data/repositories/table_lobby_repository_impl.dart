import '../../../../core/constants/app_assets.dart';
import '../../domain/entities/game_table_room.dart';
import '../../domain/repositories/table_lobby_repository.dart';

/// Default [TableLobbyRepository] supplying curated Teen Patti rooms.
class TableLobbyRepositoryImpl implements TableLobbyRepository {
  const TableLobbyRepositoryImpl();

  @override
  Future<List<GameTableRoom>> getAvailableTables() async {
    return const [
      GameTableRoom(
        id: 'room_emerald',
        name: 'Emerald Room',
        entryChips: 1000,
        smallBlind: 50,
        bigBlind: 100,
        seatedCount: 4,
        maxSeats: 6,
        tier: TableTier.beginner,
        themeStyle: RoomThemeStyle.emerald,
        seatedAvatars: [
          AppAssets.avatar2,
          AppAssets.avatar4,
          AppAssets.avatar3,
          AppAssets.avatar5,
        ],
      ),
      GameTableRoom(
        id: 'room_ivory',
        name: 'Ivory Table',
        entryChips: 5000,
        smallBlind: 250,
        bigBlind: 500,
        seatedCount: 2,
        maxSeats: 6,
        tier: TableTier.beginner,
        themeStyle: RoomThemeStyle.ivory,
        seatedAvatars: [
          AppAssets.avatar2,
          AppAssets.avatar4,
        ],
      ),
      GameTableRoom(
        id: 'room_club_lounge',
        name: 'Club Lounge',
        entryChips: 10000,
        smallBlind: 500,
        bigBlind: 1000,
        seatedCount: 5,
        maxSeats: 6,
        tier: TableTier.classic,
        themeStyle: RoomThemeStyle.clubLounge,
        seatedAvatars: [
          AppAssets.avatar2,
          AppAssets.avatar4,
          AppAssets.avatar3,
          AppAssets.avatar5,
          AppAssets.avatar4,
        ],
      ),
      GameTableRoom(
        id: 'room_royal',
        name: 'Royal Circle',
        entryChips: 25000,
        smallBlind: 1250,
        bigBlind: 2500,
        seatedCount: 6,
        maxSeats: 6,
        tier: TableTier.highStakes,
        themeStyle: RoomThemeStyle.royal,
        seatedAvatars: [
          AppAssets.avatar2,
          AppAssets.avatar4,
          AppAssets.avatar3,
          AppAssets.avatar5,
          AppAssets.avatar4,
          AppAssets.avatar2,
        ],
      ),
      GameTableRoom(
        id: 'room_ace_chamber',
        name: 'Ace Chamber',
        entryChips: 50000,
        smallBlind: 2500,
        bigBlind: 5000,
        seatedCount: 3,
        maxSeats: 6,
        tier: TableTier.highStakes,
        themeStyle: RoomThemeStyle.aceChamber,
        seatedAvatars: [
          AppAssets.avatar2,
          AppAssets.avatar4,
          AppAssets.avatar3,
        ],
      ),
    ];
  }
}

