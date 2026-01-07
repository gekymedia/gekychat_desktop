import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';

class DesktopNotificationService extends NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
      linux: const LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
      windows: const WindowsInitializationSettings(
        appUserModelId: 'gekychat.desktop',
        appName: 'GekyChat',
        guid: 'gekychat-desktop-app',
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📬 Desktop notification response: ${response.id}, ${response.actionId}, ${response.input}');
    
    // Handle inline reply
    if (response.actionId == 'reply' && response.input != null && response.input!.isNotEmpty) {
      _handleNotificationReply(response.payload ?? '', response.input!);
      return;
    }
    
    // Handle notification tap
    final data = response.payload != null
        ? {'data': response.payload}
        : <String, dynamic>{};
    onNotificationTap?.call(data);
  }
  
  void _handleNotificationReply(String payload, String replyText) {
    debugPrint('💬 Desktop notification reply received: $replyText');
    try {
      // Parse payload to get conversation_id and message_id
      final data = <String, dynamic>{'payload': payload};
      
      // Try to extract conversation_id from payload if it's in format like "conversation_id=123&message_id=456"
      if (payload.contains('conversation_id')) {
        final parts = payload.split('&');
        for (final part in parts) {
          final kv = part.split('=');
          if (kv.length == 2) {
            data[kv[0]] = kv[1];
          }
        }
      }
      
      // Add reply text
      data['reply_text'] = replyText;
      data['type'] = 'message_reply';
      
      // Call callback to handle the reply
      onNotificationTap?.call(data);
    } catch (e) {
      debugPrint('❌ Error handling notification reply: $e');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    // Desktop platforms typically don't require permission requests
    return true;
  }

  @override
  Future<String?> getDeviceToken() async {
    // Desktop doesn't use FCM tokens
    return null;
  }

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    // Extract conversation and message IDs for reply
    final conversationId = data?['conversation_id']?.toString() ?? '';
    final messageId = data?['message_id']?.toString() ?? '';
    
    // Create payload string with conversation and message IDs
    final payloadString = conversationId.isNotEmpty && messageId.isNotEmpty
        ? 'conversation_id=$conversationId&message_id=$messageId'
        : (data?.toString() ?? '');
    
    // Windows notification details
    const windowsDetails = WindowsNotificationDetails();
    
    // macOS supports inline replies via categoryIdentifier
    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: 'MESSAGE_CATEGORY',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Linux notification details
    const linuxDetails = LinuxNotificationDetails(
      defaultActionName: 'Open',
    );

    const androidDetails = AndroidNotificationDetails(
      'gekychat_channel',
      'GekyChat Notifications',
      channelDescription: 'Notifications for GekyChat messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
      windows: windowsDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
      payload: payloadString,
    );
  }

  @override
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  @override
  void dispose() {
    // Desktop notifications don't need disposal
  }
}

