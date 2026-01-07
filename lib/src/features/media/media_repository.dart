import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'models.dart';
import 'package:dio/dio.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return MediaRepository(api);
});

class MediaRepository {
  final ApiService _api;

  MediaRepository(this._api);

  Future<List<MediaItem>> getConversationMedia(int conversationId) async {
    try {
      final response = await _api.getConversationMedia(conversationId);
      final raw = response.data;
      final data = raw is Map && raw['data'] is List
          ? raw['data'] as List<dynamic>
          : (raw is List ? raw : []);
      return data.map((json) => MediaItem.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map
            ? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to load media (HTTP $statusCode): $message');
      }
      throw Exception('Failed to load media: $e');
    }
  }

  Future<List<MediaItem>> getGroupMedia(int groupId) async {
    try {
      final response = await _api.getGroupMedia(groupId);
      final raw = response.data;
      final data = raw is Map && raw['data'] is List
          ? raw['data'] as List<dynamic>
          : (raw is List ? raw : []);
      return data.map((json) => MediaItem.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map
            ? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to load media (HTTP $statusCode): $message');
      }
      throw Exception('Failed to load media: $e');
    }
  }
}

