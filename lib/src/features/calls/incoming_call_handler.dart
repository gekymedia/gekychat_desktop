// lib/src/features/calls/incoming_call_handler.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/desktop_window_service.dart';
import '../../core/global_navigator_key.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../features/notifications/notification_manager.dart';
import '../realtime/pusher_service.dart';
import 'call_busy_helper.dart';
import 'call_manager.dart';
import 'call_session.dart';
import 'joinable_call_message.dart';
import 'call_waiting_dialog.dart';
import 'call_navigation.dart';
import 'join_call_from_link.dart';
import 'livekit_call_screen.dart';
import 'providers.dart';
import '../../services/livekit_call_service.dart';
import '../../core/providers/connectivity_provider.dart';

/// Global handler for incoming calls. Uses [rootNavigatorKey] so the ring UI
/// works from any route (settings, calls tab, etc.), not only [DesktopChatScreen].
class IncomingCallHandler {
  IncomingCallHandler(this._pusherService);

  final PusherService _pusherService;
  Ref? _ref;
  CallManager? _callManager;
  int? _currentUserId;
  NotificationManager? _notificationManager;
  bool _initialized = false;
  int? _listeningUserId;

  CallSession? _pendingCall;
  String? _pendingCallerName;
  String? _pendingCallerAvatar;
  int? _pendingConversationId;
  int? _pendingGroupId;
  bool _ringScreenRouteOpen = false;
  bool _incomingRingOnStack = false;
  bool _liveKitScreenRouteOpen = false;
  bool _liveKitOnStack = false;
  Timer? _incomingUiFallbackTimer;
  DateTime? _lastPendingInviteFetch;
  DateTime? _lastAppResumedAt;
  bool _pendingInviteFetchInProgress = false;
  static const Duration _pendingInviteMinInterval = Duration(seconds: 45);
  static const Duration _appResumeDebounce = Duration(seconds: 3);

  bool get isCallUiOnStack =>
      _incomingRingOnStack ||
      _liveKitOnStack ||
      _ringScreenRouteOpen ||
      _liveKitScreenRouteOpen;

  CallSession? _waitingCall;
  String? _waitingCallerName;
  String? _waitingCallerAvatar;
  int? _waitingConversationId;
  int? _waitingGroupId;
  Timer? _waitingCallTimer;
  static const Duration _waitingCallTimeout = Duration(seconds: 45);
  static const Duration _calleeRingingNotifyDelay = Duration(milliseconds: 450);

  Future<void> initialize(Ref ref) async {
    _ref = ref;
    await hydrateDismissedDeadCallKeys(ref.container);

    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');

    if (_currentUserId == null) return;
    if (_initialized && _listeningUserId == _currentUserId) {
      await _fetchPendingInvite();
      await tryShowPendingIncomingRing();
      return;
    }
    _listeningUserId = _currentUserId;
    _initialized = true;

    _callManager = ref.read(callManagerProvider);

    try {
      final apiService = ref.read(apiServiceProvider);
      _notificationManager = await NotificationManager.create(apiService, ref);
    } catch (_) {}

    final userId = _currentUserId!;
    final userChannel = 'private-user.$userId';

    await _pusherService.subscribePrivate(userChannel, (_) {});
    _pusherService.listen(userChannel, 'CallInvite', (data) {
      _handleCallInvite(data);
    });

    await _pusherService.subscribePrivate('call.$userId', (_) {});
    _pusherService.listen('call.$userId', 'CallSignal', (data) {
      _handleCallSignal(data);
    });

    unawaited(_pusherService.connect());
    await _fetchPendingInvite(force: true);
    await tryShowPendingIncomingRing();
  }

