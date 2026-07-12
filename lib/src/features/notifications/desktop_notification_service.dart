import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../realtime/pusher_service.dart';
import 'desktop_notification_constants.dart';
import 'notification_avatar_helper.dart';
import 'notification_large_icon.dart';
import 'notification_service.dart';

/// Desktop notifications via the shared [PusherService] (same WebSocket as chat/calls)
/// plus OS local notifications.
class DesktopNotificationService extends NotificationService {
  DesktopNotificationService(this._pusher);

  final PusherService _pusher;

  /// Windows inline-reply actions omit toast launch payload — only action arguments.
  final Map<int, String> _notificationPayloadById = {};
  final Map<String, String> _payloadByThreadKey = {};
  String? _lastMessagePayload;
  static const int _maxCachedPayloads = 64;

  Function(Map<String, dynamic> payload)? onInboxMessage;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  int? _userId;
  bool _userChannelWired = false;

  @override
  Future<void> initialize() async {
    debugPrint('🖥️ Initializing Desktop Notification Service...');
    await _initializeLocalNotifications();
    await _wireUserChannelIfReady();
    debugPrint('✅ Desktop Notification Service initialized');
  }

  /// Call after login or when [initialize] ran before `user_id` / token was available.
  Future<void> refreshAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final accountId = prefs.getInt('current_account_id');
    String? token = accountId != null
        ? prefs.getString('auth_token_$accountId')
        : null;
    token ??= prefs.getString('auth_token');
    final newId = prefs.getInt('user_id');
    if (token == null || token.isEmpty || newId == null) return;
    if (newId == _userId && _userChannelWired) {
      return;
    }
    _userId = newId;
    _userChannelWired = false;
    await _wireUserChannelIfReady();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(
        notificationCategories: [kDesktopMessageCategory],
      ),
      macOS: DarwinInitializationSettings(
        notificationCategories: [kDesktopMessageCategory],
      ),
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
      windows: WindowsInitializationSettings(
        appUserModelId: 'gekychat.desktop',
        appName: 'GekyChat',
        guid: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _wireUserChannelIfReady() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getInt('current_account_id');
      String? token = accountId != null
          ? prefs.getString('auth_token_$accountId')
          : null;
      token ??= prefs.getString('auth_token');
      _userId = prefs.getInt('user_id');

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ No auth token, skipping Pusher inbox for notifications');
        return;
      }
      if (_userId == null) {
        debugPrint('⚠️ No user_id, skipping Pusher inbox for notifications');
        return;
      }

