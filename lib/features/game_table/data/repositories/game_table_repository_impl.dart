import '../../../../core/constants/app_assets.dart';
import '../../domain/entities/playing_card.dart';
import '../../domain/entities/round_result.dart';
import '../../domain/entities/table_player.dart';
import '../../domain/entities/table_state.dart';
import '../../domain/repositories/game_table_repository.dart';

/// Default [GameTableRepository] with a 7-seat Teen Patti table and local
/// action simulation.
class GameTableRepositoryImpl implements GameTableRepository {
  const GameTableRepositoryImpl();

  @override
  Future<TableState> getInitialTableState() async {
    return const TableState(
      tableName: 'Teen Patti',
      minStake: 100,
      maxStake: 200,
      potAmount: 1200,
      blindAmount: 200,
      chaalAmount: 400,
      players: [
        TablePlayer(
          id: 'p_aryan',
          name: 'Aryan',
          chips: 12400,
          avatarAsset: AppAssets.avatar2,
          hasGiftBadge: true,
        ),
        TablePlayer(
          id: 'p_sneha',
          name: 'Sneha',
          chips: 8200,
          avatarAsset: AppAssets.avatar4,
        ),
        TablePlayer(
          id: 'p_rohit',
          name: 'Rohit',
          chips: 15000,
          avatarAsset: AppAssets.avatar3,
        ),
        TablePlayer(
          id: 'p_karan',
          name: 'Karan',
          chips: 9800,
          avatarAsset: AppAssets.avatar5,
          isDealer: true,
        ),
        TablePlayer(
          id: 'p_meera',
          name: 'Meera',
          chips: 11600,
          avatarAsset: AppAssets.splashCharacter,
        ),
        TablePlayer(
          id: 'p_vikram',
          name: 'Vikram',
          chips: 14200,
          avatarAsset: AppAssets.avatar2,
        ),
        TablePlayer(
          id: 'p_garv',
          name: 'Garv',
          chips: 25000,
          avatarAsset: AppAssets.splashCharacter,
          isLocalPlayer: true,
          isActiveTurn: true,
          cards: [
            PlayingCard(rank: 'A', suit: CardSuit.spades),
            PlayingCard(rank: 'K', suit: CardSuit.hearts),
            PlayingCard(rank: 'Q', suit: CardSuit.clubs),
          ],
        ),
      ],
    );
  }

  @override
  Future<TableState> performAction({
    required TableState currentState,
    required PlayerTableAction action,
  }) async {
    if (action == PlayerTableAction.show) {
      final previousBalance = currentState.localPlayer.chips;
      final wonAmount = currentState.potAmount * 4;
      final newBalance = previousBalance + wonAmount;

      final updatedPlayers = currentState.players.map((player) {
        if (player.isLocalPlayer) {
          return player.copyWith(chips: newBalance, isActiveTurn: false);
        }
        return player.copyWith(hasPacked: true);
      }).toList();

      final winner = updatedPlayers.firstWhere((p) => p.isLocalPlayer);
      final packedOpponents = updatedPlayers
          .where((p) => !p.isLocalPlayer)
          .take(2)
          .toList();

      return currentState.copyWith(
        potAmount: 0,
        players: updatedPlayers,
        roundResult: RoundResult(
          wonAmount: wonAmount,
          previousBalance: previousBalance,
          newBalance: newBalance,
          handLabel: 'Teen Patti',
          winner: winner,
          packedOpponents: packedOpponents,
        ),
      );
    }

    final betAmount = switch (action) {
      PlayerTableAction.blind => currentState.blindAmount,
      PlayerTableAction.chaal => currentState.chaalAmount,
      _ => 0,
    };

    final updatedPlayers = currentState.players.map((player) {
      if (!player.isLocalPlayer) return player;

      if (action == PlayerTableAction.pack) {
        return player.copyWith(hasPacked: true, isActiveTurn: false);
      }
      final nextChips = (player.chips - betAmount).clamp(0, player.chips);
      return player.copyWith(chips: nextChips);
    }).toList();

    return currentState.copyWith(
      potAmount: currentState.potAmount + betAmount,
      players: updatedPlayers,
    );
  }
}

