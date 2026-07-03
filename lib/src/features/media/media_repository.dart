import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'media_gallery_parser.dart';
import 'package:dio/dio.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return MediaRepository(api);
});

final conversationMediaGalleryProvider =
    FutureProvider.family<MediaGalleryData, int>((ref, conversationId) async {
  final repo = ref.read(mediaRepositoryProvider);
  return repo.getConversationMediaGallery(conversationId);
});

final groupMediaGalleryProvider =
    FutureProvider.family<MediaGalleryData, int>((ref, groupId) async {
  final repo = ref.read(mediaRepositoryProvider);
  return repo.getGroupMediaGallery(groupId);
});

class MediaRepository {
  final ApiService _api;

  MediaRepository(this._api);

  Future<MediaGalleryData> getConversationMediaGallery(int conversationId) async {
    try {
      final response = await _api.getConversationMedia(conversationId);
      return parseMediaGalleryList(extractGalleryList(response.data));
    } catch (e) {
      throw _wrapError(e, 'conversation');
    }
  }

  Future<MediaGalleryData> getGroupMediaGallery(int groupId) async {
    try {
      final response = await _api.getGroupMedia(groupId);
      return parseMediaGalleryList(extractGalleryList(response.data));
    } catch (e) {
      throw _wrapError(e, 'group');
    }
  }

  Exception _wrapError(Object e, String scope) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      final message = e.response?.data is Map
          ? e.response?.data['message'] ?? e.message
          : e.message;
      return Exception('Failed to load $scope media (HTTP $statusCode): $message');
    }
    return Exception('Failed to load $scope media: $e');
  }
}