      await _wireUserChannel();
      if (!_pusher.isConnected) {
        unawaited(_pusher.connect().catchError((e) {
          debugPrint('⚠️ Shared Pusher connect from notifications: $e');
        }));
      }
      debugPrint('✅ Pusher inbox wired for desktop notifications (user $_userId)');
    } catch (e) {
      debugPrint('❌ Pusher inbox wire for notifications: $e');
      _userChannelWired = false;
    }
  }

  Future<void> _wireUserChannel() async {
    if (_userId == null || _userChannelWired) return;
    final uid = _userId!;
    final channel = 'user.$uid';

    await _pusher.subscribePrivate(channel, (_) {});

    _pusher.listen(channel, 'CallInvite', _onCallInvite);
    _pusher.listen(channel, 'UserInboxMessage', _onUserInboxMessage);
    _pusher.listen(channel, 'UserInboxGroupMessage', _onUserInboxMessage);

    _userChannelWired = true;
  }

  void _onUserInboxMessage(dynamic data) {
    try {
      final payload = _parseInboxPayload(data);
      if (payload == null) return;
      onInboxMessage?.call(payload);
    } catch (e) {
      debugPrint('DesktopNotificationService inbox event: $e');
    }
  }

  static Map<String, dynamic>? _parseInboxPayload(dynamic data) {
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

  void _onCallInvite(dynamic data) {
    if (data is! Map) return;
    final caller = data['caller'] is Map ? data['caller'] as Map : null;
    final name = caller?['name']?.toString() ?? 'Someone';
    final callType = data['type']?.toString() == 'video' ? 'video call' : 'call';
    onForegroundNotification?.call(Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v))));
    final sessionId = data['session_id'] ?? data['call_id'];
    showLocalNotification(
      title: 'Incoming $callType',
      body: '$name is calling you',
      data: <String, dynamic>{
        'type': 'incoming_call',
        'action': 'incoming_call',
        'session_id': sessionId,
        'call_type': data['type']?.toString() ?? 'voice',
        if (caller?['id'] != null) 'caller_id': caller!['id'],
        'caller_name': name,
        if (caller?['avatar'] != null) 'caller_avatar': caller!['avatar'],
        if (data['conversation_id'] != null)
          'conversation_id': data['conversation_id'],
        if (data['group_id'] != null) 'group_id': data['group_id'],
      },
      senderName: name,
      senderAvatarUrl: NotificationAvatarHelper.resolveAvatarUrl(
        caller?['avatar']?.toString() ?? caller?['avatar_url']?.toString(),
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
        '📬 Desktop notification response: ${response.id}, ${response.actionId}, ${response.input}, data=${response.data}');

    final replyText = _extractReplyText(response);
    final actionId = response.actionId ?? '';
    final isReplyAction = isWindowsReplyActionId(actionId) ||
        actionId == 'send-reply' ||
        actionId == 'Send' ||
        (replyText != null &&
            replyText.isNotEmpty &&
            response.notificationResponseType ==
                NotificationResponseType.selectedNotificationAction);

    if (isReplyAction &&
        replyText != null &&
        replyText.trim().isNotEmpty) {
      final payload = _resolveReplyPayload(response);
      _handleNotificationReply(payload, replyText.trim());
      return;
    }

    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      onNotificationTap?.call({'data': payload});
    } else {
      onNotificationTap?.call(<String, dynamic>{});
    }
  }

  String? _extractReplyText(NotificationResponse response) {
    final direct = response.input?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final data = response.data;
    if (data.isEmpty) return null;

    for (final key in [kDesktopReplyInputId, 'reply', 'text']) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    if (data.length == 1) {
      final only = data.values.first?.toString().trim();
      if (only != null && only.isNotEmpty) return only;
    }
    return null;
  }

  void _rememberMessagePayload(
    String payloadString, {
    int? conversationId,
    int? groupId,
  }) {
    if (payloadString.isEmpty) return;
    _lastMessagePayload = payloadString;
    if (groupId != null && groupId > 0) {
      _payloadByThreadKey['g:$groupId'] = payloadString;
    }
    if (conversationId != null && conversationId > 0) {
      _payloadByThreadKey['c:$conversationId'] = payloadString;
    }
    while (_payloadByThreadKey.length > _maxCachedPayloads) {
      _payloadByThreadKey.remove(_payloadByThreadKey.keys.first);
    }
  }

  String _resolveReplyPayload(NotificationResponse response) {
    final routing = parseWindowsReplyRouting(response.actionId) ??
        parseWindowsReplyRouting(response.payload);
    if (routing != null) {
      try {
        return jsonEncode(routing);
      } catch (_) {}
    }

    var payload = response.payload?.trim() ?? '';
    if (payload.isNotEmpty && payload != kDesktopReplyActionId) {
      return payload;
    }

    if (response.id != null) {
      final cached = _notificationPayloadById[response.id];
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final threadFromAction = parseWindowsReplyRouting(response.actionId);
    if (threadFromAction != null) {
      final groupId = threadFromAction['group_id']?.toString();
      final conversationId = threadFromAction['conversation_id']?.toString();
      if (groupId != null) {
        final cached = _payloadByThreadKey['g:$groupId'];
        if (cached != null && cached.isNotEmpty) return cached;
      }
      if (conversationId != null) {
        final cached = _payloadByThreadKey['c:$conversationId'];
        if (cached != null && cached.isNotEmpty) return cached;
      }
    }

    final last = _lastMessagePayload;
    if (last != null && last.isNotEmpty) return last;

    return payload;
  }

  Map<String, dynamic>? _parsePayloadString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    if (!trimmed.contains('=')) return null;
    final map = <String, dynamic>{};
    for (final part in trimmed.split('&')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        map[kv[0]] = Uri.decodeComponent(kv[1]);
      }
    }
    return map.isEmpty ? null : map;
  }

  void _handleNotificationReply(String payload, String replyText) {
    try {
      final parsed = _parsePayloadString(payload);
      final data = <String, dynamic>{
        if (parsed != null) ...parsed,
        'reply_text': replyText,
        'type': 'message_reply',
      };
      if (parsed == null && payload.isNotEmpty) {
        data['payload'] = payload;
      }
      onNotificationTap?.call(data);
    } catch (e) {
      debugPrint('❌ Error handling notification reply: $e');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    return true;
  }

  @override
  Future<String?> getDeviceToken() async {
    return null;
  }

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? senderName,
    String? senderAvatarUrl,
    String? subtitle,
  }) async {
    final conversationIdRaw = data?['conversation_id'] ?? data?['conversationId'];
    final groupIdRaw = data?['group_id'] ?? data?['groupId'];
    final conversationId = conversationIdRaw?.toString() ?? '';
    final groupId = groupIdRaw?.toString() ?? '';
    final conversationIdInt = int.tryParse(conversationId);
    final groupIdInt = int.tryParse(groupId);
    final messageId = data?['message_id']?.toString() ?? data?['id']?.toString() ?? '';
    final isCall = data?['type'] == 'incoming_call' ||
        data?['action'] == 'incoming_call';
    final isMessage =
        !isCall && (conversationId.isNotEmpty || groupId.isNotEmpty);
    final windowsReplyArgs = isMessage
        ? buildWindowsReplyArguments(
            conversationId: conversationIdInt,
            groupId: groupIdInt,
          )
        : kDesktopReplyActionId;

    String payloadString;
    if (isMessage) {
      final payloadMap = <String, dynamic>{
        'type': 'message',
        if (conversationId.isNotEmpty) 'conversation_id': conversationId,
        if (groupId.isNotEmpty) 'group_id': groupId,
        if (messageId.isNotEmpty) 'message_id': messageId,
      };
      if (data != null) {
        for (final entry in data.entries) {
          payloadMap.putIfAbsent(entry.key, () => entry.value);
        }
      }
      try {
        payloadString = jsonEncode(payloadMap);
      } catch (_) {
        payloadString = payloadMap.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&');
      }
    } else if (groupId.isNotEmpty && messageId.isNotEmpty) {
      payloadString = 'group_id=$groupId&message_id=$messageId';
    } else if (conversationId.isNotEmpty && messageId.isNotEmpty) {
      payloadString = 'conversation_id=$conversationId&message_id=$messageId';
    } else if (data != null && data.isNotEmpty) {
      try {
        payloadString = jsonEncode(data);
      } catch (_) {
        payloadString = data.toString();
      }
    } else {
      payloadString = '';
    }

    final darwinDetails = isMessage
        ? buildMessageDarwinDetails(
            subtitle: subtitle,
            attachments: null,
          )
        : const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );
    const linuxDetails = LinuxNotificationDetails(defaultActionName: 'Open');

    final resolvedAvatarUrl = NotificationAvatarHelper.resolveAvatarUrl(
          senderAvatarUrl ?? imageUrl,
        ) ??
        senderAvatarUrl ??
        imageUrl;
    final avatarLabel = senderName ?? title;

    String? largeIconPath;
    try {
      largeIconPath = await NotificationLargeIconComposer.compose(
        avatarUrl: resolvedAvatarUrl,
        displayName: avatarLabel,
      );
    } catch (e) {
      debugPrint('NotificationLargeIconComposer: $e');
    }

    final windowsImages = <WindowsImage>[];
    if (largeIconPath != null && largeIconPath.isNotEmpty) {
      windowsImages.add(
        WindowsImage(
          Uri.file(largeIconPath),
          altText: avatarLabel,
          placement: WindowsImagePlacement.appLogoOverride,
        ),
      );
    }

    final windowsDetails = isMessage
        ? buildMessageWindowsDetails(
            images: windowsImages,
            subtitle: subtitle,
            replyArguments: windowsReplyArgs,
          )
        : const WindowsNotificationDetails();

    final darwinMessageDetails = isMessage
        ? buildMessageDarwinDetails(
            subtitle: subtitle,
            attachments: largeIconPath != null
                ? [DarwinNotificationAttachment(largeIconPath)]
                : null,
          )
        : darwinDetails;

    final androidDetails = largeIconPath != null
        ? AndroidNotificationDetails(
            'gekychat_channel',
            'GekyChat Notifications',
            channelDescription: 'Notifications for GekyChat messages and calls',
            importance: Importance.high,
            priority: Priority.high,
            largeIcon: FilePathAndroidBitmap(largeIconPath),
            actions: isMessage ? [kDesktopAndroidReplyAction] : null,
          )
        : AndroidNotificationDetails(
            'gekychat_channel',
            'GekyChat Notifications',
            channelDescription: 'Notifications for GekyChat messages and calls',
            importance: Importance.high,
            priority: Priority.high,
            actions: isMessage ? [kDesktopAndroidReplyAction] : null,
          );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinMessageDetails,
      macOS: darwinMessageDetails,
      linux: linuxDetails,
      windows: windowsDetails,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
      if (payloadString.isNotEmpty) {
        _notificationPayloadById[notificationId] = payloadString;
        if (isMessage) {
          _rememberMessagePayload(
            payloadString,
            conversationId: conversationIdInt,
            groupId: groupIdInt,
          );
        }
        while (_notificationPayloadById.length > _maxCachedPayloads) {
          _notificationPayloadById.remove(_notificationPayloadById.keys.first);
        }
      }
      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payloadString.isEmpty ? null : payloadString,
      );
    } catch (e) {
      debugPrint('❌ showLocalNotification (with reply + avatar): $e');
      if (!isMessage) return;
      try {
        final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
        if (payloadString.isNotEmpty) {
          _notificationPayloadById[notificationId] = payloadString;
          if (isMessage) {
            _rememberMessagePayload(
              payloadString,
              conversationId: conversationIdInt,
              groupId: groupIdInt,
            );
          }
        }
        await _localNotifications.show(
          notificationId,
          title,
          body,
          NotificationDetails(
            android: androidDetails,
            iOS: buildMessageDarwinDetails(subtitle: subtitle),
            macOS: buildMessageDarwinDetails(subtitle: subtitle),
            linux: linuxDetails,
            windows: buildMessageWindowsDetails(
              subtitle: subtitle,
              replyArguments: windowsReplyArgs,
            ),
          ),
          payload: payloadString.isEmpty ? null : payloadString,
        );
      } catch (fallbackError) {
        debugPrint('❌ showLocalNotification reply fallback: $fallbackError');
        try {
          await _localNotifications.show(
            DateTime.now().millisecondsSinceEpoch % 100000,
            title,
            body,
            NotificationDetails(
              android: androidDetails,
              iOS: darwinMessageDetails,
              macOS: darwinMessageDetails,
              linux: linuxDetails,
              windows: const WindowsNotificationDetails(),
            ),
            payload: payloadString.isEmpty ? null : payloadString,
          );
        } catch (plainError) {
          debugPrint('❌ showLocalNotification plain fallback: $plainError');
        }
      }
    }
  }

  @override
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  @override
  void dispose() {
    _userChannelWired = false;
    _userId = null;
  }
}
