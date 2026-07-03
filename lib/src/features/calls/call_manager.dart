// lib/src/features/calls/call_manager.dart
//
// Call session + signaling only. All voice/video media uses LiveKit — see
// docs/CALL_ARCHITECTURE.md in gekychat_mobile (do not add WebRTC here).
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../realtime/pusher_service.dart';
import 'call_end_reason.dart';
import 'call_repository.dart';
import 'call_session.dart';

const String _keyPendingEndCallIds = 'pending_end_call_ids';
const String _keyPendingLeaveCallIds = 'pending_leave_call_ids';
const String _keyPendingDeclineCallIds = 'pending_decline_call_ids';

int? _parseCallSessionId(Map<String, dynamic> response) {
  dynamic raw =
      response['session_id'] ?? response['call_session_id'] ?? response['id'];
  final data = response['data'];
  if (raw == null && data is Map) {
    final d = Map<String, dynamic>.from(data);
    raw = d['session_id'] ?? d['call_session_id'] ?? d['id'];
  }
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

enum CallState {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  ended,
}

class CallManager {
  final CallRepository _callRepo;
  final PusherService _pusherService;

  CallSession? _currentCall;
  CallState _callState = CallState.idle;
  String _callType = 'voice';
  bool _isCaller = false;

  Timer? _callTimeoutTimer;
  static const Duration _callTimeout = Duration(seconds: 60);
  bool _liveKitRoomActive = false;

  Function(CallState)? onCallStateChanged;
  Function(Map<String, dynamic>)? onCallSignal;
  Function(String)? onError;
  VoidCallback? onNoAnswerUi;
  void Function(int userId)? onParticipantLeft;

  CallManager(this._callRepo, this._pusherService);

  CallState get callState => _callState;
  set callState(CallState value) => _emitCallState(value);

  void _emitCallState(CallState value) {
    _callState = value;
    onCallStateChanged?.call(value);
  }

  CallSession? get currentCall => _currentCall;
  set currentCall(CallSession? value) => _currentCall = value;

  bool get isCaller => _isCaller;
  set isCaller(bool value) => _isCaller = value;

  String get callType => _callType;
  set callType(String value) => _callType = value;

  bool get hasActiveCall =>
      _callState != CallState.idle && _callState != CallState.ended;

  Future<void> startCall({
    int? calleeId,
    int? groupId,
    int? conversationId,
    required String type,
  }) async {
    if (hasActiveCall) {
      const error = 'Please end your current call before starting a new one';
      onError?.call(error);
      throw StateError(error);
    }

    try {
      _callType = type;
      _isCaller = true;

      final response = await _callRepo.startCall(
        calleeId: calleeId,
        groupId: groupId,
        conversationId: conversationId,
        type: type,
      );

      final sessionId = _parseCallSessionId(response);
      if (sessionId == null) {
        throw FormatException(
          'Start call response missing session_id: ${response.keys.toList()}',
        );
      }

      _currentCall = CallSession(
        id: sessionId,
        callerId: 0,
        calleeId: calleeId,
        groupId: groupId,
        conversationId: conversationId,
        type: type,
        status: 'pending',
        callLink: response['call_link'] as String?,
      );

      _emitCallState(CallState.calling);
      _startCallTimeout();
      await _setupSignaling();
    } catch (e) {
      debugPrint('Error starting call: $e');
      _callTimeoutTimer?.cancel();
      _emitCallState(CallState.ended);
      if (e is CallStartException) {
        onError?.call(e.userMessage);
      } else {
        onError?.call('Failed to start call: $e');
      }
      rethrow;
    }
  }

  Future<void> declineCall({int? sessionIdOverride, int? groupId}) async {
    final sessionId = sessionIdOverride ?? _currentCall?.id;
    if (sessionId == null) return;
    final resolvedGroupId = groupId ?? _currentCall?.groupId;
    // Group invites are optional — server has no decline endpoint; dismiss locally.
    final serverAction = resolvedGroupId != null && resolvedGroupId > 0
        ? _CallServerAction.none
        : _CallServerAction.decline;
    await _finishCallSession(
      sessionIdOverride: sessionId,
      serverAction: serverAction,
    );
  }

  Future<void> endCall({int? sessionIdOverride, String? reason}) async {
    await _finishCallSession(
      sessionIdOverride: sessionIdOverride,
      serverAction: _CallServerAction.end,
      endReason: reason,
    );
  }

  Future<void> leaveCall({int? sessionIdOverride}) async {
    await _finishCallSession(
      sessionIdOverride: sessionIdOverride,
      serverAction: _CallServerAction.leave,
    );
  }

  Future<void> abandonCallLocally({int? sessionIdOverride}) async {
    await _finishCallSession(
      sessionIdOverride: sessionIdOverride,
      serverAction: _CallServerAction.none,
    );
  }

  Future<void> _finishCallSession({
    int? sessionIdOverride,
    required _CallServerAction serverAction,
    String? endReason,
  }) async {
    _callTimeoutTimer?.cancel();
    final sessionId = sessionIdOverride ?? _currentCall?.id;

    await _cleanup();
    if (_callState != CallState.ended) {
      _emitCallState(CallState.ended);
    }

    if (sessionId == null) return;
    switch (serverAction) {
      case _CallServerAction.end:
        unawaited(_endCallOnServerBestEffort(sessionId, reason: endReason));
      case _CallServerAction.decline:
        unawaited(_declineCallOnServerBestEffort(sessionId));
      case _CallServerAction.leave:
        unawaited(_leaveCallOnServerBestEffort(sessionId));
      case _CallServerAction.none:
        break;
    }
  }

  Future<void> _endCallOnServerBestEffort(int sessionId, {String? reason}) async {
    try {
      await _callRepo.endCall(sessionId, reason: reason);
    } catch (e) {
      debugPrint('Error ending call (will retry when online): $e');
      await _storePendingServerAction(_keyPendingEndCallIds, sessionId);
    }
  }

  Future<void> _declineCallOnServerBestEffort(int sessionId) async {
    try {
      await _callRepo.declineCall(sessionId);
    } catch (e) {
      debugPrint('Error declining call (will retry when online): $e');
      await _storePendingServerAction(_keyPendingDeclineCallIds, sessionId);
    }
  }

  Future<void> _leaveCallOnServerBestEffort(int sessionId) async {
    try {
      await _callRepo.leaveCall(sessionId);
    } catch (e) {
      debugPrint('Error leaving call (will retry when online): $e');
      await _storePendingServerAction(_keyPendingLeaveCallIds, sessionId);
    }
  }

  static Future<void> _storePendingServerAction(String key, int sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final list =
          raw != null ? (jsonDecode(raw) as List).cast<String>() : <String>[];
      list.add(sessionId.toString());
      await prefs.setString(key, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> retryPendingEndCalls() async {
    await _retryPendingServerActions(_keyPendingEndCallIds, _callRepo.endCall);
  }

  Future<void> retryPendingDeclineCalls() async {
    await _retryPendingServerActions(
      _keyPendingDeclineCallIds,
      _callRepo.declineCall,
    );
  }

  Future<void> retryPendingLeaveCalls() async {
    await _retryPendingServerActions(
      _keyPendingLeaveCallIds,
      _callRepo.leaveCall,
    );
  }

  Future<void> _retryPendingServerActions(
    String key,
    Future<void> Function(int) action,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return;
      final list = List<String>.from((jsonDecode(raw) as List).cast<String>());
      if (list.isEmpty) return;
      final remaining = <String>[];
      for (final idStr in list) {
        final id = int.tryParse(idStr);
        if (id == null) continue;
        try {
          await action(id);
        } catch (_) {
          remaining.add(idStr);
        }
      }
      if (remaining.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(remaining));
      }
    } catch (_) {}
  }

  void cancelOutgoingTimeout() {
    _callTimeoutTimer?.cancel();
  }

  void notifyLiveKitRoomConnected() {
    _liveKitRoomActive = true;
  }

  void notifyLiveKitRoomDisconnected() {
    _liveKitRoomActive = false;
    if (_callState != CallState.ended) {
      _emitCallState(CallState.ended);
    }
    _currentCall = null;
  }

  void notifyRemoteParticipantJoined() {
    _callTimeoutTimer?.cancel();
    if (_callState == CallState.calling || _callState == CallState.ringing) {
      _emitCallState(CallState.connecting);
    } else if (_callState != CallState.connected) {
      _emitCallState(CallState.connected);
    }
  }

  void handleSignal(dynamic data) {
    try {
      if (_currentCall == null) return;

      final signalData = data is String ? jsonDecode(data) : data;
      final payload = signalData['payload'] is String
          ? jsonDecode(signalData['payload'] as String)
          : signalData['payload'] as Map<String, dynamic>;

      onCallSignal?.call(payload);

      if (payload['action'] == 'invite' && !_isCaller) {
        _emitCallState(CallState.ringing);
      } else if (payload['action'] == 'callee-ringing' && _isCaller) {
        if (_callState == CallState.calling) {
          _emitCallState(CallState.ringing);
        }
      } else if (payload['action'] == 'busy' && _isCaller) {
        _callTimeoutTimer?.cancel();
        onError?.call('User is busy on another call.');
        endCall();
      } else if (payload['action'] == 'cancel') {
        if (!_payloadMatchesCurrentSession(payload)) return;
        abandonCallLocally();
      } else if (!_payloadMatchesCurrentSession(payload)) {
        return;
      } else if (payload['action'] == 'declined' ||
          (payload['action'] == 'ended' &&
              payload['reason']?.toString() == 'declined')) {
        onError?.call(
          callerMessageForCallEndSignal(payload, hadRemoteParticipant: false),
        );
        abandonCallLocally();
      } else if (payload['action'] == 'ended') {
        onError?.call(
          callerMessageForCallEndSignal(
            payload,
            hadRemoteParticipant: _liveKitRoomActive &&
                (_callState == CallState.connected ||
                    _callState == CallState.connecting),
          ),
        );
        abandonCallLocally();
      } else if (payload['action'] == 'participant-left') {
        final userId = int.tryParse(payload['user_id']?.toString() ?? '');
        if (userId != null) {
          onParticipantLeft?.call(userId);
        }
      } else if (payload['type'] == 'livekit-joined' && _isCaller) {
        _callTimeoutTimer?.cancel();
        if (_callState != CallState.connected) {
          _emitCallState(CallState.connecting);
        }
      }
    } catch (e) {
      debugPrint('Error handling call signal: $e');
    }
  }

  bool _payloadMatchesCurrentSession(Map<String, dynamic> payload) {
    if (_currentCall == null) return false;
    final sid = int.tryParse(payload['session_id']?.toString() ?? '');
    if (sid == null) return true;
    return sid == _currentCall!.id;
  }

  Future<void> ensureSignalingSubscribed() async {
    await _setupSignaling();
  }

  Future<void> _setupSignaling() async {
    if (_currentCall == null) return;

    final prefs = await SharedPreferences.getInstance();
    final myUserId =
        prefs.getInt('user_id') ?? int.tryParse(prefs.getString('user_id') ?? '');

    String channel;
    if (_currentCall!.groupId != null) {
      channel = 'group.${_currentCall!.groupId}.call';
    } else if (myUserId != null && myUserId > 0) {
      channel = 'call.$myUserId';
    } else if (_currentCall!.conversationId != null) {
      channel = 'conversation.${_currentCall!.conversationId}';
    } else {
      channel = 'call.${_currentCall!.calleeId}';
    }

    await _pusherService.subscribePrivate(channel, (_) {});
    _pusherService.listen(channel, 'CallSignal', handleSignal);
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(_callTimeout, () {
      if (_callState == CallState.calling || _callState == CallState.ringing) {
        debugPrint('Call timeout - no answer received');
        onNoAnswerUi?.call();
        unawaited(Future<void>.delayed(const Duration(milliseconds: 2000), () {
          if (_callState == CallState.calling || _callState == CallState.ringing) {
            endCall(reason: 'no_answer');
          }
        }));
      }
    });
  }

  Future<void> _cleanup() async {
    _callTimeoutTimer?.cancel();
    _liveKitRoomActive = false;
    _currentCall = null;
    _isCaller = false;
    onParticipantLeft = null;
  }

  Future<void> dispose() async {
    await _cleanup();
  }
}

enum _CallServerAction { end, decline, leave, none }
