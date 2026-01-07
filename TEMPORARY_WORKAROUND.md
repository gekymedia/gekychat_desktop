# Temporary Workaround (Build Without Notifications)

If you can't install ATL components right now, you can temporarily disable notifications to get the app building.

## ⚠️ Warning

This will disable desktop notifications. The app will still work, but you won't get notifications for new messages.

## Steps

1. **Comment out notification dependencies** in `pubspec.yaml`:
   ```yaml
   # Desktop notifications
   # flutter_local_notifications: ^19.4.0
   ```

2. **Comment out notification initialization** in `lib/main.dart`:
   ```dart
   // Future.microtask(() async {
   //   try {
   //     final apiService = ref.read(apiServiceProvider);
   //     final notificationManager = await NotificationManager.create(apiService);
   //     await notificationManager.setup();
   //     debugPrint('✅ Notifications initialized');
   //   } catch (e) {
   //     debugPrint('⚠️ Failed to initialize notifications: $e');
   //   }
   // });
   ```

3. **Comment out notification imports** if they cause errors:
   ```dart
   // import 'src/features/notifications/notification_manager.dart';
   ```

4. **Update `lib/src/features/notifications/desktop_notification_service.dart`** to be a stub:
   ```dart
   import 'notification_service.dart';

   class DesktopNotificationService extends NotificationService {
     @override
     Future<void> initialize() async {
       // Stub - notifications disabled
     }

     @override
     Future<bool> requestPermissions() async => true;

     @override
     Future<String?> getDeviceToken() async => null;

     @override
     Future<void> showLocalNotification({
       required String title,
       required String body,
       Map<String, dynamic>? data,
       String? imageUrl,
     }) async {
       // Stub - no-op
     }

     @override
     Future<void> clearAllNotifications() async {
       // Stub - no-op
     }

     @override
     void dispose() {}
   }
   ```

5. **Run:**
   ```powershell
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

## Re-enabling Notifications Later

1. Install ATL components (see `WINDOWS_BUILD_SETUP.md`)
2. Uncomment all the changes above
3. Run `flutter pub get` and rebuild

