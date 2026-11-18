import '../../../../core/session/app_session_store.dart';
import '../../domain/entities/wallet_data.dart';
import '../../domain/repositories/wallet_repository.dart';

/// Default [WalletRepository] supplying Chip Wallet balance and ledger.
class WalletRepositoryImpl implements WalletRepository {
  const WalletRepositoryImpl({this.sessionStore});

  final AppSessionStore? sessionStore;

  @override
  Future<WalletData> getWalletData() async {
    final store = sessionStore;
    if (store != null) {
      return store.toWalletData();
    }

    return const WalletData(
      balance: 124500,
      hasClaimableFreeChips: true,
      dailyClaimAmount: 1500,
      streakBonusUpTo: 5000,
      watchEarnAmount: 1000,
      transactions: [
        ChipTransaction(
          id: 'tx_1',
          title: 'Daily Reward',
          subtitle: 'Claimed today, 10:24 AM',
          amount: 1500,
          type: ChipTransactionType.dailyReward,
        ),
        ChipTransaction(
          id: 'tx_2',
          title: 'Game Win',
          subtitle: 'Teen Patti • Table #4521',
          amount: 8000,
          type: ChipTransactionType.gameWin,
        ),
        ChipTransaction(
          id: 'tx_3',
          title: 'Chip Purchase',
          subtitle: '₹499 • 2,00,000 Chips',
          amount: 200000,
          type: ChipTransactionType.chipPurchase,
        ),
        ChipTransaction(
          id: 'tx_4',
          title: 'Game Entry',
          subtitle: 'Table #4521',
          amount: -5000,
          type: ChipTransactionType.gameEntry,
        ),
        ChipTransaction(
          id: 'tx_5',
          title: 'Game Win',
          subtitle: 'Teen Patti • Table #4478',
          amount: 12000,
          type: ChipTransactionType.gameWin,
        ),
        ChipTransaction(
          id: 'tx_6',
          title: 'Game Entry',
          subtitle: 'Table #4478',
          amount: -3000,
          type: ChipTransactionType.gameEntry,
        ),
      ],
    );
  }
}
