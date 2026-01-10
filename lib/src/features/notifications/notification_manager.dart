import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'desktop_notification_service.dart';
import '../../core/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationManager {
  final NotificationService _service;
  final ApiService _api;
  static NotificationManager? _instance;

  NotificationManager._(this._service, this._api);

  static Future<NotificationManager> create(ApiService api) async {
    // Return existing instance if already created
    if (_instance != null) {
      debugPrint('⚠️ NotificationManager already exists, returning existing instance');
      return _instance!;
    }

    NotificationService service = DesktopNotificationService();
    try {
      await service.initialize();
      _instance = NotificationManager._(service, api);
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

    _service.onNotificationTap = (data) {
      debugPrint('📬 Notification tapped: $data');
    };
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


