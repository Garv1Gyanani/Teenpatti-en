import '../entities/wallet_data.dart';

abstract interface class WalletRepository {
  Future<WalletData> getWalletData();
}
