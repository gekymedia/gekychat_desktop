import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/api_service.dart';
import 'models.dart';
import 'package:dio/dio.dart';

class ChatRepository {
  final ApiService apiService;

  ChatRepository(this.apiService);

  // Conversations
  Future<List<ConversationSummary>> getConversations() async {
    try {
      final response = await apiService.get('/conversations');
      final raw = response.data;
      
      List<dynamic> data;
      if (raw is Map) {
        // Handle different response formats: data, conversations, or direct array
        if (raw['data'] != null) {
          data = raw['data'] as List<dynamic>;
        } else if (raw['conversations'] != null) {
          data = raw['conversations'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response format: expected "data" or "conversations" key. Got: ${raw.keys}');
        }
      } else if (raw is List) {
        data = raw;
      } else {
        throw Exception('Unexpected response format: ${raw.runtimeType}. Response: $raw');
      }
      
      final conversations = data.map((json) => ConversationSummary.fromJson(json)).toList();
      // Sort conversations: pinned first, then by updatedAt
      conversations.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return conversations;
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map 
            ? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to load conversations (HTTP $statusCode): $message');
      }
      throw Exception('Failed to load conversations: $e');
    }
  }

  Future<GroupSummary> createGroup({
    required String name,
    required List<int> memberIds,
    File? avatar,
    String type = 'group',
  }) async {
    try {
      Response response;
      
      if (avatar != null) {
        // Upload with avatar using FormData
        // For Laravel, arrays in FormData need to be sent as separate entries with [] notation
        final formData = FormData();
        formData.fields.add(MapEntry('name', name));
        formData.fields.add(MapEntry('type', type));
        // Add each member as members[] to match Laravel's expected format
        for (final memberId in memberIds) {
          formData.fields.add(MapEntry('members[]', memberId.toString()));
        }
        formData.files.add(
          MapEntry(
            'avatar',
            await MultipartFile.fromFile(
              avatar.path,
              filename: avatar.path.split(Platform.pathSeparator).last,
            ),
          ),
        );
        response = await apiService.post('/groups', data: formData);
      } else {
        // Regular JSON request
        response = await apiService.post(
          '/groups',
          data: {
            'name': name,
            'members': memberIds,
            'type': type,
          },
        );
      }

      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data']
          : raw;

      return GroupSummary.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  Future<ConversationSummary> getConversation(int id) async {
    try {
      final response = await apiService.get('/conversations/$id');
      return ConversationSummary.fromJson(
        response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data),
      );
    } catch (e) {
      throw Exception('Failed to load conversation: $e');
    }
  }

  Future<int> startConversation(int userId) async {
    try {
      final response = await apiService.post('/conversations/start', data: {'user_id': userId});
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data']
          : raw;
      return map['id'] as int;
    } catch (e) {
      throw Exception('Failed to start conversation: $e');
    }
  }

  Future<List<Message>> getConversationMessages(
    int id, {
    int? page,
    DateTime? updatedSince,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (updatedSince != null) {
        params['after'] = updatedSince.toIso8601String();
      }
      if (page != null) {
        params['page'] = page;
      }
      final response = await apiService.get(
        '/conversations/$id/messages',
        queryParameters: params.isEmpty ? null : params,
      );
      final raw = response.data;
      List<dynamic> data;
      
      // Handle different response formats
      if (raw is Map) {
        if (raw['data'] is List) {
          data = raw['data'] as List<dynamic>;
        } else if (raw['messages'] is List) {
          data = raw['messages'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response format: expected "data" or "messages" key. Got: ${raw.keys}');
        }
      } else if (raw is List) {
        data = raw;
      } else {
        throw Exception('Unexpected response format: ${raw.runtimeType}. Response: $raw');
      }
      
      return data
          .map((json) {
            try {
              return Message.fromJson(
                json is Map<String, dynamic>
                    ? json
                    : Map<String, dynamic>.from(json as Map),
              );
            } catch (e) {
              throw Exception('Failed to parse message: $e. Message data: $json');
            }
          })
          .toList();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map 
            ? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to load messages (HTTP $statusCode): $message');
      }
      throw Exception('Failed to load messages: $e');
    }
  }

  Future<Message> sendMessageToConversation({
    required int conversationId,
    String? body,
    int? replyTo,
    int? forwardFrom,
    List<File>? attachments,
  }) async {
    final data = <String, dynamic>{};
    if (body != null) data['body'] = body;
    if (replyTo != null) data['reply_to'] = replyTo;
    if (forwardFrom != null) data['forward_from'] = forwardFrom;
    try {
      Response response;
      final path = '/conversations/$conversationId/messages';
      if (attachments != null && attachments.isNotEmpty) {
        response = await apiService.uploadFiles(path, attachments, data: data);
      } else {
        response = await apiService.post(path, data: data);
      }
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      return Message.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<List<GroupSummary>> getGroups() async {
    try {
      final response = await apiService.get('/groups');
      final raw = response.data;
      
      List<dynamic> data;
      if (raw is Map) {
        // Handle different response formats: data, groups, or direct array
        if (raw['data'] != null) {
          data = raw['data'] as List<dynamic>;
        } else if (raw['groups'] != null) {
          data = raw['groups'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response format: expected "data" or "groups" key. Got: ${raw.keys}');
        }
      } else if (raw is List) {
        data = raw;
      } else {
        throw Exception('Unexpected response format: ${raw.runtimeType}. Response: $raw');
      }
      
      final groups = data.map((json) => GroupSummary.fromJson(json)).toList();
      // Sort groups: pinned first, then by updatedAt
      groups.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return groups;
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map 
            ? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to load groups (HTTP $statusCode): $message');
      }
      throw Exception('Failed to load groups: $e');
    }
  }

  Future<List<Message>> getGroupMessages(int id,
      {int? page, DateTime? updatedSince}) async {
    try {
      final params = {
        if (page != null) 'page': page,
        if (updatedSince != null) 'updated_since': updatedSince.toIso8601String(),
      };
      
      final response = await apiService.get(
        '/groups/$id/messages',
        queryParameters: params,
      );
      
      final raw = response.data;
      List<dynamic> data;
      
      // Handle different response formats
      if (raw is Map) {
        if (raw['data'] is List) {
          data = raw['data'] as List<dynamic>;
        } else if (raw['messages'] is List) {
          data = raw['messages'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response format: expected "data" or "messages" key. Got: ${raw.keys}');
        }
      } else if (raw is List) {
        data = raw;
      } else {
        throw Exception('Unexpected response format: ${raw.runtimeType}. Response: $raw');
      }
      
      return data
          .map((json) {
            try {
              return Message.fromJson(
                json is Map<String, dynamic>
                    ? json
                    : Map<String, dynamic>.from(json as Map),
              );
            } catch (e) {
              throw Exception('Failed to parse message: $e. Message data: $json');
            }
          })
          .toList();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map 
            ? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to load group messages (HTTP $statusCode): $message');
      }
      throw Exception('Failed to load group messages: $e');
    }
  }

  Future<Message> sendMessageToGroup({
    required int groupId,
    String? body,
    int? replyToId,
    int? forwardFrom,
    List<File>? attachments,
  }) async {
    try {
      final data = <String, dynamic>{
        if (body != null) 'body': body,
        if (replyToId != null) 'reply_to': replyToId,
        if (forwardFrom != null) 'forward_from_id': forwardFrom,
      };

      // Upload attachments first and get their IDs
      // MEDIA COMPRESSION: Use medium compression level by default
      if (attachments != null && attachments.isNotEmpty) {
        List<int> attachmentIds = [];
        for (final file in attachments) {
          final uploadResponse = await apiService.uploadAttachment(file, compressionLevel: 'medium');
          final attachmentData = uploadResponse.data;
          final attachment = attachmentData is Map && attachmentData['data'] != null
              ? attachmentData['data'] as Map<String, dynamic>
              : attachmentData as Map<String, dynamic>;
          attachmentIds.add(attachment['id'] as int);
        }
        data['attachments'] = attachmentIds;
      }

      final response = await apiService.post('/groups/$groupId/messages', data: data);
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      return Message.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to send group message: $e');
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      await apiService.deleteMessage(messageId);
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  Future<Message> editMessage(int messageId, String newBody) async {
    try {
      final response = await apiService.editMessage(messageId, newBody);
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data']
          : raw;
      return Message.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }

  Future<void> reactToMessage(int messageId, String emoji, {bool isGroupMessage = false}) async {
    try {
      final endpoint = isGroupMessage 
          ? '/group-messages/$messageId/react'
          : '/messages/$messageId/react';
      await apiService.post(endpoint, data: {'emoji': emoji});
    } catch (e) {
      throw Exception('Failed to react to message: $e');
    }
  }

  Future<void> removeReaction(int messageId) async {
    try {
      await apiService.delete('/messages/$messageId/react');
    } catch (e) {
      throw Exception('Failed to remove reaction: $e');
    }
  }

  Future<void> markAsRead(int conversationId, List<int> messageIds) async {
    try {
      for (final id in messageIds) {
        await apiService.post('/messages/$id/read');
      }
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  Future<void> sendTypingIndicator(int conversationId, bool isTyping) async {
    try {
      if (isTyping) {
        await apiService.post('/conversations/$conversationId/typing', data: {'is_typing': true});
      } else {
        await apiService.delete('/conversations/$conversationId/typing');
      }
    } catch (e) {
      throw Exception('Failed to send typing indicator: $e');
    }
  }

  Future<void> pinConversation(int conversationId) async {
    try {
      await apiService.pinConversation(conversationId);
    } catch (e) {
      throw Exception('Failed to pin conversation: $e');
    }
  }

  Future<void> unpinConversation(int conversationId) async {
    try {
      await apiService.unpinConversation(conversationId);
    } catch (e) {
      throw Exception('Failed to unpin conversation: $e');
    }
  }

  Future<void> markConversationUnread(int conversationId) async {
    try {
      await apiService.markConversationUnread(conversationId);
    } catch (e) {
      throw Exception('Failed to mark conversation as unread: $e');
    }
  }

  // Group Actions
  Future<void> pinGroup(int groupId) async {
    try {
      await apiService.pinGroup(groupId);
    } catch (e) {
      throw Exception('Failed to pin group: $e');
    }
  }

  Future<void> unpinGroup(int groupId) async {
    try {
      await apiService.unpinGroup(groupId);
    } catch (e) {
      throw Exception('Failed to unpin group: $e');
    }
  }

  Future<void> muteGroup(int groupId, {int? minutes, DateTime? until}) async {
    try {
      await apiService.muteGroup(groupId, minutes: minutes, until: until);
    } catch (e) {
      throw Exception('Failed to mute group: $e');
    }
  }

  Future<void> unmuteGroup(int groupId) async {
    try {
      await apiService.unmuteGroup(groupId);
    } catch (e) {
      throw Exception('Failed to unmute group: $e');
    }
  }

  Future<Message> shareLocationInConversation(
    int conversationId, {
    required double latitude,
    required double longitude,
    String? address,
    String? placeName,
  }) async {
    try {
      final response = await apiService.shareLocationInConversation(
        conversationId,
        latitude: latitude,
        longitude: longitude,
        address: address,
        placeName: placeName,
      );
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      return Message.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to share location: $e');
    }
  }

  Future<Message> shareLocationInGroup(
    int groupId, {
    required double latitude,
    required double longitude,
    String? address,
    String? placeName,
  }) async {
    try {
      final response = await apiService.shareLocationInGroup(
        groupId,
        latitude: latitude,
        longitude: longitude,
        address: address,
        placeName: placeName,
      );
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      return Message.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to share location: $e');
    }
  }

  Future<Message> shareContactInConversation(
    int conversationId, {
    int? contactId,
    String? name,
    String? phone,
    String? email,
  }) async {
    try {
      final response = await apiService.shareContactInConversation(
        conversationId,
        contactId: contactId,
        name: name,
        phone: phone,
        email: email,
      );
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      return Message.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to share contact: $e');
    }
  }

  Future<Message> shareContactInGroup(
    int groupId, {
    int? contactId,
    String? name,
    String? phone,
    String? email,
  }) async {
    try {
      final response = await apiService.shareContactInGroup(
        groupId,
        contactId: contactId,
        name: name,
        phone: phone,
        email: email,
      );
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      return Message.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to share contact: $e');
    }
  }

  Future<void> archiveConversation(int conversationId) async {
    try {
      await apiService.archiveConversation(conversationId);
    } catch (e) {
      throw Exception('Failed to archive conversation: $e');
    }
  }

  Future<void> unarchiveConversation(int conversationId) async {
    try {
      await apiService.unarchiveConversation(conversationId);
    } catch (e) {
      throw Exception('Failed to unarchive conversation: $e');
    }
  }

  Future<void> promoteGroupAdmin(int groupId, int userId) async {
    try {
      await apiService.promoteGroupAdmin(groupId, userId);
    } catch (e) {
      throw Exception('Failed to promote admin: $e');
    }
  }

  Future<void> demoteGroupAdmin(int groupId, int userId) async {
    try {
      await apiService.demoteGroupAdmin(groupId, userId);
    } catch (e) {
      throw Exception('Failed to demote admin: $e');
    }
  }

  Future<void> removeGroupMember(int groupId, int userId) async {
    try {
      await apiService.removeGroupMember(groupId, userId);
    } catch (e) {
      throw Exception('Failed to remove member: $e');
    }
  }

  Future<void> leaveGroup(int groupId) async {
    try {
      await apiService.leaveGroup(groupId);
    } catch (e) {
      throw Exception('Failed to leave group: $e');
    }
  }

  Future<void> updateGroup(int groupId, {String? name, String? description, File? avatar}) async {
    try {
      if (avatar != null) {
        final formData = FormData();
        if (name != null) formData.fields.add(MapEntry('name', name));
        if (description != null) formData.fields.add(MapEntry('description', description));
        formData.files.add(
          MapEntry(
            'avatar',
            await MultipartFile.fromFile(
              avatar.path,
              filename: avatar.path.split(Platform.pathSeparator).last,
            ),
          ),
        );
        await apiService.put('/groups/$groupId', data: formData);
      } else {
        final data = <String, dynamic>{};
        if (name != null) data['name'] = name;
        if (description != null) data['description'] = description;
        await apiService.put('/groups/$groupId', data: data);
      }
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }

  Future<GroupSummary> getGroupDetails(int groupId) async {
    try {
      final response = await apiService.get('/groups/$groupId');
      return GroupSummary.fromJson(response.data['data']);
    } catch (e) {
      throw Exception('Failed to load group details: $e');
    }
  }

  Future<void> addGroupMembers(int groupId, List<int> userIds) async {
    try {
      // Get user phones from the user IDs
      final conversations = await getConversations();
      final userPhones = <String>[];
      
      for (final userId in userIds) {
        final conversation = conversations.firstWhere(
          (c) => c.otherUser.id == userId,
          orElse: () => throw Exception('User not found in conversations'),
        );
        if (conversation.otherUser.phone != null) {
          userPhones.add(conversation.otherUser.phone!);
        }
      }
      
      await apiService.addGroupMember(groupId, {'phones': userPhones});
    } catch (e) {
      throw Exception('Failed to add group members: $e');
    }
  }

  Future<String> exportConversation(int conversationId) async {
    try {
      final response = await apiService.exportConversation(conversationId);
      return response.data['data']['content'] ?? '';
    } catch (e) {
      throw Exception('Failed to export conversation: $e');
    }
  }

  Future<void> clearConversation(int conversationId) async {
    try {
      await apiService.clearConversation(conversationId);
    } catch (e) {
      throw Exception('Failed to clear conversation: $e');
    }
  }

  Future<void> deleteConversation(int conversationId) async {
    try {
      await apiService.deleteConversation(conversationId);
    } catch (e) {
      throw Exception('Failed to delete conversation: $e');
    }
  }

  Future<List<ConversationSummary>> getArchivedConversations() async {
    try {
      final response = await apiService.getArchivedConversations();
      final raw = response.data;
      List<dynamic> data;
      if (raw is Map && raw['data'] is List) {
        data = raw['data'] as List<dynamic>;
      } else if (raw is Map && raw['conversations'] is List) {
        data = raw['conversations'] as List<dynamic>;
      } else if (raw is List) {
        data = raw;
      } else {
        throw Exception('Unexpected response format: expected "data" or "conversations" key. Got: ${raw.keys}');
      }
      
      return data.map((json) => ConversationSummary.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map 
            ? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to load archived conversations (HTTP $statusCode): $message');
      }
      throw Exception('Failed to load archived conversations: $e');
    }
  }

  Future<Map<String, dynamic>> replyPrivatelyToGroupMessage(int groupId, int messageId) async {
    try {
      final response = await apiService.post('/groups/$groupId/messages/$messageId/reply-private');
      return response.data['data'] ?? {};
    } catch (e) {
      throw Exception('Failed to reply privately: $e');
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return ChatRepository(apiService);
});

