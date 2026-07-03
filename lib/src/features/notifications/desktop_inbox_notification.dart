import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'notification_avatar_helper.dart';
import 'notification_manager.dart';
import 'notification_service.dart';

/// Gates OS notifications for desktop inbox events (Pusher user channel).
class DesktopInboxNotification {
  DesktopInboxNotification._();

  static NotificationService? _boundService;
  static bool _desktopEnabled = true;
  static bool _previewEnabled = true;
  static final Set<int> _recentMessageIds = <int>{};
  static const _maxDedupIds = 300;

  static bool get desktopEnabled => _desktopEnabled;
  static bool get previewEnabled => _previewEnabled;

  static void bindService(NotificationService service) {
    _boundService = service;
  }

  static void unbindService() {
    _boundService = null;
  }

  static Future<void> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _desktopEnabled = prefs.getBool('desktop_notifications_enabled') ?? true;
      _previewEnabled = prefs.getBool('notification_preview_enabled') ?? true;
    } catch (_) {}
  }

  static Future<void> loadFromApi(ApiService api) async {
    try {
      final response = await api.getNotificationSettings();
      final settings = response.data['data'];
      if (settings is! Map) return;
      _desktopEnabled = _toBool(settings['desktop_enabled']) ?? true;
      _previewEnabled = _toBool(settings['preview_enabled']) ?? true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('desktop_notifications_enabled', _desktopEnabled);
      await prefs.setBool('notification_preview_enabled', _previewEnabled);
    } catch (e) {
      debugPrint('DesktopInboxNotification: load settings failed: $e');
      await loadFromCache();
    }
  }

  static void applyLocalPrefs({bool? desktopEnabled, bool? previewEnabled}) {
    if (desktopEnabled != null) _desktopEnabled = desktopEnabled;
    if (previewEnabled != null) _previewEnabled = previewEnabled;
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return null;
  }

  static bool _dedup(int messageId) {
    if (_recentMessageIds.contains(messageId)) return true;
    _recentMessageIds.add(messageId);
    if (_recentMessageIds.length > _maxDedupIds) {
      _recentMessageIds.remove(_recentMessageIds.first);
    }
    return false;
  }

  /// Returns `false` when the message should not trigger an OS notification.
  static Future<bool> shouldNotify(
    dynamic ref, {
    required int messageId,
    required int? senderId,
    required int? currentUserId,
    int? conversationId,
    int? groupId,
  }) async {
    if (!_desktopEnabled) return false;
    if (senderId != null && currentUserId != null && senderId == currentUserId) {
      return false;
    }
    if (_dedup(messageId)) return false;

    try {
      final minimized = await windowManager.isMinimized();
      if (minimized) return true;
      final visible = await windowManager.isVisible();
      if (!visible) return true;
      final skipTaskbar = await windowManager.isSkipTaskbar();
      if (skipTaskbar) return true;

      final focused = await windowManager.isFocused();
      if (focused) {
        final openGroup = ref.read(selectedGroupIdProvider);
        if (groupId != null && openGroup == groupId) return false;
        final openConv = ref.read(selectedConversationProvider);
        if (conversationId != null && openConv == conversationId) return false;
      }
    } catch (_) {}

    return true;
  }

  static Future<void> showFromInbox(
    dynamic ref, {
    required Map<String, dynamic> messageMap,
    required int messageId,
    required int? senderId,
    required int? currentUserId,
    int? conversationId,
    int? groupId,
    required bool isGroupMessage,
  }) async {
    if (!await shouldNotify(
      ref,
      messageId: messageId,
      senderId: senderId,
      currentUserId: currentUserId,
      conversationId: conversationId,
      groupId: groupId,
    )) {
      return;
    }

    final sender = messageMap['sender'] is Map
        ? Map<String, dynamic>.from(messageMap['sender'] as Map)
        : null;
    final senderName =
        sender?['name']?.toString() ?? messageMap['sender_name']?.toString();
    final groupName = messageMap['group_name']?.toString();
    final avatarUrl = NotificationAvatarHelper.avatarFromMessageMap(messageMap);

    String title;
    String? subtitle;
    if (isGroupMessage) {
      if (senderName != null && senderName.isNotEmpty) {
        title = senderName;
        subtitle = (groupName != null && groupName.isNotEmpty) ? groupName : null;
      } else {
        title = (groupName != null && groupName.isNotEmpty) ? groupName : 'Group';
        subtitle = null;
      }
    } else {
      title = senderName ?? 'New message';
      subtitle = null;
    }

    String body;
    if (_previewEnabled) {
      body = messageMap['body']?.toString().trim() ?? '';
      if (body.isEmpty) {
        if (messageMap['has_attachments'] == true ||
            (messageMap['attachments'] is List &&
                (messageMap['attachments'] as List).isNotEmpty)) {
          body = '📎 Attachment';
        } else {
          body = isGroupMessage ? 'New group message' : 'New message';
        }
      }
      if (body.length > 120) body = '${body.substring(0, 117)}...';
    } else {
      body = isGroupMessage ? 'New group message' : 'New message';
    }

    final data = Map<String, dynamic>.from(messageMap);
    data.putIfAbsent('type', () => 'message');

    final service = _boundService ?? NotificationManager.instance?.service;
    if (service == null) {
      debugPrint('DesktopInboxNotification: no notification service bound');
      return;
    }

    await service.showLocalNotification(
      title: title,
      body: body,
      subtitle: subtitle,
      data: data,
      senderName: senderName ?? title,
      senderAvatarUrl: avatarUrl,
    );
  }
}