  /// Fetches pending incoming call from API (offline ring recovery).
  Future<void> _fetchPendingInvite({bool force = false}) async {
    if (_ref == null || _callManager == null) return;

    if (!force) {
      if (_pendingInviteFetchInProgress) return;
      final last = _lastPendingInviteFetch;
      if (last != null &&
          DateTime.now().difference(last) < _pendingInviteMinInterval) {
        return;
      }
    }

    if (!_ref!.read(connectivityProvider)) return;

    _pendingInviteFetchInProgress = true;
    _lastPendingInviteFetch = DateTime.now();
    try {
      final repo = _ref!.read(callRepositoryProvider);
      final data = await repo.getPendingInvite();
      final invite = data['invite'];
      if (invite is! Map) return;
      final inviteMap = Map<String, dynamic>.from(invite);
      if (inviteMap['session_id'] == null) return;
      if (_pendingCall != null || _waitingCall != null) return;
      inviteMap['action'] = 'invite';
      if (inviteMap['caller'] is! Map) {
        final c = inviteMap['caller'];
        inviteMap['caller'] = c is Map
            ? Map<String, dynamic>.from(c)
            : {'id': 0, 'name': 'Unknown'};
      }
      unawaited(_handleIncomingCall(inviteMap));
    } catch (e) {
      debugPrint('fetchPendingInvite failed: $e');
    } finally {
      _pendingInviteFetchInProgress = false;
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _extractPayload(dynamic data) {
    try {
      final signalData = data is String ? jsonDecode(data) : data;
      if (signalData is! Map) return null;
      final map = Map<String, dynamic>.from(signalData);

      final payload = map['payload'];
      if (payload is String) {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        return null;
      }
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
      if (map['action'] == 'invite') {
        return map;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _handleCallInvite(dynamic data) {
    try {
      final invite = data is String ? jsonDecode(data) : data;
      if (invite is! Map) return;
      final map = Map<String, dynamic>.from(invite);
      map['action'] = 'invite';
      if (map['session_id'] == null && map['call_id'] != null) {
        map['session_id'] = map['call_id'];
      }
      handleIncomingCallFromConversation(
        {'payload': map},
        _asInt(map['conversation_id']),
      );
    } catch (e) {
      debugPrint('Error handling CallInvite: $e');
    }
  }

  void _handleCallSignal(dynamic data) {
    final payload = _extractPayload(data);
    if (payload == null) return;
    if (payload['action'] == 'invite') {
      unawaited(_handleIncomingCall(payload));
    } else if (payload['action'] == 'end' ||
        payload['action'] == 'cancel' ||
        payload['action'] == 'ended' ||
        payload['action'] == 'declined') {
      _handleCallCancelled(payload);
    } else {
      final type = payload['type']?.toString();
      if (type == 'video-upgrade-request' ||
          type == 'video-upgrade-accepted' ||
          type == 'video-upgrade-declined') {
        // Backup path: CallManager may early-return when _currentCall is unset.
        _callManager?.onCallSignal?.call(payload);
      }
    }
  }

  void handleIncomingCallFromConversation(dynamic data, int? conversationId) {
    final payload = _extractPayload(data);
    if (payload == null) return;
    if (conversationId != null && payload['conversation_id'] == null) {
      payload['conversation_id'] = conversationId;
    }
    if (payload['action'] == 'invite') {
      unawaited(_handleIncomingCall(payload));
    } else if (payload['action'] == 'end' ||
        payload['action'] == 'cancel' ||
        payload['action'] == 'ended' ||
        payload['action'] == 'declined') {
      _handleCallCancelled(payload);
    }
  }

  /// Fallback when inbox delivers call_data but CallInvite was missed.
  Future<void> handleInviteFromCallMessage({
    required Map<String, dynamic> callData,
    required Map<String, dynamic>? sender,
    int? conversationId,
    int? groupId,
  }) async {
    if (!isJoinableCallDataStatus(callData['status'] as String?)) return;
    final sessionId = sessionIdFromCallData(callData);
    if (sessionId == null) return;

    final callerId =
        _asInt(callData['caller_id']) ?? _asInt(sender?['id']) ?? 0;
    if (callerId > 0 && callerId == _currentUserId) return;

    final callerMap = sender != null
        ? Map<String, dynamic>.from(sender)
        : <String, dynamic>{
            if (callerId > 0) 'id': callerId,
            'name': 'Someone',
          };
    if (callerMap['id'] == null && callerId > 0) {
      callerMap['id'] = callerId;
    }

    await _handleIncomingCall(<String, dynamic>{
      'action': 'invite',
      'session_id': sessionId,
      'call_id': sessionId,
      'type': callData['type']?.toString() ?? 'voice',
      if (conversationId != null && conversationId > 0)
        'conversation_id': conversationId,
      if (groupId != null && groupId > 0) 'group_id': groupId,
      'caller': callerMap,
    });
  }

  Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    final sessionId = _asInt(data['session_id']) ?? _asInt(data['call_id']);
    if (sessionId == null) return;

    await _handleIncomingCall(<String, dynamic>{
      'action': 'invite',
      'session_id': sessionId,
      'call_id': sessionId,
      'type': data['call_type']?.toString() ?? data['type']?.toString() ?? 'voice',
      'conversation_id': data['conversation_id'],
      'group_id': data['group_id'],
      'caller': <String, dynamic>{
        'id': _asInt(data['caller_id']) ?? 0,
        'name': data['caller_name']?.toString() ?? 'Someone',
        'avatar': data['caller_avatar']?.toString(),
        'phone': data['caller_phone']?.toString() ?? '',
      },
    });
  }

  Future<void> tryShowPendingIncomingRing() async {
    if (_pendingCall == null || _callManager == null) return;
    if (_callManager!.callState != CallState.ringing) return;
    if (_incomingRingOnStack) return;
    await _pushCallScreenWhenReady();
  }

  Future<void> fetchPendingInviteOnFocus() async {
    await _fetchPendingInvite();
    if (_ref != null) {
      await ensureIncomingCallUiVisible(_ref!);
    }
  }

  Future<void> handleAppResumed() async {
    if (_ref == null) return;
    final now = DateTime.now();
    if (_lastAppResumedAt != null &&
        now.difference(_lastAppResumedAt!) < _appResumeDebounce) {
      return;
    }
    _lastAppResumedAt = now;

    _callManager ??= _ref!.read(callManagerProvider);
    await _fetchPendingInvite();
    await ensureIncomingCallUiVisible(_ref!);
    _startIncomingCallUiFallback();
  }

  Future<void> ensureIncomingCallUiVisible(Ref ref) async {
    _ref ??= ref;
    _callManager ??= ref.read(callManagerProvider);
    if (_callManager!.isCaller || _callManager!.callState == CallState.calling) {
      return;
    }
    if (_waitingCall != null) return;

    if (_pendingCall == null) return;

    final liveKitBusy = ref.read(liveKitCallServiceProvider).hasActiveCall;

    if (_callManager!.callState == CallState.ringing &&
        !_incomingRingOnStack &&
        !_ringScreenRouteOpen &&
        !liveKitBusy) {
      await _pushCallScreenWhenReady();
      return;
    }

    if ((_callManager!.callState == CallState.connecting ||
            _callManager!.callState == CallState.connected) &&
        !liveKitBusy &&
        !_liveKitOnStack &&
        !_liveKitScreenRouteOpen) {
      final ringWasOnStack = _incomingRingOnStack;
      await _dismissInAppRingOverlay();
      await _openLiveKitForPendingCall(replaceCurrentRoute: ringWasOnStack);
    }
  }

  void _startIncomingCallUiFallback() {
    if (_ref == null || _callManager?.isCaller == true) return;
    _incomingUiFallbackTimer?.cancel();
    var tick = 0;
    final ref = _ref!;
    _incomingUiFallbackTimer = Timer.periodic(
      const Duration(milliseconds: 400),
      (timer) async {
        tick++;
        if (tick > 50) {
          timer.cancel();
          _incomingUiFallbackTimer = null;
          return;
        }
        if (_callManager?.isCaller == true) {
          timer.cancel();
          _incomingUiFallbackTimer = null;
          return;
        }
        if (_liveKitOnStack || _incomingRingOnStack) {
          timer.cancel();
          _incomingUiFallbackTimer = null;
          return;
        }
        await ensureIncomingCallUiVisible(ref);
        if (_liveKitOnStack || _incomingRingOnStack) {
          timer.cancel();
          _incomingUiFallbackTimer = null;
        }
      },
    );
  }

  Future<void> _dismissInAppRingOverlay() async {
    if (!_incomingRingOnStack) return;
    final cs = _callManager?.callState;
    if (_liveKitOnStack &&
        cs != null &&
        cs != CallState.ringing &&
        cs != CallState.idle) {
      _incomingRingOnStack = false;
      return;
    }
    final navigator = rootNavigatorKey.currentState;
    if (navigator?.canPop() ?? false) {
      navigator!.pop();
    }
    _incomingRingOnStack = false;
  }

  Future<bool> acceptPendingCallInPlace() async {
    if (_callManager == null || _pendingCall == null || _ref == null) {
      return false;
    }
    _callManager!.currentCall = _pendingCall;
    _callManager!.callType = _pendingCall!.type;
    _callManager!.isCaller = false;
    _callManager!.callState = CallState.connecting;
    _incomingRingOnStack = false;
    await _ref!.read(callRepositoryProvider).acceptIncomingCallSession(
          _pendingCall!.id,
        );
    await _callManager?.ensureSignalingSubscribed();
    _incomingUiFallbackTimer?.cancel();
    return true;
  }

  /// Decline from unified incoming screen — always notifies server for 1:1 calls.
  Future<void> declinePendingIncomingCall(int sessionId, {int? groupId}) async {
    if (_ref == null) return;
    debugPrint('📞 declinePendingIncomingCall($sessionId)');

    _incomingUiFallbackTimer?.cancel();

    final pending = _pendingCall;
    final isGroupInvite = (groupId ?? _pendingGroupId ?? pending?.groupId) != null &&
        (groupId ?? _pendingGroupId ?? pending?.groupId)! > 0;
    if (!isGroupInvite) {
      try {
        await _ref!.read(callRepositoryProvider).declineCall(sessionId);
      } catch (e) {
        debugPrint('📞 declinePendingIncomingCall server error: $e');
        unawaited(_callManager?.retryPendingDeclineCalls());
      }
    }

    if (_callManager != null) {
      await _callManager!.abandonCallLocally(sessionIdOverride: sessionId);
    }
    _pendingCall = null;
    _pendingCallerName = null;
    _pendingCallerAvatar = null;
    _pendingConversationId = null;
    _pendingGroupId = null;
    _incomingRingOnStack = false;
    _liveKitOnStack = false;
  }

  Future<bool> acceptPendingCall({bool replaceRingRoute = false}) async {
    if (_callManager == null || _pendingCall == null || _ref == null) {
      return false;
    }
    _callManager!.currentCall = _pendingCall;
    _callManager!.callType = _pendingCall!.type;
    _callManager!.isCaller = false;
    _callManager!.callState = CallState.connecting;
    await _ref!.read(callRepositoryProvider).acceptIncomingCallSession(
          _pendingCall!.id,
        );
    if (!replaceRingRoute) {
      await _dismissInAppRingOverlay();
    } else {
      _incomingRingOnStack = false;
    }
    return _openLiveKitForPendingCall(replaceCurrentRoute: replaceRingRoute);
  }

  void _scheduleCalleeRingingNotify(int sessionId) {
    Future<void>.delayed(_calleeRingingNotifyDelay, () async {
      if (_ref == null) return;
      if (_pendingCall?.id != sessionId) return;
      if (_pendingGroupId != null) return;
      try {
        final repo = _ref!.read(callRepositoryProvider);
        final payload = jsonEncode({
          'session_id': sessionId.toString(),
          'action': 'callee-ringing',
        });
        await repo.sendSignal(sessionId, payload);
      } catch (e) {
        debugPrint('callee-ringing notify failed: $e');
      }
    });
  }

  Future<void> _handleIncomingCall(Map<String, dynamic> callData) async {
    try {
      if (!_ensureHandlerReady()) {
        debugPrint('⚠️ Desktop incoming call: handler not ready');
        return;
      }

      if (_ref != null) {
        await reconcileLocalCallStateWithServer(_ref!.container);
      }

      final sessionId =
          _asInt(callData['session_id']) ?? _asInt(callData['call_id']);
      if (sessionId == null) {
        debugPrint('⚠️ Desktop CallInvite missing session_id');
        return;
      }
      if (callData['action'] != 'invite') return;

      if (_pendingCall != null && _pendingCall!.id == sessionId) {
        if (!_incomingRingOnStack) {
          unawaited(_pushCallScreenWhenReady());
        }
        return;
      }

      final caller = callData['caller'] is Map
          ? Map<String, dynamic>.from(callData['caller'] as Map)
          : null;
      final callerId = _asInt(caller?['id']) ?? 0;

      if (callerId > 0 && callerId == _currentUserId) {
        debugPrint('📞 Ignoring invite — we are the caller');
        return;
      }

      final calleeId = _asInt(callData['callee_id']);
      if (calleeId != null && calleeId != _currentUserId) {
        return;
      }

      final callType = callData['type'] as String? ?? 'voice';
      final callerName = caller?['name'] as String? ?? 'Unknown';
      final callerAvatar = caller?['avatar'] as String?;
      final conversationId = _asInt(callData['conversation_id']);
      final groupId = _asInt(callData['group_id']);

      final call = CallSession(
        id: sessionId,
        callerId: callerId,
        calleeId: calleeId ?? _currentUserId,
        conversationId: conversationId,
        groupId: groupId,
        type: callType,
        status: 'pending',
      );

      if (_pendingCall != null && _pendingCall!.id != sessionId) {
        final firstStillActive = _callManager!.hasActiveCall ||
            _callManager!.callState == CallState.ringing ||
            _callManager!.callState == CallState.connecting ||
            _callManager!.callState == CallState.connected;
        if (firstStillActive) {
          _waitingCall = call;
          _waitingCallerName = callerName;
          _waitingCallerAvatar = callerAvatar;
          _waitingConversationId = conversationId;
          _waitingGroupId = groupId;
          _showCallWaitingDialog();
          return;
        }
      }

      if (_callManager!.hasActiveCall) {
        _waitingCall = call;
        _waitingCallerName = callerName;
        _waitingCallerAvatar = callerAvatar;
        _waitingConversationId = conversationId;
        _waitingGroupId = groupId;
        _showCallWaitingDialog();
        return;
      }

      _pendingCall = call;
      _pendingCallerName = callerName;
      _pendingCallerAvatar = callerAvatar;
      _pendingConversationId = conversationId;
      _pendingGroupId = groupId;

      _callManager!.currentCall = call;
      _callManager!.callType = callType;
      _callManager!.isCaller = false;
      _callManager!.callState = CallState.ringing;

      if (groupId == null) {
        _scheduleCalleeRingingNotify(sessionId);
      }

      unawaited(DesktopWindowService.showMainWindow());

      final pushed = await _pushCallScreenWhenReady();
      if (!pushed) {
        _showOsNotificationFallback(sessionId, callerName);
      }
      _startIncomingCallUiFallback();
    } catch (e) {
      debugPrint('Error handling incoming call: $e');
    }
  }

  Future<void> _tearDownRemoteEndedCall(int sessionId) async {
    _incomingUiFallbackTimer?.cancel();
    await _dismissInAppRingOverlay();
    try {
      final lk = _ref?.read(liveKitCallServiceProvider);
      if (lk?.hasActiveCall == true) {
        await lk!.endCall();
      }
    } catch (_) {}
    await _callManager?.abandonCallLocally(sessionIdOverride: sessionId);
    _popCallUiIfOnStack();
    _pendingCall = null;
    _pendingCallerName = null;
    _pendingCallerAvatar = null;
    _pendingConversationId = null;
    _pendingGroupId = null;
    _liveKitOnStack = false;
    _incomingRingOnStack = false;
  }

  void _popCallUiIfOnStack() {
    if (!_incomingRingOnStack && !_liveKitOnStack) return;
    final navigator = rootNavigatorKey.currentState;
    if (navigator?.canPop() ?? false) {
      navigator!.pop();
    }
    _incomingRingOnStack = false;
    _liveKitOnStack = false;
  }

  void _handleCallCancelled(Map<String, dynamic> callData) {
    final sessionId =
        _asInt(callData['session_id']) ?? _asInt(callData['call_id']);
    if (sessionId == null) return;

    if (_waitingCall != null && _waitingCall!.id == sessionId) {
      _waitingCallTimer?.cancel();
      _waitingCallTimer = null;
      _waitingCall = null;
      _waitingCallerName = null;
      _waitingCallerAvatar = null;
      _waitingConversationId = null;
      _waitingGroupId = null;
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && Navigator.of(ctx).canPop()) {
        Navigator.of(ctx).pop();
      }
    }

    if (_pendingCall?.id != sessionId) return;

    debugPrint('📞 Incoming call $sessionId cancelled/ended');
    unawaited(_tearDownRemoteEndedCall(sessionId));
  }

  void _showCallWaitingDialog() {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || _waitingCall == null) return;

    _waitingCallTimer?.cancel();
    _waitingCallTimer = Timer(_waitingCallTimeout, () {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && Navigator.of(ctx).canPop()) {
        Navigator.of(ctx).pop();
      }
      _declineWaitingCall();
    });

    showDialog<void>(
      context: navContext,
      barrierDismissible: false,
      builder: (context) => CallWaitingDialog(
        callerName: _waitingCallerName ?? 'Unknown',
        callerAvatar: _waitingCallerAvatar,
        callType: _waitingCall!.type,
        onDecline: () {
          Navigator.of(context).pop();
          _declineWaitingCall();
        },
        onEndAndAnswer: () {
          Navigator.of(context).pop();
          unawaited(_endCurrentAndAnswerWaiting());
        },
      ),
    );
  }

  void _declineWaitingCall() {
    _waitingCallTimer?.cancel();
    _waitingCallTimer = null;
    if (_waitingCall == null) return;
    final waiting = _waitingCall!;
    final isGroupInvite =
        waiting.groupId != null || _waitingGroupId != null;
    if (!isGroupInvite) {
      final callRepo = _ref?.read(callRepositoryProvider);
      callRepo?.declineCall(waiting.id).catchError((_) {});
    } else {
      debugPrint(
        '📞 Dismissed group call invite ${waiting.id} locally (no server decline)',
      );
    }
    _waitingCall = null;
    _waitingCallerName = null;
    _waitingCallerAvatar = null;
    _waitingConversationId = null;
    _waitingGroupId = null;
  }

  Future<void> _endCurrentAndAnswerWaiting() async {
    _waitingCallTimer?.cancel();
    _waitingCallTimer = null;
    if (_waitingCall == null || _callManager == null || _ref == null) return;

    final waitingCall = _waitingCall!;
    final waitingCallerName = _waitingCallerName;
    final waitingCallerAvatar = _waitingCallerAvatar;
    final waitingConversationId = _waitingConversationId;
    final waitingGroupId = _waitingGroupId;

    _waitingCall = null;
    _waitingCallerName = null;
    _waitingCallerAvatar = null;
    _waitingConversationId = null;
    _waitingGroupId = null;

    await _callManager!.endCall();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    _pendingCall = waitingCall;
    _pendingCallerName = waitingCallerName;
    _pendingCallerAvatar = waitingCallerAvatar;
    _pendingConversationId = waitingConversationId;
    _pendingGroupId = waitingGroupId;

    _callManager!.currentCall = waitingCall;
    _callManager!.callType = waitingCall.type;
    _callManager!.isCaller = false;
    _callManager!.callState = CallState.connecting;

    await _openLiveKitForPendingCall(replaceCurrentRoute: true);
  }

  Future<bool> _openLiveKitForPendingCall({
    bool replaceCurrentRoute = false,
  }) async {
    if (_pendingCall == null || _ref == null) return false;
    if (_liveKitScreenRouteOpen || _liveKitOnStack) return true;
    if (_ref!.read(liveKitCallServiceProvider).hasActiveCall) return true;

    _liveKitScreenRouteOpen = true;
    try {
      final sessionId = _pendingCall!.id;
      final roomName = 'call_$sessionId';
      final pushed = await pushRouteOnRootNavigator(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => LiveKitCallScreen(
            roomName: roomName,
            callId: sessionId,
            videoEnabled: _pendingCall!.type == 'video',
            deferCredentialFetch: true,
            peerName: _pendingCallerName,
            peerAvatar: _pendingCallerAvatar,
            conversationId: _pendingConversationId,
            groupId: _pendingGroupId,
            isOutgoingCall: false,
          ),
        ),
        logLabel: 'LiveKitCallScreen(incoming)',
        replace: replaceCurrentRoute,
        onRoutePopped: () {
          if (_liveKitOnStack) _liveKitOnStack = false;
        },
      );
      if (pushed) {
        _incomingRingOnStack = false;
        _liveKitOnStack = true;
      }
      return pushed;
    } finally {
      _liveKitScreenRouteOpen = false;
    }
  }

