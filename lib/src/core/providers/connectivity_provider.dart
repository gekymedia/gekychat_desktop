import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/message_queue_service.dart';
import '../../services/background_sync_worker.dart';

bool _resultsIndicateOnline(List<ConnectivityResult> results) {
  // Desktop (especially Windows): plugin often returns [] — treat as online so we still hit the API.
  if (results.isEmpty) return true;
  return results.any((r) => r != ConnectivityResult.none);
}

class ConnectivityNotifier extends StateNotifier<bool> {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final Ref _ref;
  bool _wasOffline = false;

  ConnectivityNotifier(this._ref) : _connectivity = Connectivity(), super(true) {
    _init();
  }

  Future<void> _init() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    final isOnline = _resultsIndicateOnline(result);
    state = isOnline;
    _wasOffline = !isOnline;
    
    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final newState = _resultsIndicateOnline(results);
      final wasOffline = !state;
      state = newState;
      
      // If we just came back online, sync pending messages and pull from server
      if (newState && wasOffline) {
        _syncPendingMessages();
        unawaited(BackgroundSyncWorker.triggerSync(force: true));
      }
    });
  }

  Future<void> _syncPendingMessages() async {
    try {
      final messageQueue = _ref.read(messageQueueServiceProvider);
      await messageQueue.syncPendingMessages();
    } catch (e) {
      // Ignore sync errors
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier(ref);
});
