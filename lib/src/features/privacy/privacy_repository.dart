import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';

final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return PrivacyRepository(api);
});

class PrivacyRepository {
  final ApiService _api;

  PrivacyRepository(this._api);

  Future<Map<String, dynamic>> getPrivacySettings() async {
    try {
      final response = await _api.getPrivacySettings();
      return response.data['data'] ?? {};
    } catch (e) {
      throw Exception('Failed to load privacy settings: $e');
    }
  }

  Future<void> updatePrivacySettings(Map<String, dynamic> settings) async {
    try {
      await _api.updatePrivacySettings(settings);
    } catch (e) {
      throw Exception('Failed to update privacy settings: $e');
    }
  }
}

