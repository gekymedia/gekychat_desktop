import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../features/status/status_list_screen.dart';

/// Listens on public `status.updates` for `status.created` (Laravel StatusCreated).
class StatusRealtimeSync {
  StatusRealtimeSync(this._ref);

  final Ref _ref;
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    _ready = true;

    try {
      final pusher = _ref.read(pusherServiceProvider);
      const channel = 'status.updates';

      await pusher.subscribePublic(channel, (_) {});
      pusher.listen(channel, 'status.created', (_) {
        debugPrint('📸 StatusRealtimeSync: status.created — refreshing list');
        _ref.invalidate(statusListProvider);
        _ref.invalidate(myStatusProvider);
      });

      unawaited(
        pusher.connect().catchError((e) {
          debugPrint('⚠️ StatusRealtimeSync Pusher connect: $e');
        }),
      );

      debugPrint('✅ StatusRealtimeSync listening on $channel');
    } catch (e) {
      _ready = false;
      debugPrint('❌ StatusRealtimeSync init failed: $e');
    }
  }

  void dispose() {
    _ready = false;
  }
}

final statusRealtimeSyncProvider = Provider<StatusRealtimeSync>((ref) {
  final sync = StatusRealtimeSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});
