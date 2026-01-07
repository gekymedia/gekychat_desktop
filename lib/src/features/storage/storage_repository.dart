import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return StorageRepository(api);
});

class StorageRepository {
  final ApiService _api;

  StorageRepository(this._api);

  Future<Map<String, dynamic>> getStorageUsage() async {
    try {
      final response = await _api.getStorageUsage();
      return response.data['data'] ?? {};
    } catch (e) {
      throw Exception('Failed to load storage usage: $e');
    }
  }
}

