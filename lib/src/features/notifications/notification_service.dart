abstract class NotificationService {
  Function(Map<String, dynamic>)? onForegroundNotification;
  Function(Map<String, dynamic>)? onNotificationTap;

  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<String?> getDeviceToken();
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? senderName,
    String? senderAvatarUrl,
    String? subtitle,
  });
  Future<void> clearAllNotifications();

  /// Tray notification for a message (parity with mobile); default uses [showLocalNotification].
  Future<void> showMessageReceivedNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await showLocalNotification(title: title, body: body, data: data);
  }

  void dispose();
}

class NotificationPlatform {
  static bool get isMobile => false; // Desktop only
  static bool get isDesktop => true;
  static bool get isAndroid => false;
  static bool get isIOS => false;
}


