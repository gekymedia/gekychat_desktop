import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';

final mediaAutoDownloadRepositoryProvider =
    Provider<MediaAutoDownloadRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return MediaAutoDownloadRepository(api);
});

class MediaAutoDownloadRepository {
  final ApiService _api;

  MediaAutoDownloadRepository(this._api);

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _api.getMediaAutoDownloadSettings();
      return response.data['data'] ?? {};
    } catch (e) {
      throw Exception('Failed to load settings: $e');
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _api.updateMediaAutoDownloadSettings(settings);
    } catch (e) {
      throw Exception('Failed to update settings: $e');
    }
  }
}

