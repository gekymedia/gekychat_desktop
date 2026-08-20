import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/api_service.dart';
import '../../core/database/local_storage_service.dart';
import '../../services/product_analytics_service.dart';
import 'models.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatRepository {
  final ApiService apiService;
  final LocalStorageService? localStorageService;
  final bool isOnline;

  static const int _initialMessagesLimit = 100;
  static const int _olderMessagesLimit = 50;

  ChatRepository(this.apiService, {this.localStorageService, this.isOnline = true});

  static bool _localPreviewIsNewer(DateTime? local, DateTime? remote) {
    if (local == null) return false;
    if (remote == null) return true;
    return local.isAfter(remote);
  }

  static int _mergedUnreadCount(int apiUnread, int localUnread) {
    return localUnread < apiUnread ? localUnread : apiUnread;
  }

  Future<List<ConversationSummary>> _mergeConversationsWithLocalPreview(
    List<ConversationSummary> fromApi,
  ) async {
    if (localStorageService == null || fromApi.isEmpty) return fromApi;
    try {
      final localRows = await localStorageService!.loadConversations();
      if (localRows.isEmpty) return fromApi;
      final localById = {for (final row in localRows) row.id: row};
      return fromApi.map((api) {
        final local = localById[api.id];
        if (local == null) return api;

        final unreadCount = _mergedUnreadCount(api.unreadCount, local.unreadCount);
        final useLocalPreview =
            _localPreviewIsNewer(local.updatedAt, api.updatedAt);

        if (!useLocalPreview && unreadCount == api.unreadCount) {
          return api;
        }

        if (!useLocalPreview) {
          return ConversationSummary(
            id: api.id,
            otherUser: api.otherUser,
            lastMessage: api.lastMessage,
            lastMessageFromMe: api.lastMessageFromMe,
            lastMessageOutgoingStatus: api.lastMessageOutgoingStatus,
            unreadCount: unreadCount,
            updatedAt: api.updatedAt,
            isPinned: api.isPinned,
            isMuted: api.isMuted,
            archivedAt: api.archivedAt,
            labelIds: api.labelIds,
            isSavedMessages: api.isSavedMessages,
          );
        }

        return ConversationSummary(
          id: api.id,
          otherUser: api.otherUser,
          lastMessage: local.lastMessage ?? api.lastMessage,
          lastMessageFromMe: local.lastMessageFromMe,
          lastMessageOutgoingStatus:
              local.lastMessageOutgoingStatus ?? api.lastMessageOutgoingStatus,
          unreadCount: unreadCount,
          updatedAt: local.updatedAt,
          isPinned: api.isPinned,
          isMuted: api.isMuted,
          archivedAt: api.archivedAt,
          labelIds: api.labelIds,
          isSavedMessages: api.isSavedMessages,
        );
      }).toList();
    } catch (_) {
      return fromApi;
    }
  }

  Future<List<GroupSummary>> _mergeGroupsWithLocalPreview(
    List<GroupSummary> fromApi,
  ) async {
    if (localStorageService == null || fromApi.isEmpty) return fromApi;
    try {
      final localRows = await localStorageService!.loadGroups();
      if (localRows.isEmpty) return fromApi;
      final localById = {for (final row in localRows) row.id: row};
      return fromApi.map((api) {
        final local = localById[api.id];
        if (local == null) return api;

        final unreadCount = _mergedUnreadCount(api.unreadCount, local.unreadCount);
        final useLocalPreview =
            _localPreviewIsNewer(local.updatedAt, api.updatedAt);

        if (!useLocalPreview && unreadCount == api.unreadCount) {
          return api;
        }

        if (!useLocalPreview) {
          return GroupSummary(
            id: api.id,
            name: api.name,
            avatarUrl: api.avatarUrl,
            unreadCount: unreadCount,
            memberCount: api.memberCount,
            updatedAt: api.updatedAt,
            type: api.type,
            isVerified: api.isVerified,
            lastMessage: api.lastMessage,
            lastMessageFromMe: api.lastMessageFromMe,
            lastMessageOutgoingStatus: api.lastMessageOutgoingStatus,
            isPinned: api.isPinned,
            isMuted: api.isMuted,
            labelIds: api.labelIds,
          );
        }

        return GroupSummary(
          id: api.id,
          name: api.name,
          avatarUrl: api.avatarUrl,
          unreadCount: unreadCount,
          memberCount: api.memberCount,
          updatedAt: local.updatedAt,
          type: api.type,
          isVerified: api.isVerified,
          lastMessage: local.lastMessage ?? api.lastMessage,
          lastMessageFromMe: local.lastMessageFromMe,
          lastMessageOutgoingStatus:
              local.lastMessageOutgoingStatus ?? api.lastMessageOutgoingStatus,
          isPinned: api.isPinned,
          isMuted: api.isMuted,
          labelIds: api.labelIds,
        );
      }).toList();
    } catch (_) {
      return fromApi;
    }
  }

  static Message _enrichFromCache(Message api, Message? cached) {
    if (cached == null) return api;
    var msg = api;
    final preview = api.replyToPreview;
    if ((preview == null || preview.isEmpty) &&
        cached.replyToPreview != null &&
        cached.replyToPreview!.isNotEmpty) {
      msg = msg.copyWith(replyToPreview: cached.replyToPreview);
    }
    return msg;
  }

  /// Keep cached rows the API batch omitted (realtime upserts, optimistic sends).
  static List<Message> mergeMessageHistory(
    List<Message> cached,
    List<Message> fromApi,
  ) {
    if (fromApi.isEmpty) return cached;
    if (cached.isEmpty) return fromApi;

    final cachedById = {
      for (final m in cached)
        if (m.id > 0) m.id: m,
    };
    final apiById = {for (final m in fromApi) m.id: m};
    final merged = fromApi
        .map((m) => _enrichFromCache(m, cachedById[m.id]))
        .toList();

    for (final m in cached) {
      if (m.id > 0 && !apiById.containsKey(m.id)) {
        merged.add(m);
      } else if (m.id <= 0 &&
          m.clientId != null &&
          m.clientId!.isNotEmpty &&
          !fromApi.any((a) => a.clientId == m.clientId)) {
        merged.add(m);
      }
    }

    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  Future<void> persistConversationMessages(
    int conversationId,
    List<Message> messages,
  ) async {
    if (localStorageService == null || messages.isEmpty) return;
    try {
      final cached = await localStorageService!.loadMessages(conversationId);
      final merged = mergeMessageHistory(cached, messages);
      await localStorageService!.saveMessages(conversationId, merged);
    } catch (e) {
      debugPrint('persistConversationMessages failed: $e');
    }
  }

  Future<void> persistGroupMessages(int groupId, List<Message> messages) async {
    if (localStorageService == null || messages.isEmpty) return;
    try {
      final cached = await localStorageService!.loadGroupMessages(groupId);
      final merged = mergeMessageHistory(cached, messages);
      await localStorageService!.saveGroupMessages(groupId, merged);
    } catch (e) {
      debugPrint('persistGroupMessages failed: $e');
    }
  }

  /// Pull messages newer than the highest id in local cache (`after_id` delta sync).
  /// When no cache exists, fetches the latest page instead.
  Future<List<Message>> pullNewMessagesForConversation(int conversationId) async {
    if (!isOnline) return const [];

    final storage = localStorageService;
    final lastId =
        storage != null ? await storage.getMaxMessageIdForConversation(conversationId) : null;

    if (lastId == null || lastId <= 0) {
      return getConversationMessages(conversationId);
    }

    final pulled = <Message>[];
    var cursor = lastId;
    while (true) {
      final response = await apiService.get(
        '/conversations/$conversationId/messages',
        queryParameters: {'after_id': cursor, 'limit': 100},
      );
      final data = _messageListFromResponse(response.data);
      final batch =
          _parseMessageList(data, contextLabel: 'DM#$conversationId delta');
      if (batch.isEmpty) break;

      pulled.addAll(batch);
      await persistConversationMessages(conversationId, batch);

      final maxId = batch.map((m) => m.id).reduce((a, b) => a > b ? a : b);
      if (batch.length < 100) break;
      cursor = maxId;
    }
    return pulled;
  }

  /// Pull group messages newer than the highest id in local cache.
  Future<List<Message>> pullNewMessagesForGroup(int groupId) async {
    if (!isOnline) return const [];

    final storage = localStorageService;
    final lastId =
        storage != null ? await storage.getMaxMessageIdForGroup(groupId) : null;

    try {
      if (lastId == null || lastId <= 0) {
        return getGroupMessages(groupId);
      }

      final pulled = <Message>[];
      var cursor = lastId;
      while (true) {
        final response = await apiService.get(
          '/groups/$groupId/messages',
          queryParameters: {'after_id': cursor, 'limit': 100},
        );
        final data = _messageListFromResponse(response.data);
        final batch =
            _parseMessageList(data, contextLabel: 'group#$groupId delta');
        if (batch.isEmpty) break;

        pulled.addAll(batch);
        await persistGroupMessages(groupId, batch);

        final maxId = batch.map((m) => m.id).reduce((a, b) => a > b ? a : b);
        if (batch.length < 100) break;
        cursor = maxId;
      }
      return pulled;
    } on DioException catch (e) {
      if (_isGroupAccessDenied(e)) {
        await _evictInaccessibleGroup(groupId);
        return const [];
      }
      rethrow;
    }
  }

  static bool _isGroupAccessDenied(DioException e) =>
      e.response?.statusCode == 403;

  Future<void> _evictInaccessibleGroup(int groupId) async {
    try {
      await localStorageService?.removeGroup(groupId);
    } catch (e) {
      debugPrint('group#$groupId: evict from local cache failed: $e');
    }
  }

  /// Laravel may return `{ "data": [ ... ] }` or wrap resources as `{ "data": { "data": [ ... ] } }`.
  static List<dynamic> _messageListFromResponse(dynamic raw) {
    if (raw is List) {
      return List<dynamic>.from(raw);
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final top = map['data'];
      if (top is List) {
        return List<dynamic>.from(top);
      }
      if (top is Map) {
        final inner = Map<String, dynamic>.from(top);
        if (inner['data'] is List) {
          return List<dynamic>.from(inner['data'] as List);
        }
        if (inner['messages'] is List) {
          return List<dynamic>.from(inner['messages'] as List);
        }
      }
      if (map['messages'] is List) {
        return List<dynamic>.from(map['messages'] as List);
      }
    }
    throw FormatException(
      'Unexpected messages JSON (expected list or data/messages map). type=${raw.runtimeType}',
    );
  }

  static Map<String, dynamic> _normalizeMessageJson(dynamic item) {
    if (item is Map<String, dynamic>) {
      if (item.length == 1 && item['data'] is Map) {
        return Map<String, dynamic>.from(item['data'] as Map);
      }
      return item;
    }
    if (item is Map) {
      final map = Map<String, dynamic>.from(item);
      if (map.length == 1 && map['data'] is Map) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      return map;
    }
    throw FormatException('Message item is not a map: ${item.runtimeType}');
  }

  static List<Message> _parseMessageList(
    List<dynamic> data, {
    required String contextLabel,
  }) {
    final messages = <Message>[];
    for (final item in data) {
      try {
        messages.add(Message.fromJson(_normalizeMessageJson(item)));
      } catch (e, st) {
        debugPrint('Skipping malformed $contextLabel message from API: $e');
        debugPrint('$st');
      }
    }
    if (data.isNotEmpty && messages.isEmpty) {
      debugPrint(
        '⚠️ $contextLabel: API returned ${data.length} item(s) but none parsed',
      );
    }
    return messages;
  }

  // Conversations
  Future<List<ConversationSummary>> getConversations() async {
    // If offline, try to load from local storage
    if (!isOnline && localStorageService != null) {
      try {
        final conversations = await localStorageService!.loadConversations();
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
        // If local storage fails, return empty list
        return [];
      }
    }
    
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
      final mergedConversations =
          await _mergeConversationsWithLocalPreview(conversations);
      // Sort conversations: pinned first, then by updatedAt
      mergedConversations.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      
      // Save to local storage if available
      if (localStorageService != null) {
        await localStorageService!.saveConversations(mergedConversations);
      }
      
      return mergedConversations;
    } catch (e) {
      // If API fails (including 401), try to load from local storage
      if (localStorageService != null) {
        try {
          final conversations = await localStorageService!.loadConversations();
          conversations.sort((a, b) {
            if (a.isPinned != b.isPinned) {
              return a.isPinned ? -1 : 1;
            }
            final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return conversations;
        } catch (localError) {
          // Ignore local storage errors
        }
      }
      
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        // For 401 (unauthenticated), return empty list instead of throwing
        if (statusCode == 401) {
          return [];
        }
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
    String? description,
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
        if (description != null && description.isNotEmpty) {
          formData.fields.add(MapEntry('description', description));
        }
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
            if (description != null && description.isNotEmpty) 'description': description,
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

  /// Persist a newly created group locally so it appears in the sidebar immediately.
  Future<void> cacheGroupToDatabase(GroupSummary group) async {
    if (localStorageService == null) return;
    await localStorageService!.saveGroups([group]);
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
    List<Message> cached = const [];
    if (localStorageService != null) {
      try {
        cached = await localStorageService!.loadMessages(id);
      } catch (_) {}
    }

    // Serve cache immediately when offline and we have history.
    if (!isOnline && cached.isNotEmpty) {
      return cached;
    }

    try {
      final params = <String, dynamic>{
        'limit': _initialMessagesLimit,
        // Newest page first (WhatsApp-style). Without this, long threads only
        // return the oldest messages and notification replies never appear.
        // Laravel boolean validation accepts 0/1, not the string "true".
        'recent': 1,
      };
      if (updatedSince != null) {
        params['after_timestamp'] = updatedSince.toIso8601String();
      }
      if (page != null) {
        params['page'] = page;
      }
      final response = await apiService.get(
        '/conversations/$id/messages',
        queryParameters: params,
      );
      final raw = response.data;
      final List<dynamic> data = _messageListFromResponse(raw);
      final messages = _parseMessageList(data, contextLabel: 'DM#$id');

      if (messages.isNotEmpty && localStorageService != null) {
        try {
          final merged = mergeMessageHistory(cached, messages);
          await localStorageService!.saveMessages(id, merged, page: page);
        } catch (e) {
          debugPrint('DM#$id: cache save failed (non-fatal): $e');
        }
      }

      if (messages.isNotEmpty) {
        return mergeMessageHistory(cached, messages);
      }
      // API returned nothing parseable — keep showing cache if we have it.
      if (cached.isNotEmpty) {
        return cached;
      }
      return messages;
    } catch (e) {
      if (cached.isNotEmpty) {
        debugPrint('DM#$id messages API failed, using cache: $e');
        return cached;
      }

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

  Future<({List<Message> messages, bool hasMore})> getOlderConversationMessages(
    int conversationId,
    int beforeMessageId,
  ) async {
    try {
      final response = await apiService.get(
        '/conversations/$conversationId/messages',
        queryParameters: {
          'before': beforeMessageId,
          'limit': _olderMessagesLimit,
        },
      );
      final raw = response.data;
      final List<dynamic> data = _messageListFromResponse(raw);
      final messages = _parseMessageList(
        data,
        contextLabel: 'DM#$conversationId older',
      );
      final hasMore = raw is Map && raw['meta'] is Map
          ? (raw['meta'] as Map)['has_more'] as bool? ??
              (messages.length >= _olderMessagesLimit)
          : messages.length >= _olderMessagesLimit;

      if (messages.isNotEmpty) {
        await persistConversationMessages(conversationId, messages);
      }
      return (messages: messages, hasMore: hasMore);
    } catch (e) {
      debugPrint('getOlderConversationMessages failed: $e');
      return (messages: <Message>[], hasMore: false);
    }
  }

  Future<({List<Message> messages, bool hasMore})> getOlderGroupMessages(
    int groupId,
    DateTime beforeCreatedAt,
  ) async {
    try {
      final response = await apiService.get(
        '/groups/$groupId/messages',
        queryParameters: {
          'before': beforeCreatedAt.toUtc().toIso8601String(),
          'limit': _olderMessagesLimit,
        },
      );
      final raw = response.data;
      final List<dynamic> data = _messageListFromResponse(raw);
      final messages = _parseMessageList(
        data,
        contextLabel: 'group#$groupId older',
      );
      final hasMore = messages.length >= _olderMessagesLimit;

      if (messages.isNotEmpty) {
        await persistGroupMessages(groupId, messages);
      }
      return (messages: messages, hasMore: hasMore);
    } catch (e) {
      debugPrint('getOlderGroupMessages failed: $e');
      return (messages: <Message>[], hasMore: false);
    }
  }

  Future<Message> sendMessageToConversation({
    required int conversationId,
    String? body,
    int? replyTo,
    int? forwardFrom,
    List<File>? attachments,
    bool skipCompression = false,
    void Function(double progress)? onProgress,
    String? clientUuid,
    int? referencedStatusId,
    int? referencedGroupId,
    int? referencedGroupMessageId,
    String? messageType,
    bool viewOnce = false,
    /// When true (typically one audio file, no body), mark upload as voice note on the server.
    bool voiceNote = false,
    DateTime? scheduledAt,
    int? expiresInHours,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': messageType ?? 'text',
        if (body != null) 'body': body,
        if (replyTo != null) 'reply_to': replyTo,
        if (replyTo != null) 'reply_to_id': replyTo,
        if (forwardFrom != null) 'forward_from': forwardFrom,
        if (clientUuid != null) 'client_uuid': clientUuid,
        if (referencedStatusId != null) 'referenced_status_id': referencedStatusId,
        if (referencedGroupId != null) 'referenced_group_id': referencedGroupId,
        if (referencedGroupMessageId != null)
          'referenced_group_message_id': referencedGroupMessageId,
        if (viewOnce) 'view_once': true,
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (expiresInHours != null && expiresInHours > 0) 'expires_in': expiresInHours,
      };

      // Upload attachments first and get their IDs
      // MEDIA COMPRESSION: Use medium compression level by default, but skip for voice messages
      if (attachments != null && attachments.isNotEmpty) {
        debugPrint('📤 [SEND MESSAGE] sendMessageToConversation called with ${attachments.length} attachment(s)');
        List<int> attachmentIds = [];
        final totalFiles = attachments.length;
        debugPrint('📤 [UPLOAD] Starting upload of $totalFiles attachment(s)');
        
        for (int i = 0; i < attachments.length; i++) {
          final file = attachments[i];
          try {
            debugPrint('📤 [UPLOAD] Processing attachment ${i + 1}/$totalFiles');
            debugPrint('📤 [UPLOAD] File path: ${file.path}');
            debugPrint('📤 [UPLOAD] File basename: ${file.path.split(Platform.pathSeparator).last}');
            debugPrint('📤 [UPLOAD] File extension: ${file.path.split('.').last}');
            
            if (!await file.exists()) {
              throw Exception('File does not exist: ${file.path}');
            }
            // Determine file type and compression
            final path = file.path.toLowerCase();
            debugPrint('📤 [UPLOAD] Lowercase path: $path');
            
            final isImage = path.endsWith('.jpg') || path.endsWith('.jpeg') || 
                           path.endsWith('.png') || path.endsWith('.gif') || 
                           path.endsWith('.webp') || path.endsWith('.bmp');
            final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') || 
                           path.endsWith('.avi') || path.endsWith('.mkv') || 
                           path.endsWith('.webm');
            final isAudio = path.endsWith('.m4a') || path.endsWith('.aac') ||
                           path.endsWith('.mp3') || path.endsWith('.wav') ||
                           path.endsWith('.ogg') || path.endsWith('.flac');
            
            debugPrint('📤 [UPLOAD] File type detection:');
            debugPrint('📤 [UPLOAD]   - isImage: $isImage');
            debugPrint('📤 [UPLOAD]   - isVideo: $isVideo');
            debugPrint('📤 [UPLOAD]   - isAudio: $isAudio');
            
            // Only compress images and videos, not documents or audio
            // Documents should be uploaded as-is (no compression) like WhatsApp
            final compressionLevel = (skipCompression || isAudio || (!isImage && !isVideo)) 
                ? 'none' 
                : 'medium';
            
            debugPrint('📤 [UPLOAD] Compression level: $compressionLevel');
            debugPrint('📤 [UPLOAD] skipCompression flag: $skipCompression');
            
            // Calculate progress: each file contributes 1/totalFiles to overall progress
            // Within each file, progress goes from i/totalFiles to (i+1)/totalFiles
            final fileStartProgress = i / totalFiles;
            final fileEndProgress = (i + 1) / totalFiles;
            
            debugPrint('📤 [UPLOAD] Calling uploadAttachment with:');
            debugPrint('📤 [UPLOAD]   - file.path: ${file.path}');
            debugPrint('📤 [UPLOAD]   - compressionLevel: $compressionLevel');
            
            final uploadResponse = await apiService.uploadAttachment(
              file,
              compressionLevel: compressionLevel,
              isVoicenote: voiceNote && totalFiles == 1,
              onSendProgress: onProgress != null
                  ? (sent, total) {
                      // Map file progress to overall progress
                      final fileProgress = sent / total;
                      final overallProgress = fileStartProgress + (fileProgress * (fileEndProgress - fileStartProgress));
                      onProgress(overallProgress);
                    }
                  : null,
            );
            final attachmentData = uploadResponse.data;
            final attachment = attachmentData is Map && attachmentData['data'] != null
                ? attachmentData['data'] as Map<String, dynamic>
                : attachmentData as Map<String, dynamic>;
            if (attachment['id'] == null) {
              throw Exception('Upload failed: No attachment ID returned');
            }
            attachmentIds.add(attachment['id'] as int);
            
            // Update progress to show this file is complete
            if (onProgress != null) {
              onProgress(fileEndProgress);
            }
          } catch (e) {
            throw Exception('Failed to upload attachment ${file.path}: $e');
          }
        }
        data['attachments'] = attachmentIds;
      }
      
      // Set progress to 100% when sending message (if no attachments, this is the only step)
      if (onProgress != null && (attachments == null || attachments.isEmpty)) {
        onProgress(1.0);
      }

      final response = await apiService.post('/conversations/$conversationId/messages', data: data);
      
      // Set progress to 100% after message is sent
      if (onProgress != null) {
        onProgress(1.0);
      }
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      ProductAnalytics.action(
        'message_sent',
        feature: 'chats',
        properties: {'conversation_id': conversationId},
      );
      final message = Message.fromJson(Map<String, dynamic>.from(map));
      // Ensure non-UI senders (notification reply, share, etc.) update local history.
      unawaited(persistConversationMessages(conversationId, [message]));
      return message;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<List<GroupSummary>> getGroups() async {
    // If offline, try to load from local storage
    if (!isOnline && localStorageService != null) {
      try {
        final groups = await localStorageService!.loadGroups();
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
        // If local storage fails, return empty list
        return [];
      }
    }
    
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
      final mergedGroups = await _mergeGroupsWithLocalPreview(groups);
      // Sort groups: pinned first, then by updatedAt
      mergedGroups.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      
      // Save to local storage if available
      if (localStorageService != null) {
        await localStorageService!.saveGroups(mergedGroups);
      }
      
      return mergedGroups;
    } catch (e) {
      // If API fails and we have local storage, try to load from there
      if (localStorageService != null) {
        try {
          final groups = await localStorageService!.loadGroups();
          groups.sort((a, b) {
            if (a.isPinned != b.isPinned) {
              return a.isPinned ? -1 : 1;
            }
            final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return groups;
        } catch (localError) {
          // Ignore local storage errors
        }
      }
      
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        // Return empty list on 401 (unauthenticated) instead of throwing
        if (statusCode == 401) {
          return [];
        }
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
    List<Message> cached = const [];
    if (localStorageService != null) {
      try {
        cached = await localStorageService!.loadGroupMessages(id);
      } catch (_) {}
    }

    if (!isOnline && cached.isNotEmpty) {
      return cached;
    }

    try {
      final params = <String, dynamic>{'limit': _initialMessagesLimit};
      if (page != null) params['page'] = page;
      if (updatedSince != null) {
        params['after'] = updatedSince.toIso8601String();
      }

      final response = await apiService.get(
        '/groups/$id/messages',
        queryParameters: params,
      );

      final raw = response.data;
      final List<dynamic> data = _messageListFromResponse(raw);
      final messages = _parseMessageList(data, contextLabel: 'group#$id');

      if (messages.isNotEmpty && localStorageService != null) {
        try {
          final merged = mergeMessageHistory(cached, messages);
          await localStorageService!.saveGroupMessages(id, merged, page: page);
        } catch (e) {
          debugPrint('group#$id: cache save failed (non-fatal): $e');
        }
      }

      if (messages.isNotEmpty) {
        return mergeMessageHistory(cached, messages);
      }
      if (cached.isNotEmpty) {
        return cached;
      }
      return messages;
    } catch (e) {
      if (e is DioException && _isGroupAccessDenied(e)) {
        await _evictInaccessibleGroup(id);
        if (cached.isNotEmpty) return cached;
        return const [];
      }

      if (cached.isNotEmpty) {
        debugPrint('group#$id messages API failed, using cache: $e');
        return cached;
      }

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
    bool skipCompression = false,
    void Function(double progress)? onProgress,
    String? clientUuid,
    String? messageType,
    bool viewOnce = false,
    bool voiceNote = false,
    DateTime? scheduledAt,
    int? expiresInHours,
    int? referencedStatusId,
    int? referencedGroupId,
    int? referencedGroupMessageId,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': messageType ?? 'text',
        if (body != null) 'body': body,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (forwardFrom != null) 'forward_from_id': forwardFrom,
        if (clientUuid != null) 'client_uuid': clientUuid,
        if (viewOnce) 'view_once': true,
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (expiresInHours != null && expiresInHours > 0) 'expires_in': expiresInHours,
        if (referencedStatusId != null) 'referenced_status_id': referencedStatusId,
        if (referencedGroupId != null) 'referenced_group_id': referencedGroupId,
        if (referencedGroupMessageId != null)
          'referenced_group_message_id': referencedGroupMessageId,
      };

      // Upload attachments first and get their IDs
      // MEDIA COMPRESSION: Use medium compression level by default, but skip for voice messages
      if (attachments != null && attachments.isNotEmpty) {
        List<int> attachmentIds = [];
        final totalFiles = attachments.length;
        for (int i = 0; i < attachments.length; i++) {
          final file = attachments[i];
          try {
            if (!await file.exists()) {
              throw Exception('File does not exist: ${file.path}');
            }
            // Determine file type and compression
            final path = file.path.toLowerCase();
            final isImage = path.endsWith('.jpg') || path.endsWith('.jpeg') || 
                           path.endsWith('.png') || path.endsWith('.gif') || 
                           path.endsWith('.webp') || path.endsWith('.bmp');
            final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') || 
                           path.endsWith('.avi') || path.endsWith('.mkv') || 
                           path.endsWith('.webm');
            final isAudio = path.endsWith('.m4a') || path.endsWith('.aac') ||
                           path.endsWith('.mp3') || path.endsWith('.wav') ||
                           path.endsWith('.ogg') || path.endsWith('.flac');
            // Only compress images and videos, not documents or audio
            // Documents should be uploaded as-is (no compression) like WhatsApp
            final compressionLevel = (skipCompression || isAudio || (!isImage && !isVideo)) 
                ? 'none' 
                : 'medium';
            
            // Calculate progress: each file contributes 1/totalFiles to overall progress
            // Within each file, progress goes from i/totalFiles to (i+1)/totalFiles
            final fileStartProgress = i / totalFiles;
            final fileEndProgress = (i + 1) / totalFiles;
            
            final uploadResponse = await apiService.uploadAttachment(
              file,
              compressionLevel: compressionLevel,
              isVoicenote: voiceNote && totalFiles == 1,
              onSendProgress: onProgress != null
                  ? (sent, total) {
                      // Map file progress to overall progress
                      final fileProgress = sent / total;
                      final overallProgress = fileStartProgress + (fileProgress * (fileEndProgress - fileStartProgress));
                      onProgress(overallProgress);
                    }
                  : null,
            );
            final attachmentData = uploadResponse.data;
            final attachment = attachmentData is Map && attachmentData['data'] != null
                ? attachmentData['data'] as Map<String, dynamic>
                : attachmentData as Map<String, dynamic>;
            if (attachment['id'] == null) {
              throw Exception('Upload failed: No attachment ID returned');
            }
            attachmentIds.add(attachment['id'] as int);
            
            // Update progress to show this file is complete
            if (onProgress != null) {
              onProgress(fileEndProgress);
            }
          } catch (e) {
            throw Exception('Failed to upload attachment ${file.path}: $e');
          }
        }
        data['attachments'] = attachmentIds;
      }
      
      // Set progress to 100% when sending message (if no attachments, this is the only step)
      if (onProgress != null && (attachments == null || attachments.isEmpty)) {
        onProgress(1.0);
      }

      final response = await apiService.post('/groups/$groupId/messages', data: data);
      
      // Set progress to 100% after message is sent
      if (onProgress != null) {
        onProgress(1.0);
      }
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      final message = Message.fromJson(Map<String, dynamic>.from(map));
      unawaited(persistGroupMessages(groupId, [message]));
      return message;
    } catch (e) {
      throw Exception('Failed to send group message: $e');
    }
  }

  // PHASE 1: Delete message with optional "delete for everyone"
  Future<void> deleteMessage(
    int messageId, {
    bool deleteForEveryone = false,
    int? groupId,
  }) async {
    try {
      if (groupId != null) {
        await apiService.deleteGroupMessage(
          messageId,
          deleteForEveryone: deleteForEveryone,
        );
      } else {
        await apiService.deleteMessage(
          messageId,
          deleteForEveryone: deleteForEveryone,
        );
      }
      final local = localStorageService;
      if (local != null) {
        await local.applyMessageDeletion(
          messageId,
          deleteForEveryone: deleteForEveryone,
        );
      }
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  /// Pusher: another participant edited a message — align SQLite cache.
  Future<void> applyRemoteMessageEdit({
    required int messageId,
    required String body,
    DateTime? editedAt,
  }) async {
    final local = localStorageService;
    if (local != null) {
      await local.applyMessageEdit(
        messageId: messageId,
        body: body,
        editedAt: editedAt,
      );
    }
  }

  /// Pusher: another participant revoked the message — align SQLite cache.
  Future<void> applyRemoteDeleteForEveryone(int messageId) async {
    final local = localStorageService;
    if (local != null) {
      await local.applyMessageDeletion(
        messageId,
        deleteForEveryone: true,
      );
    }
  }

  Future<Message> editMessage(int messageId, String newBody) async {
    try {
      final response = await apiService.editMessage(messageId, newBody);
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map) ? raw['data'] : raw;
      return Message.fromJson(Map<String, dynamic>.from(map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final data = e.response?.data;
        final serverMsg = data is Map ? data['message']?.toString() : null;
        throw Exception(
          serverMsg ?? 'Could not edit message (text may be too long or invalid).',
        );
      }
      throw Exception('Failed to edit message: $e');
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }

  Future<Message> editGroupMessage(int messageId, String newBody) async {
    try {
      final response = await apiService.editGroupMessage(messageId, newBody);
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map) ? raw['data'] : raw;
      return Message.fromJson(Map<String, dynamic>.from(map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final data = e.response?.data;
        final serverMsg = data is Map ? data['message']?.toString() : null;
        throw Exception(
          serverMsg ?? 'Could not edit message (text may be too long or invalid).',
        );
      }
      throw Exception('Failed to edit group message: $e');
    } catch (e) {
      throw Exception('Failed to edit group message: $e');
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

  Future<void> forwardMessage(
    int messageId,
    List<Map<String, dynamic>> targets,
  ) async {
    try {
      await apiService.post(
        '/messages/$messageId/forward',
        data: {'targets': targets},
      );
    } catch (e) {
      throw Exception('Failed to forward message: $e');
    }
  }

  Future<void> removeReaction(int messageId) async {
    try {
      await apiService.delete('/messages/$messageId/react');
    } catch (e) {
      throw Exception('Failed to remove reaction: $e');
    }
  }

  // Get a single message by ID (for updating reactions without reloading all messages)
  Future<Message> getMessage(int messageId) async {
    try {
      final response = await apiService.get('/messages/$messageId');
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      return Message.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to load message: $e');
    }
  }

  // Get a single group message by ID (for updating reactions without reloading all messages)
  Future<Message> getGroupMessage(int messageId) async {
    try {
      final response = await apiService.get('/group-messages/$messageId');
      final raw = response.data;
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map
          : (raw as Map);
      return Message.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      throw Exception('Failed to load group message: $e');
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

  /// Mark all unread messages in a conversation as read (API). Call [markConversationAsReadLocally] first when offline so UI updates.
  Future<void> markConversationAsRead(int conversationId) async {
    try {
      await apiService.markConversationRead(conversationId);
    } catch (e) {
      throw Exception('Failed to mark conversation as read: $e');
    }
  }

  /// Mark a view-once message as opened on the server.
  Future<bool> markViewOnceOpened(int messageId) async {
    try {
      await apiService.post('/messages/$messageId/view-once', data: {});
      return true;
    } catch (e) {
      debugPrint('Failed to mark view-once as opened: $e');
      return false;
    }
  }

  /// Mark a conversation as read in local storage only (unread count → 0). Use when opening a chat so list and badge update even when offline.
  Future<void> markConversationAsReadLocally(int conversationId) async {
    if (localStorageService == null) return;
    try {
      await localStorageService!.markConversationAsReadLocally(conversationId);
    } catch (e) {
      debugPrint('markConversationAsReadLocally: $e');
    }
  }

  /// Mark a group as read in local storage only (unread count → 0). Use when opening a group chat so list and badge update even when offline.
  Future<void> markGroupAsReadLocally(int groupId) async {
    if (localStorageService == null) return;
    try {
      await localStorageService!.markGroupAsReadLocally(groupId);
    } catch (e) {
      debugPrint('markGroupAsReadLocally: $e');
    }
  }

  /// Mark all group messages read on server (sidebar sync).
  Future<void> markGroupAsRead(int groupId) async {
    try {
      await apiService.post('/groups/$groupId/read');
    } catch (e) {
      throw Exception('Failed to mark group as read: $e');
    }
  }

  Future<void> sendRecordingIndicator(int conversationId, bool isRecording) async {
    try {
      if (isRecording) {
        await apiService.post('/conversations/$conversationId/recording', data: {'is_recording': true});
      } else {
        await apiService.delete('/conversations/$conversationId/recording');
      }
    } catch (e) {
      throw Exception('Failed to send recording indicator: $e');
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

  Future<void> sendGroupTypingIndicator(int groupId, bool isTyping) async {
    try {
      await apiService.post(
        '/groups/$groupId/typing',
        data: {'is_typing': isTyping},
      );
    } catch (e) {
      throw Exception('Failed to send group typing indicator: $e');
    }
  }

  Future<void> sendGroupRecordingIndicator(int groupId, bool isRecording) async {
    try {
      if (isRecording) {
        await apiService.post('/groups/$groupId/recording');
      } else {
        await apiService.delete('/groups/$groupId/recording');
      }
    } catch (e) {
      throw Exception('Failed to send group recording indicator: $e');
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

  Future<void> markGroupUnread(int groupId) async {
    try {
      await apiService.markGroupUnread(groupId);
    } catch (e) {
      throw Exception('Failed to mark group as unread: $e');
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

  Future<void> pinMessageInConversation(
    int conversationId,
    int messageId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pinned_msg_conv_$conversationId', messageId);
    try {
      await apiService.post(
        '/conversations/$conversationId/pinned-message',
        data: {'message_id': messageId},
      );
    } catch (_) {}
  }

  Future<void> unpinMessageInConversation(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pinned_msg_conv_$conversationId');
    try {
      await apiService.delete('/conversations/$conversationId/pinned-message');
    } catch (_) {}
  }

  Future<void> pinMessageInGroup(int groupId, int messageId) async {
    await apiService.pinGroupMessage(groupId, messageId);
  }

  Future<void> unpinMessageInGroup(int groupId) async {
    await apiService.unpinGroupMessage(groupId);
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
        // For 401 (unauthenticated), return empty list instead of throwing
        if (statusCode == 401) {
          return [];
        }
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

  Future<Message?> sendPoll(
    int conversationId,
    Map<String, dynamic> pollData,
  ) async {
    final response = await apiService.post(
      '/conversations/$conversationId/polls',
      data: pollData,
    );
    final raw = response.data;
    final map = (raw is Map && raw['data'] != null)
        ? (raw['data'] is Map
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : null)
        : null;
    if (map == null) return null;
    return Message.fromJson(map);
  }

  Future<Message?> sendPollToGroup(
    int groupId,
    Map<String, dynamic> pollData, {
    String? clientId,
  }) async {
    final response = await apiService.post(
      '/groups/$groupId/polls',
      data: {
        ...pollData,
        if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
      },
    );
    final raw = response.data;
    final map = (raw is Map && raw['data'] != null)
        ? (raw['data'] is Map
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : null)
        : null;
    if (map == null) return null;
    return Message.fromJson(map);
  }
}
