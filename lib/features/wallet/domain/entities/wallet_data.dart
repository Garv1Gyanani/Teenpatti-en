enum ChipTransactionType {
  dailyReward,
  gameWin,
  chipPurchase,
  gameEntry,
}

class ChipTransaction {
  const ChipTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
  });

  final String id;
  final String title;
  final String subtitle;
  final int amount;
  final ChipTransactionType type;

  bool get isCredit => amount >= 0;
}

class WalletData {
  const WalletData({
    required this.balance,
    required this.hasClaimableFreeChips,
    required this.dailyClaimAmount,
    required this.streakBonusUpTo,
    required this.watchEarnAmount,
    required this.transactions,
  });

  final int balance;
  final bool hasClaimableFreeChips;
  final int dailyClaimAmount;
  final int streakBonusUpTo;
  final int watchEarnAmount;
  final List<ChipTransaction> transactions;

  WalletData copyWith({
    int? balance,
    bool? hasClaimableFreeChips,
    List<ChipTransaction>? transactions,
  }) {
    return WalletData(
      balance: balance ?? this.balance,
      hasClaimableFreeChips:
          hasClaimableFreeChips ?? this.hasClaimableFreeChips,
      dailyClaimAmount: dailyClaimAmount,
      streakBonusUpTo: streakBonusUpTo,
      watchEarnAmount: watchEarnAmount,
      transactions: transactions ?? this.transactions,
    );
  }
}
