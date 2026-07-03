import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/json_coercion.dart';
import '../../../core/providers.dart';
import '../../../core/session.dart';
import '../../realtime/pusher_service.dart';

/// Group chats list: typing indicators per group id.
final groupTypingStatusProvider =
    StateNotifierProvider<GroupTypingStatusNotifier, Map<int, bool>>((ref) {
  return GroupTypingStatusNotifier(ref);
});

/// Group chats list: voice recording indicators per group id.
final groupRecordingStatusProvider =
    StateNotifierProvider<GroupRecordingStatusNotifier, Map<int, bool>>((ref) {
  return GroupRecordingStatusNotifier(ref);
});

class GroupTypingStatusNotifier extends StateNotifier<Map<int, bool>> {
  GroupTypingStatusNotifier(this._ref) : super({}) {
    _initializeListener();
  }

  final Ref _ref;
  PusherService? _pusherService;
  final Map<int, Timer> _typingTimers = {};
  final Set<int> _subscribedGroups = {};

  Future<void> _initializeListener() async {
    _pusherService = _ref.read(pusherServiceProvider);
    await _pusherService!.connect();
  }

  void _handleTypingEvent(int groupId, dynamic data) {
    if (data is! Map) return;
    final userId = asInt(data['user_id']);
    final isTyping = data['is_typing'] == true ||
        data['is_typing'] == 1 ||
        data['is_typing'] == '1';
    if (userId == null) return;

    unawaited(_ref.read(currentUserProvider.future).then((currentUser) {
      if (userId == currentUser.id) return;

      _typingTimers[groupId]?.cancel();
      final newState = Map<int, bool>.from(state);
      newState[groupId] = isTyping;
      state = newState;

      if (isTyping) {
        _typingTimers[groupId] = Timer(const Duration(seconds: 3), () {
          final updated = Map<int, bool>.from(state);
          updated[groupId] = false;
          state = updated;
          _typingTimers.remove(groupId);
        });
      } else {
        _typingTimers.remove(groupId);
      }
    }));
  }

  void subscribeToGroup(int groupId) {
    if (_subscribedGroups.contains(groupId)) return;

    if (_pusherService == null) {
      unawaited(_initializeListener().then((_) {
        if (_subscribedGroups.contains(groupId)) return;
        subscribeToGroup(groupId);
      }));
      return;
    }

    _subscribedGroups.add(groupId);
    final channel = 'group.$groupId';

    void onEvent(dynamic data) => _handleTypingEvent(groupId, data);

    _pusherService!.listen(channel, 'TypingInGroup', onEvent);
    _pusherService!.listen(channel, 'GroupTyping', onEvent);
  }

  void subscribeToGroups(List<int> groupIds) {
    for (final id in groupIds) {
      subscribeToGroup(id);
    }
  }

  @override
  void dispose() {
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _subscribedGroups.clear();
    super.dispose();
  }
}

class GroupRecordingStatusNotifier extends StateNotifier<Map<int, bool>> {
  GroupRecordingStatusNotifier(this._ref) : super({}) {
    _initializeListener();
  }

  final Ref _ref;
  PusherService? _pusherService;
  final Map<int, Timer> _recordingTimers = {};
  final Set<int> _subscribedGroups = {};

  Future<void> _initializeListener() async {
    _pusherService = _ref.read(pusherServiceProvider);
    await _pusherService!.connect();
  }

  void subscribeToGroup(int groupId) {
    if (_subscribedGroups.contains(groupId)) return;

    if (_pusherService == null) {
      unawaited(_initializeListener().then((_) {
        if (_subscribedGroups.contains(groupId)) return;
        subscribeToGroup(groupId);
      }));
      return;
    }

    _subscribedGroups.add(groupId);

    void onEvent(dynamic data) {
      if (data is! Map) return;
      final userId = asInt(data['user_id']);
      final isRecording = data['is_recording'] == true ||
          data['is_recording'] == 1 ||
          data['is_recording'] == '1';
      if (userId == null) return;

      unawaited(_ref.read(currentUserProvider.future).then((currentUser) {
        if (userId == currentUser.id) return;

        _recordingTimers[groupId]?.cancel();
        final newState = Map<int, bool>.from(state);
        newState[groupId] = isRecording;
        state = newState;

        if (isRecording) {
          _recordingTimers[groupId] = Timer(const Duration(seconds: 6), () {
            final updated = Map<int, bool>.from(state);
            updated[groupId] = false;
            state = updated;
            _recordingTimers.remove(groupId);
          });
        } else {
          _recordingTimers.remove(groupId);
        }
      }));
    }

    _pusherService!.listen('group.$groupId', '.UserRecording', onEvent);
    _pusherService!.listen('group.$groupId', 'UserRecording', onEvent);
  }

  void subscribeToGroups(List<int> groupIds) {
    for (final id in groupIds) {
      subscribeToGroup(id);
    }
  }

  @override
  void dispose() {
    for (final timer in _recordingTimers.values) {
      timer.cancel();
    }
    _recordingTimers.clear();
    _subscribedGroups.clear();
    super.dispose();
  }
}
