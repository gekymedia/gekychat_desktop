import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/desktop_window_service.dart';
import '../../app_router.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import '../../core/services/taskbar_badge_service.dart';
import '../calls/incoming_call_handler.dart';
import '../chats/chat_providers.dart';
import '../chats/sidebar_inbox_bump.dart';
import '../../realtime/pusher_message_payload.dart';
import '../realtime/pusher_service.dart';
import '../../utils/world_feed_link_navigation.dart';
import 'desktop_inbox_notification.dart';
import 'desktop_notification_service.dart';
import 'notification_service.dart';

class NotificationManager {
  final NotificationService _service;
  final ApiService _api;
  final dynamic _ref; // Ref or WidgetRef
  static NotificationManager? _instance;

  NotificationManager._(this._service, this._api, [this._ref]);

  static NotificationManager? get instance => _instance;

  static Future<NotificationManager> create(ApiService api, [dynamic ref]) async {
    if (_instance != null) {
      debugPrint(
          '⚠️ NotificationManager already exists, returning existing instance');
      return _instance!;
    }

    PusherService? sharedPusher;
    if (ref != null) {
      try {
        sharedPusher = (ref as dynamic).read(pusherServiceProvider) as PusherService;
      } catch (e) {
        debugPrint('⚠️ Could not read shared PusherService: $e');
      }
    }
    final service = DesktopNotificationService(sharedPusher ?? PusherService());
    try {
      await service.initialize();
      DesktopInboxNotification.bindService(service);
      _instance = NotificationManager._(service, api, ref);
      return _instance!;
    } catch (e) {
      debugPrint('❌ Failed to create NotificationManager: $e');
      rethrow;
    }
  }

  static void reset() {
    DesktopInboxNotification.unbindService();
    _instance = null;
  }

  /// After OTP login or session restore — wires Pusher user channel if it was skipped at cold start.
  static Future<void> tryRefreshAfterLogin() async {
    final m = _instance;
    if (m == null) return;
    await m.refreshRealtimeSubscriptions();
  }

  Future<void> refreshRealtimeSubscriptions() async {
    final s = _service;
    if (s is DesktopNotificationService) {
      await s.refreshAfterLogin();
    }
    _wireInboxNotifications();
  }

  /// Shared inbox → OS toast path (also used by [InboxRealtimeSync]).
  Future<void> notifyInboxPayload(Map<String, dynamic> payload) async {
    await _handleInboxMessageNotification(payload);
  }

  Future<void> setup() async {
    await DesktopInboxNotification.loadFromCache();
    unawaited(DesktopInboxNotification.loadFromApi(_api));

    final granted = await _service.requestPermissions();
    if (!granted) {
      debugPrint('⚠️ Notification permissions not granted');
    }

    // Desktop: no FCM token — realtime uses Pusher (WebSocket or sync polling).
    final token = await _service.getDeviceToken();
    if (token != null && token.isNotEmpty) {
      debugPrint(
          'ℹ️ Unexpected device token on desktop; push registration not used.');
    }

    _setupHandlers();
    _wireInboxNotifications();
  }

  void _wireInboxNotifications() {
    final s = _service;
    if (s is! DesktopNotificationService || _ref == null) return;
    s.onInboxMessage = (payload) {
      unawaited(_handleInboxMessageNotification(payload));
    };
  }

