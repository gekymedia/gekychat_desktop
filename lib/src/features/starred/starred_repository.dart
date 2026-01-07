import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'models.dart';

final starredRepositoryProvider = Provider<StarredRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return StarredRepository(api);
});

class StarredRepository {
  final ApiService _api;

  StarredRepository(this._api);

  /// Get all starred messages
  /// Note: This endpoint may need to be created in the backend
  Future<List<StarredMessage>> getStarredMessages() async {
    try {
      // TODO: Replace with actual API endpoint when available
      // For now, return empty list as placeholder
      // final response = await _api.get('/starred-messages');
      // final data = response.data;
      // final messagesData = data['data'] is List ? data['data'] as List : [];
      // return messagesData.map((json) => StarredMessage.fromJson(json)).toList();
      
      return [];
    } catch (e) {
      throw Exception('Failed to load starred messages: $e');
    }
  }

  /// Star a message
  /// Note: This endpoint may need to be created in the backend
  Future<void> starMessage(int messageId, {int? conversationId, int? groupId}) async {
    try {
      // TODO: Replace with actual API endpoint when available
      // if (groupId != null) {
      //   await _api.post('/groups/$groupId/messages/$messageId/star');
      // } else {
      //   await _api.post('/conversations/$conversationId/messages/$messageId/star');
      // }
    } catch (e) {
      throw Exception('Failed to star message: $e');
    }
  }

  /// Unstar a message
  /// Note: This endpoint may need to be created in the backend
  Future<void> unstarMessage(int messageId, {int? conversationId, int? groupId}) async {
    try {
      // TODO: Replace with actual API endpoint when available
      // if (groupId != null) {
      //   await _api.delete('/groups/$groupId/messages/$messageId/star');
      // } else {
      //   await _api.delete('/conversations/$conversationId/messages/$messageId/star');
      // }
    } catch (e) {
      throw Exception('Failed to unstar message: $e');
    }
  }

  /// Check if a message is starred
  /// Note: This will need backend support or local storage
  Future<bool> isMessageStarred(int messageId) async {
    try {
      // TODO: Implement when backend API is available
      // For now, use local storage as a workaround
      return false;
    } catch (e) {
      return false;
    }
  }
}

