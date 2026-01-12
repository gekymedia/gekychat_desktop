import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'desktop_notification_service.dart';
import '../../core/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chats/chat_repo.dart';

class NotificationManager {
  final NotificationService _service;
  final ApiService _api;
  final dynamic _ref; // Use dynamic to accept both Ref and WidgetRef
  static NotificationManager? _instance;

  NotificationManager._(this._service, this._api, [this._ref]);

  static Future<NotificationManager> create(ApiService api, [dynamic ref]) async {
    // Return existing instance if already created
    if (_instance != null) {
      debugPrint('⚠️ NotificationManager already exists, returning existing instance');
      return _instance!;
    }

    NotificationService service = DesktopNotificationService();
    try {
      await service.initialize();
      _instance = NotificationManager._(service, api, ref);
      return _instance!;
    } catch (e) {
      debugPrint('❌ Failed to create NotificationManager: $e');
      rethrow;
    }
  }

  static void reset() {
    _instance = null;
  }

  Future<void> setup() async {
    final granted = await _service.requestPermissions();
    if (!granted) {
      debugPrint('⚠️ Notification permissions not granted');
      return;
    }

    final token = await _service.getDeviceToken();
    if (token != null) {
      await _sendTokenToBackend(token);
    }

    _setupHandlers();
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _api.post('/user/fcm-token', data: {
        'fcm_token': token,
        'platform': 'desktop',
      });
      debugPrint('✅ Device token sent to backend');
    } catch (e) {
      debugPrint('❌ Failed to send device token: $e');
    }
  }

  void _setupHandlers() {
    _service.onForegroundNotification = (data) {
      debugPrint('📨 Foreground notification: $data');
    };

    _service.onNotificationTap = (data) async {
      debugPrint('📬 Notification tapped: $data');
      
      // Handle notification reply
      if (data['type'] == 'message_reply' && data['reply_text'] != null) {
        await _handleNotificationReply(data);
      }
    };
  }
  
  Future<void> _handleNotificationReply(Map<String, dynamic> data) async {
    final replyText = data['reply_text']?.toString();
    if (replyText == null || replyText.isEmpty) {
      debugPrint('⚠️ Cannot send reply: reply_text is missing or empty');
      return;
    }
    
    final conversationIdStr = data['conversation_id']?.toString();
    final conversationId = conversationIdStr != null ? int.tryParse(conversationIdStr) : null;
    
    if (conversationId == null) {
      debugPrint('⚠️ Cannot send reply: conversation_id is missing');
      return;
    }
    
    debugPrint('💬 Sending reply to conversation $conversationId: $replyText');
    
    try {
      // Access chat repository via provider if ref is available
      if (_ref != null) {
        final chatRepo = _ref!.read(chatRepositoryProvider);
        await chatRepo.sendMessageToConversation(
          conversationId: conversationId,
          body: replyText,
        );
        debugPrint('✅ Reply sent successfully');
      } else {
        // Fallback: send directly via API
        await _api.post('/conversations/$conversationId/messages', data: {
          'body': replyText,
        });
        debugPrint('✅ Reply sent successfully (via API)');
      }
    } catch (e) {
      debugPrint('❌ Error sending reply: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    await _service.showLocalNotification(
      title: title,
      body: body,
      data: data,
      imageUrl: imageUrl,
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