  Future<bool> _pushLiveKitScreenWhenReady() async {
    if (_pendingCall == null || _ref == null) return false;
    return _openLiveKitForPendingCall(replaceCurrentRoute: _incomingRingOnStack);
  }

  bool _ensureHandlerReady() {
    if (_callManager != null) return true;
    if (_ref == null) return false;
    _callManager = _ref!.read(callManagerProvider);
    return _callManager != null;
  }

  Future<bool> _pushCallScreenWhenReady() async {
    if (_ringScreenRouteOpen ||
        _incomingRingOnStack ||
        _pendingCall == null ||
        _callManager == null) {
      return false;
    }
    _ringScreenRouteOpen = true;
    final call = _pendingCall!;
    try {
      final sessionId = call.id;
      final roomName = 'call_$sessionId';
      final pushed = await pushRouteOnRootNavigator(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => LiveKitCallScreen(
            roomName: roomName,
            callId: sessionId,
            videoEnabled: call.type == 'video',
            deferCredentialFetch: true,
            awaitIncomingAccept: true,
            peerName: _pendingCallerName,
            peerAvatar: _pendingCallerAvatar,
            conversationId: _pendingConversationId,
            groupId: _pendingGroupId,
            isOutgoingCall: false,
          ),
        ),
        logLabel: 'LiveKitCallScreen(incoming-ring)',
      );
      if (pushed) {
        _incomingRingOnStack = true;
        _liveKitOnStack = true;
      }
      return pushed;
    } finally {
      _ringScreenRouteOpen = false;
    }
  }

  void _showOsNotificationFallback(int sessionId, String callerName) {
    try {
      _notificationManager?.showNotification(
        title: 'Incoming call',
        body: '$callerName is calling you',
        data: <String, dynamic>{
          'type': 'incoming_call',
          'action': 'incoming_call',
          'session_id': sessionId,
        },
      );
    } catch (_) {}
  }

  void setContext(BuildContext context) {}
}

final incomingCallHandlerProvider = Provider<IncomingCallHandler>((ref) {
  final pusherService = ref.read(pusherServiceProvider);
  return IncomingCallHandler(pusherService);
});
