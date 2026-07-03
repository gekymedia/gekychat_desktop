import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/message_queue_service.dart';
import 'message_sync_service.dart';

/// Triggers incremental message pull + outgoing queue flush.
///
/// Mirrors mobile [BackgroundSyncWorker]: runs on startup, window focus,
/// and when connectivity is restored (Pusher alone can miss messages while
/// the app was closed or offline).
class BackgroundSyncWorker {
  static ProviderContainer? _container;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  static DateTime? _lastSyncTime;
  static bool _initialized = false;

  static void attach(ProviderContainer container) {
    _container = container;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    debugPrint('✅ Desktop background sync worker initialized');

    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.isEmpty ||
          results.any((r) => r != ConnectivityResult.none);
      if (!online) return;
      debugPrint('🌐 Desktop network restored — triggering sync');
      unawaited(triggerSync());
    });

    unawaited(triggerSync());
  }

  static Future<void> triggerSync({bool force = false}) async {
    final container = _container;
    if (container == null) {
      debugPrint('⏭️ Desktop sync skipped (worker not attached)');
      return;
    }

    if (!force && _lastSyncTime != null) {
      final elapsed = DateTime.now().difference(_lastSyncTime!);
      if (elapsed.inSeconds < 60) {
        debugPrint(
          '⏭️ Desktop sync throttled (last ${elapsed.inSeconds}s ago)',
        );
        return;
      }
    }

    try {
      // Outgoing queue first (same order as mobile syncAccount).
      try {
        await container.read(messageQueueServiceProvider).syncPendingMessages();
      } catch (e) {
        debugPrint('Desktop outbox sync: $e');
      }

      await container.read(messageSyncServiceProvider).syncInbox(force: force);
      _lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('❌ Desktop background sync error: $e');
    }
  }

  static void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _initialized = false;
    _container = null;
  }
}
