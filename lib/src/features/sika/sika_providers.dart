import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'models.dart';
import 'sika_repository.dart';

final sikaRepositoryProvider = Provider<SikaRepository>((ref) {
  final api = ref.watch(apiServiceProvider);
  return SikaRepository(api);
});

final sikaPacksProvider = FutureProvider<List<SikaPack>>((ref) async {
  final repo = ref.watch(sikaRepositoryProvider);
  return repo.getPacks();
});

final sikaWalletProvider = FutureProvider<({SikaWallet wallet, List<SikaLedgerEntry> recentTransactions})>((ref) async {
  final repo = ref.watch(sikaRepositoryProvider);
  return repo.getWallet();
});

class SikaWalletNotifier extends StateNotifier<AsyncValue<SikaWallet?>> {
  final SikaRepository _repo;

  SikaWalletNotifier(this._repo) : super(const AsyncValue.loading()) {
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final result = await _repo.getWallet();
      state = AsyncValue.data(result.wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadWallet();
  }

  void updateBalance(int newBalance) {
    state.whenData((wallet) {
      if (wallet != null) {
        state = AsyncValue.data(SikaWallet(
          id: wallet.id,
          userId: wallet.userId,
          balance: newBalance,
          formattedBalance: _formatBalance(newBalance),
          status: wallet.status,
          canTransact: wallet.canTransact,
          createdAt: wallet.createdAt,
        ));
      }
    });
  }

  String _formatBalance(int balance) {
    if (balance >= 1000000) {
      return '${(balance / 1000000).toStringAsFixed(1)}M';
    }
    if (balance >= 1000) {
      return '${(balance / 1000).toStringAsFixed(1)}K';
    }
    return balance.toString();
  }
}

final sikaWalletNotifierProvider = StateNotifierProvider<SikaWalletNotifier, AsyncValue<SikaWallet?>>((ref) {
  final repo = ref.watch(sikaRepositoryProvider);
  return SikaWalletNotifier(repo);
});

final sikaTransactionsProvider = FutureProvider.family<
    ({List<SikaLedgerEntry> transactions, int currentPage, int lastPage, int total}),
    ({int page, String? type, String? direction})
>((ref, params) async {
  final repo = ref.watch(sikaRepositoryProvider);
  return repo.getTransactions(
    page: params.page,
    type: params.type,
    direction: params.direction,
  );
});
