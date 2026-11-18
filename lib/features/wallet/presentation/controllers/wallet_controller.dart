import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/session/app_session_store.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/wallet_data.dart';
import '../../domain/usecases/get_wallet_data_usecase.dart';

/// Presentation controller for the Chip Wallet screen.
class WalletController extends ChangeNotifier {
  WalletController({
    required GetWalletDataUseCase getWalletDataUseCase,
    AppSessionStore? sessionStore,
  })  : _getWalletDataUseCase = getWalletDataUseCase,
        _sessionStore = sessionStore {
    _sessionStore?.addListener(_onSessionChanged);
  }

  final GetWalletDataUseCase _getWalletDataUseCase;
  final AppSessionStore? _sessionStore;

  WalletData? _data;
  WalletData? get data => _data;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _showAllTransactions = false;
  bool get showAllTransactions => _showAllTransactions;

  bool _isDisposed = false;

  void _onSessionChanged() {
    final store = _sessionStore;
    if (_isDisposed || _isLoading || store == null) return;
    _data = store.toWalletData();
    _notifySafely();
  }

  Future<void> loadWallet() async {
    _isLoading = true;
    _notifySafely();

    try {
      _data = await _getWalletDataUseCase();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  List<ChipTransaction> get visibleTransactions {
    final list = _data?.transactions ?? const [];
    if (_showAllTransactions || list.length <= 5) {
      return list;
    }
    return list.take(5).toList();
  }

  void toggleShowAllTransactions() {
    _showAllTransactions = !_showAllTransactions;
    _notifySafely();
  }

  int? claimWatchAndEarn() {
    final current = _data;
    if (current == null) return null;

    final reward = current.watchEarnAmount;
    final store = _sessionStore;
    if (store != null) {
      unawaited(store.claimWatchAndEarn(reward: reward));
      _data = store.toWalletData();
      _notifySafely();
      return reward;
    }

    final tx = ChipTransaction(
      id: 'tx_watch_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Watch & Earn',
      subtitle: 'Rewarded bonus • Just now',
      amount: reward,
      type: ChipTransactionType.dailyReward,
    );

    _data = current.copyWith(
      balance: current.balance + reward,
      transactions: [tx, ...current.transactions],
    );
    _notifySafely();
    return reward;
  }

  void purchaseChips({required int priceInr, required int chipAmount}) {
    final current = _data;
    if (current == null) return;

    final store = _sessionStore;
    if (store != null) {
      unawaited(
        store.purchaseChips(priceInr: priceInr, chipAmount: chipAmount),
      );
      _data = store.toWalletData();
      _notifySafely();
      return;
    }

    final tx = ChipTransaction(
      id: 'tx_buy_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Chip Purchase',
      subtitle: '₹$priceInr • ${formatIndianNumber(chipAmount)} Chips',
      amount: chipAmount,
      type: ChipTransactionType.chipPurchase,
    );

    _data = current.copyWith(
      balance: current.balance + chipAmount,
      transactions: [tx, ...current.transactions],
    );
    _notifySafely();
  }

  void markFreeChipsClaimed() {
    final current = _data;
    if (current == null || !current.hasClaimableFreeChips) return;
    _data = current.copyWith(hasClaimableFreeChips: false);
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionStore?.removeListener(_onSessionChanged);
    super.dispose();
  }
}
