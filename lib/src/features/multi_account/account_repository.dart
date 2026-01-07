import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import '../../core/device_id.dart';

/// PHASE 2: Multi-Account Repository
class AccountRepository {
  final ApiService _apiService;

  AccountRepository(this._apiService);

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final deviceId = await getOrCreateDeviceId();
    final response = await _apiService.getAccounts(
      deviceId: deviceId,
      deviceType: 'desktop',
    );
    
    if (response.data is Map && response.data['data'] != null) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  Future<void> switchAccount(int accountId) async {
    final deviceId = await getOrCreateDeviceId();
    final response = await _apiService.switchAccount(
      deviceId: deviceId,
      deviceType: 'desktop',
      accountId: accountId,
    );
    
    // Update token in storage
    final responseData = response.data is Map ? response.data : {};
    if (responseData['token'] != null) {
      final token = responseData['token'] as String;
      await _apiService.saveToken(token);
    }
  }

  Future<void> removeAccount(int accountId) async {
    final deviceId = await getOrCreateDeviceId();
    await _apiService.removeAccount(
      deviceId: deviceId,
      deviceType: 'desktop',
      accountId: accountId,
    );
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AccountRepository(apiService);
});

final accountsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.read(accountRepositoryProvider);
  return await repository.getAccounts();
});

