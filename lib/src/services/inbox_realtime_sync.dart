import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';
import '../features/chats/sidebar_inbox_bump.dart';
import '../features/chats/models.dart';
import '../features/chats/chat_providers.dart';
import '../realtime/pusher_message_payload.dart';
import '../core/services/taskbar_badge_service.dart';
import '../features/notifications/notification_manager.dart';

/// App-wide inbox listener: refreshes the chats list and pushes live messages
/// into open [ChatView] / [GroupChatView] via [inboxLiveMessageProvider].
class InboxRealtimeSync {
  InboxRealtimeSync(this._ref);

  static DateTime? lastInboxEventAt;

  final Ref _ref;
  bool _ready = false;
  int? _listeningUserId;

  Future<void> initialize({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var userId = prefs.getInt('user_id') ??
          int.tryParse(prefs.getString('user_id') ?? '');
      if (userId == null) {
        debugPrint('📭 InboxRealtimeSync: no user — skipping');
        return;
      }
      if (!force && _ready && _listeningUserId == userId) return;
      _ready = true;
      _listeningUserId = userId;

      final pusher = _ref.read(pusherServiceProvider);
      final channel = 'user.$userId';

      await pusher.connect();
      await pusher.subscribePrivate(channel, (_) {});
      pusher.listen(channel, 'UserInboxMessage', _handleInboxEvent);
      pusher.listen(channel, 'UserInboxGroupMessage', _handleInboxEvent);

      debugPrint('✅ InboxRealtimeSync listening on private-user.$userId');
    } catch (e) {
      _ready = false;
      debugPrint('❌ InboxRealtimeSync init failed: $e');
    }
  }

  Future<void> _handleInboxEvent(dynamic data) async {
    lastInboxEventAt = DateTime.now();
    try {
      final payload = _parsePayload(data);
      if (payload == null) return;

      final message = payload['message'] ?? payload['data'] ?? payload;
      if (message is! Map) return;
      final messageMap = payload['message'] is Map
          ? mergeLaravelMessageBroadcastPayload(
              Map<String, dynamic>.from(payload),
            )
          : Map<String, dynamic>.from(message);

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) return;

      final senderId = _asInt(
        (messageMap['sender'] is Map
                ? (messageMap['sender'] as Map)['id']
                : null) ??
            messageMap['sender_id'] ??
            messageMap['senderId'],
      );

      final messageId = _asInt(messageMap['id'] ?? messageMap['message_id']);
      if (messageId == null) return;

      final conversationId = _asInt(
        messageMap['conversation_id'] ?? messageMap['conversationId'],
      );
      final groupId = _asInt(messageMap['group_id'] ?? messageMap['groupId']);
      final isGroupMessage =
          groupId != null || messageMap['is_group'] == true;

      final openGroupId = _ref.read(selectedGroupIdProvider);
      final openConversationId = _ref.read(selectedConversationProvider);
      final viewingOpenChat = senderId != userId &&
          ((isGroupMessage && groupId != null && openGroupId == groupId) ||
              (!isGroupMessage &&
                  conversationId != null &&
                  openConversationId == conversationId));

      Message parsedMessage;
      try {
        parsedMessage = Message.fromJson(messageMap);
      } catch (e) {
        debugPrint('InboxRealtimeSync: Message.fromJson failed: $e');
        return;
      }

      // Push into open chat views immediately (UserInbox* is the reliable inbox path).
      _ref.read(inboxLiveMessageProvider.notifier).state = InboxLiveMessage(
        conversationId: isGroupMessage ? null : conversationId,
        groupId: isGroupMessage ? groupId : null,
        message: parsedMessage,
        nonce: DateTime.now().microsecondsSinceEpoch,
      );

      // Persist for offline / cache (best-effort).
      try {
        final storage = _ref.read(localStorageServiceProvider);
        if (isGroupMessage && groupId != null) {
          await storage.upsertMessage(parsedMessage);
          final body = _previewBody(messageMap);
          await storage.bumpGroupFromInbox(
            groupId: groupId,
            lastMessage: body,
            fromMe: senderId == userId,
            updatedAt: parsedMessage.createdAt,
            incrementUnread: senderId != userId && !viewingOpenChat,
          );
          patchGroupSidebarFromInbox(
            _ref,
            groupId: groupId,
            preview: body,
            updatedAt: parsedMessage.createdAt,
            fromMe: senderId == userId,
          );
          if (viewingOpenChat) {
            _ref.read(groupUnreadOverridesProvider.notifier).update((overrides) {
              final next = Map<int, int>.from(overrides);
              next[groupId] = 0;
              return next;
            });
          }
        } else if (conversationId != null) {
          await storage.upsertMessage(parsedMessage);
          final body = _previewBody(messageMap);
          await storage.bumpConversationFromInbox(
            conversationId: conversationId,
            lastMessage: body,
            fromMe: senderId == userId,
            updatedAt: parsedMessage.createdAt,
            incrementUnread: senderId != userId && !viewingOpenChat,
          );
          patchConversationSidebarFromInbox(
            _ref,
            conversationId: conversationId,
            preview: body,
            updatedAt: parsedMessage.createdAt,
            fromMe: senderId == userId,
          );
          if (viewingOpenChat) {
            _ref.read(conversationUnreadOverridesProvider.notifier).update(
              (overrides) {
                final next = Map<int, int>.from(overrides);
                next[conversationId] = 0;
                return next;
              },
            );
          }
        }
      } catch (e) {
        debugPrint('InboxRealtimeSync: local cache update: $e');
      }

      // Refresh sidebar lists (keeps previous data while refetching).
      _ref.read(inboxListRefreshTickProvider.notifier).state++;
      unawaited(_ref.read(taskbarBadgeServiceProvider).updateBadge());

      unawaited(
        NotificationManager.instance?.notifyInboxPayload(payload),
      );
    } catch (e) {
      debugPrint('InboxRealtimeSync event: $e');
    }
  }

  static Map<String, dynamic>? _parsePayload(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static String _previewBody(Map<String, dynamic> messageMap) {
    final raw = messageMap['body'] ?? messageMap['message'] ?? '';
    final text = raw.toString().trim();
    if (text.isNotEmpty) {
      return text.length > 120 ? '${text.substring(0, 117)}...' : text;
    }
    final attachments = messageMap['attachments'];
    if (messageMap['has_attachments'] == true ||
        (attachments is List && attachments.isNotEmpty)) {
      return '📎 Attachment';
    }
    return 'New message';
  }

  void dispose() {
    _ready = false;
    _listeningUserId = null;
  }
}

class InboxLiveMessage {
  const InboxLiveMessage({
    required this.conversationId,
    required this.groupId,
    required this.message,
    required this.nonce,
  });

  final int? conversationId;
  final int? groupId;
  final Message message;
  final int nonce;
}

final inboxRealtimeSyncProvider = Provider<InboxRealtimeSync>((ref) {
  final sync = InboxRealtimeSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});

final inboxLiveMessageProvider =
    StateProvider<InboxLiveMessage?>((ref) => null);
