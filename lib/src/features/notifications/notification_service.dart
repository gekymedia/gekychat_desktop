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
  });
  Future<void> clearAllNotifications();
  void dispose();
}

class NotificationPlatform {
  static bool get isMobile => false; // Desktop only
  static bool get isDesktop => true;
  static bool get isAndroid => false;
  static bool get isIOS => false;
}


