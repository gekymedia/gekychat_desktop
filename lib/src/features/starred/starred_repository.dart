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
  Future<List<StarredMessage>> getStarredMessages() async {
    try {
      final response = await _api.get('/starred-messages');
      final data = response.data;
      final messagesData = data['data'] is List ? data['data'] as List : [];
      return messagesData.map((json) => StarredMessage.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load starred messages: $e');
    }
  }

  /// Star a message
  Future<void> starMessage(int messageId, {int? conversationId, int? groupId}) async {
    try {
      if (groupId != null) {
        await _api.post('/groups/$groupId/messages/$messageId/star');
      } else {
        await _api.post('/messages/$messageId/star');
      }
    } catch (e) {
      throw Exception('Failed to star message: $e');
    }
  }

  /// Unstar a message
  Future<void> unstarMessage(int messageId, {int? conversationId, int? groupId}) async {
    try {
      if (groupId != null) {
        await _api.delete('/groups/$groupId/messages/$messageId/star');
      } else {
        await _api.delete('/messages/$messageId/star');
      }
    } catch (e) {
      throw Exception('Failed to unstar message: $e');
    }
  }

  /// Check if a message is starred
  /// This checks by fetching all starred messages and checking if the message ID exists
  Future<bool> isMessageStarred(int messageId) async {
    try {
      final starredMessages = await getStarredMessages();
      return starredMessages.any((msg) => msg.messageId == messageId || msg.groupMessageId == messageId);
    } catch (e) {
      return false;
    }
  }
}

