import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/message_queue_service.dart';

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
    final isOnline = result.any((r) => r != ConnectivityResult.none);
    state = isOnline;
    _wasOffline = !isOnline;
    
    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final newState = results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !state;
      state = newState;
      
      // If we just came back online, sync pending messages
      if (newState && wasOffline) {
        _syncPendingMessages();
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