  Future<void> _handleInboxMessageNotification(
    Map<String, dynamic> payload,
  ) async {
    if (_ref == null) return;

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

    await DesktopInboxNotification.showFromInbox(
      _ref,
      messageMap: messageMap,
      messageId: messageId,
      senderId: senderId,
      currentUserId: userId,
      conversationId: conversationId,
      groupId: groupId,
      isGroupMessage: isGroupMessage,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _parsePayloadString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final j = jsonDecode(trimmed);
      if (j is Map) {
        return j.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    if (!trimmed.contains('=')) return null;
    final map = <String, dynamic>{};
    for (final part in trimmed.split('&')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        map[kv[0]] = kv[1];
      }
    }
    return map.isEmpty ? null : map;
  }

  void _setupHandlers() {
    _service.onForegroundNotification = (data) {
      debugPrint('📨 Foreground notification: $data');
    };

    _service.onNotificationTap = (data) async {
      debugPrint('📬 Notification tapped: $data');

      if (data['type'] == 'message_reply' && data['reply_text'] != null) {
        await _handleNotificationReply(data);
        return;
      }

      final rawPayload = data['data']?.toString();
      final parsed = rawPayload != null && rawPayload.isNotEmpty
          ? _parsePayloadString(rawPayload)
          : null;

      final type = data['type']?.toString() ??
          parsed?['type']?.toString() ??
          parsed?['action']?.toString();
      final raw = rawPayload ?? '';

      final isIncomingCall = type == 'incoming_call' ||
          type == 'call_invite' ||
          raw.contains('incoming_call') ||
          raw.contains('call_invite');

      try {
        await DesktopWindowService.showMainWindow();
      } catch (_) {}

      if (_ref == null) return;

      try {
        if (isIncomingCall) {
          final merged = <String, dynamic>{
            if (parsed != null) ...parsed,
            ...data.map((k, v) => MapEntry(k.toString(), v)),
          };
          final handler =
              (_ref as dynamic).read(incomingCallHandlerProvider)
                  as IncomingCallHandler;
          await handler.handleNotificationTap(merged);
          return;
        }

        final mergedPayload = <String, dynamic>{
          if (parsed != null) ...parsed,
          ...data.map((k, v) => MapEntry(k.toString(), v)),
        };
        final worldType = type ?? mergedPayload['type']?.toString();
        if (worldType == 'world_activity' || worldType == 'live_started') {
          final postId = int.tryParse(mergedPayload['post_id']?.toString() ?? '');
          final broadcastId =
              int.tryParse(mergedPayload['broadcast_id']?.toString() ?? '');
          final router = (_ref as dynamic).read(routerProvider);
          if (broadcastId != null && broadcastId > 0) {
            // Live join is handled elsewhere when user opens from world; route to live section.
            (_ref as dynamic).read(currentSectionProvider.notifier).setSection('/live-broadcast');
            router.go('/live-broadcast');
            return;
          }
          if (postId != null && postId > 0) {
            openWorldFeedInAppWithRouter(
              _ref as WidgetRef,
              router,
              postId: postId,
            );
            return;
          }
        }

        final groupIdStr = parsed?['group_id']?.toString();
        final messageIdStr =
            parsed?['message_id']?.toString() ?? parsed?['id']?.toString();
        final groupId = groupIdStr != null ? int.tryParse(groupIdStr) : null;
        final messageId = messageIdStr != null ? int.tryParse(messageIdStr) : null;

        if (groupId != null) {
          (_ref as dynamic).read(pendingDesktopGroupDeepLinkProvider.notifier).state =
              (groupId: groupId, messageId: messageId ?? 0);
          final router = (_ref as dynamic).read(routerProvider);
          router.go('/chats');
          (_ref as dynamic).read(currentSectionProvider.notifier).setSection('/chats');
          return;
        }

        final convIdStr = parsed?['conversation_id']?.toString() ??
            parsed?['cid']?.toString();
        final conversationId =
            convIdStr != null ? int.tryParse(convIdStr) : null;
        if (conversationId != null) {
          (_ref as dynamic)
              .read(selectedConversationProvider.notifier)
              .selectConversation(conversationId);
          final router = (_ref as dynamic).read(routerProvider);
          router.go('/chats');
          (_ref as dynamic).read(currentSectionProvider.notifier).setSection('/chats');
        }
      } catch (e) {
        debugPrint('⚠️ Notification tap navigation: $e');
      }
    };
  }

  Future<void> _handleNotificationReply(Map<String, dynamic> data) async {
    final replyText = data['reply_text']?.toString().trim();
    if (replyText == null || replyText.isEmpty) {
      debugPrint('⚠️ Cannot send reply: reply_text is missing or empty');
      return;
    }

    var conversationId = _parseId(data['conversation_id']);
    var groupId = _parseId(data['group_id']);

    if (conversationId == null && groupId == null) {
      final rawPayload = data['payload']?.toString() ??
          data['data']?.toString();
      if (rawPayload != null && rawPayload.isNotEmpty) {
        final parsed = _parsePayloadString(rawPayload);
        conversationId ??= _parseId(parsed?['conversation_id']);
        groupId ??= _parseId(parsed?['group_id']);
      }
    }

    if (conversationId == null && groupId == null) {
      debugPrint('⚠️ Cannot send reply: conversation_id/group_id missing');
      return;
    }

    try {
      if (_ref != null) {
        final chatRepo = (_ref as dynamic).read(chatRepositoryProvider);
        if (groupId != null) {
          debugPrint('💬 Sending reply to group $groupId: $replyText');
          await chatRepo.sendMessageToGroup(groupId: groupId, body: replyText);
          await clearGroupUnreadInSidebar(_ref as WidgetRef, groupId);
          try {
            await chatRepo.markGroupAsRead(groupId);
          } catch (e) {
            debugPrint('Mark group read after notification reply: $e');
          }
        } else {
          debugPrint(
              '💬 Sending reply to conversation $conversationId: $replyText');
          await chatRepo.sendMessageToConversation(
            conversationId: conversationId!,
            body: replyText,
          );
          await clearConversationUnreadInSidebar(
            _ref as WidgetRef,
            conversationId,
          );
          try {
            await chatRepo.markConversationAsRead(conversationId);
          } catch (e) {
            debugPrint('Mark conversation read after notification reply: $e');
          }
        }
        (_ref as dynamic).read(inboxListRefreshTickProvider.notifier).state++;
        unawaited(
          (_ref as dynamic)
              .read(taskbarBadgeServiceProvider)
              .updateBadge(),
        );
        debugPrint('✅ Reply sent successfully');
      } else if (groupId != null) {
        await _api.post('/groups/$groupId/messages', data: {'body': replyText});
      } else {
        await _api.post('/conversations/$conversationId/messages', data: {
          'body': replyText,
        });
      }
    } catch (e) {
      debugPrint('❌ Error sending reply: $e');
    }
  }

  int? _parseId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? senderName,
    String? senderAvatarUrl,
  }) async {
    if (!DesktopInboxNotification.desktopEnabled) return;
    await _service.showLocalNotification(
      title: title,
      body: body,
      data: data,
      imageUrl: imageUrl,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
    );
  }

  Future<void> clearAll() async {
    await _service.clearAllNotifications();
  }

  NotificationService get service => _service;

  void dispose() {
    _service.dispose();
  }
}

final notificationManagerProvider = Provider<NotificationManager?>((ref) {
  return null;
});
