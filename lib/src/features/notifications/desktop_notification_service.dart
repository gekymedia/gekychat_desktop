import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

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
    // Handle notification tap
    final data = response.payload != null
        ? {'data': response.payload}
        : <String, dynamic>{};
    onNotificationTap?.call(data);
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
    const androidDetails = AndroidNotificationDetails(
      'gekychat_channel',
      'GekyChat Notifications',
      channelDescription: 'Notifications for GekyChat messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
      payload: data != null ? data.toString() : null,
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

