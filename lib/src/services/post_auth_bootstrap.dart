import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../features/calls/incoming_call_handler.dart';
import '../features/calls/join_call_from_link.dart';
import '../features/notifications/desktop_inbox_notification.dart';
import '../features/notifications/notification_manager.dart';
import 'background_sync_worker.dart';
import 'bot_contact_registry.dart';
import 'inbox_realtime_sync.dart';

/// Runs after login so Pusher and incoming-call listeners wire up even when
/// the app cold-started on the login screen.
Future<void> bootstrapAfterAuth(Ref ref) async {
  try {
    await ref.read(pusherServiceProvider).resetReconnectPolicyAndConnect();
  } catch (e) {
    debugPrint('⚠️ Post-auth Pusher connect failed: $e');
  }

  try {
    await ref.read(inboxRealtimeSyncProvider).initialize();
  } catch (e) {
    debugPrint('⚠️ Post-auth InboxRealtimeSync init failed: $e');
  }

  try {
    await NotificationManager.tryRefreshAfterLogin();
    await DesktopInboxNotification.loadFromApi(ref.read(apiServiceProvider));
  } catch (e) {
    debugPrint('⚠️ Post-auth notification refresh failed: $e');
  }

  try {
    await hydrateDismissedDeadCallKeys(ref.container);
  } catch (e) {
    debugPrint('⚠️ Post-auth dismissed call keys hydrate failed: $e');
  }

  try {
    await ref.read(incomingCallHandlerProvider).initialize(ref);
  } catch (e) {
    debugPrint('⚠️ Post-auth IncomingCallHandler init failed: $e');
  }

  try {
    BackgroundSyncWorker.attach(ref.container);
    await BackgroundSyncWorker.triggerSync(force: true);
  } catch (e) {
    debugPrint('⚠️ Post-auth message sync failed: $e');
  }

  try {
    final registry = ref.read(botContactRegistryProvider);
    await registry.ensureLoaded();
    unawaited(registry.syncFromApi(ref.read(apiServiceProvider)));
  } catch (e) {
    debugPrint('⚠️ Post-auth bot registry sync failed: $e');
  }
}
