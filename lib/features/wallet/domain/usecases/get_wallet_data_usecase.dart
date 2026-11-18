import '../entities/wallet_data.dart';
import '../repositories/wallet_repository.dart';

class GetWalletDataUseCase {
  const GetWalletDataUseCase({required WalletRepository repository})
      : _repository = repository;

  final WalletRepository _repository;

  Future<WalletData> call() => _repository.getWalletData();
}
