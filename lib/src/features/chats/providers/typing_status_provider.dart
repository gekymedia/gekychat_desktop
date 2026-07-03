import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/json_coercion.dart';
import '../../../core/providers.dart';
import '../../../core/session.dart';
import '../../realtime/pusher_service.dart';

/// Provider that tracks typing status for all conversations
final typingStatusProvider = StateNotifierProvider<TypingStatusNotifier, Map<int, bool>>((ref) {
  return TypingStatusNotifier(ref);
});

/// Provider that tracks recording status separately
final recordingStatusProvider = StateNotifierProvider<RecordingStatusNotifier, Map<int, bool>>((ref) {
  return RecordingStatusNotifier(ref);
});

class TypingStatusNotifier extends StateNotifier<Map<int, bool>> {
  final Ref _ref;
  TypingStatusNotifier(this._ref) : super({}) {
    _initializeListener();
  }

  PusherService? _pusherService;
  final Map<int, Timer> _typingTimers = {};
  final Set<int> _subscribedConversations = {};

  Future<void> _initializeListener() async {
    _pusherService = _ref.read(pusherServiceProvider);
    await _pusherService!.connect();
  }

  /// Re-bind after a channel was torn down (e.g. legacy full unsubscribe).
  void resubscribeToConversation(int conversationId) {
    _subscribedConversations.remove(conversationId);
    subscribeToConversation(conversationId);
  }

  void subscribeToConversation(int conversationId) {
    if (_subscribedConversations.contains(conversationId)) {
      return;
    }

    if (_pusherService == null) {
      unawaited(_initializeListener().then((_) {
        if (_subscribedConversations.contains(conversationId)) return;
        subscribeToConversation(conversationId);
      }));
      return;
    }

    _subscribedConversations.add(conversationId);

    _pusherService!.listen(
      'conversation.$conversationId',
      'UserTyping',
      (data) {
        if (data is Map) {
          final userId = asInt(data['user_id']);
          final isTyping = data['is_typing'] == true ||
              data['is_typing'] == 1 ||
              data['is_typing'] == '1';

          final currentUserAsync = _ref.read(currentUserProvider.future);
          currentUserAsync.then((currentUser) {
            if (userId != null && userId != currentUser.id) {
              _typingTimers[conversationId]?.cancel();

              final newState = Map<int, bool>.from(state);
              newState[conversationId] = isTyping;
              state = newState;

              if (isTyping) {
                _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
                  final updatedState = Map<int, bool>.from(state);
                  updatedState[conversationId] = false;
                  state = updatedState;
                  _typingTimers.remove(conversationId);
                });
              } else {
                _typingTimers.remove(conversationId);
              }
            }
          });
        }
      },
    );
  }

  void subscribeToConversations(List<int> conversationIds) {
    for (final id in conversationIds) {
      subscribeToConversation(id);
    }
  }

  void unsubscribeFromConversation(int conversationId) {
    _subscribedConversations.remove(conversationId);
    _typingTimers[conversationId]?.cancel();
    _typingTimers.remove(conversationId);
    final newState = Map<int, bool>.from(state);
    newState.remove(conversationId);
    state = newState;
  }

  bool isTyping(int conversationId) => state[conversationId] ?? false;

  void clearTyping(int conversationId) {
    _typingTimers[conversationId]?.cancel();
    _typingTimers.remove(conversationId);
    final newState = Map<int, bool>.from(state);
    newState[conversationId] = false;
    state = newState;
  }

  @override
  void dispose() {
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _subscribedConversations.clear();
    super.dispose();
  }
}

class RecordingStatusNotifier extends StateNotifier<Map<int, bool>> {
  final Ref _ref;
  RecordingStatusNotifier(this._ref) : super({}) {
    _initializeListener();
  }

  PusherService? _pusherService;
  final Set<int> _subscribedConversations = {};

  Future<void> _initializeListener() async {
    _pusherService = _ref.read(pusherServiceProvider);
    await _pusherService!.connect();
  }

  void resubscribeToConversation(int conversationId) {
    _subscribedConversations.remove(conversationId);
    subscribeToConversation(conversationId);
  }

  void subscribeToConversation(int conversationId) {
    if (_subscribedConversations.contains(conversationId)) {
      return;
    }

    if (_pusherService == null) {
      unawaited(_initializeListener().then((_) {
        if (_subscribedConversations.contains(conversationId)) return;
        subscribeToConversation(conversationId);
      }));
      return;
    }

    _subscribedConversations.add(conversationId);

    _pusherService!.listen(
      'conversation.$conversationId',
      'UserRecording',
      (data) {
        if (data is Map) {
          final userId = asInt(data['user_id']);
          final isRecording = data['is_recording'] == true ||
              data['is_recording'] == 1 ||
              data['is_recording'] == '1';

          final currentUserAsync = _ref.read(currentUserProvider.future);
          currentUserAsync.then((currentUser) {
            if (userId != null && userId != currentUser.id) {
              final newState = Map<int, bool>.from(state);
              newState[conversationId] = isRecording;
              state = newState;
            }
          });
        }
      },
    );
  }

  void subscribeToConversations(List<int> conversationIds) {
    for (final id in conversationIds) {
      subscribeToConversation(id);
    }
  }

  void unsubscribeFromConversation(int conversationId) {
    _subscribedConversations.remove(conversationId);
    final newState = Map<int, bool>.from(state);
    newState.remove(conversationId);
    state = newState;
  }

  bool isRecording(int conversationId) => state[conversationId] ?? false;

  void clearRecording(int conversationId) {
    final newState = Map<int, bool>.from(state);
    newState[conversationId] = false;
    state = newState;
  }

  @override
  void dispose() {
    _subscribedConversations.clear();
    super.dispose();
  }
}
