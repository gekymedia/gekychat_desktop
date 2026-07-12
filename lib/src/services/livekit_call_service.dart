import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;

/// Information about an active LiveKit call for overlay display.
class LiveKitCallInfo {
  final livekit.Room room;
  final String roomName;
  final String? displayName;
  final String? avatarUrl;
  final bool isVideoCall;
  final int? callId;
  final int? conversationId;
  final int? groupId;
  final Duration callDuration;
  final bool isMuted;
  final bool isVideoEnabled;

  const LiveKitCallInfo({
    required this.room,
    required this.roomName,
    this.displayName,
    this.avatarUrl,
    required this.isVideoCall,
    this.callId,
    this.conversationId,
    this.groupId,
    required this.callDuration,
    required this.isMuted,
    required this.isVideoEnabled,
  });

  LiveKitCallInfo copyWith({
    livekit.Room? room,
    String? roomName,
    String? displayName,
    String? avatarUrl,
    bool? isVideoCall,
    int? callId,
    int? conversationId,
    int? groupId,
    Duration? callDuration,
    bool? isMuted,
    bool? isVideoEnabled,
  }) {
    return LiveKitCallInfo(
      room: room ?? this.room,
      roomName: roomName ?? this.roomName,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVideoCall: isVideoCall ?? this.isVideoCall,
      callId: callId ?? this.callId,
      conversationId: conversationId ?? this.conversationId,
      groupId: groupId ?? this.groupId,
      callDuration: callDuration ?? this.callDuration,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
    );
  }

  bool get isConnected =>
      room.connectionState == livekit.ConnectionState.connected;

  int get participantCount => room.remoteParticipants.length + 1;

  bool get hasChat => conversationId != null || groupId != null;
}

/// Tracks minimized LiveKit calls for the floating desktop overlay.
class LiveKitCallService extends ChangeNotifier {
  LiveKitCallInfo? _activeCall;
  Timer? _durationTimer;
  Duration _currentDuration = Duration.zero;
  bool _hasConnectedPeer = false;
  bool _isMinimized = false;
  Timer? _disconnectEndTimer;

  LiveKitCallInfo? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  bool get isMinimized => _isMinimized;
  Duration get currentDuration => _currentDuration;

  void startCall({
    required livekit.Room room,
    required String roomName,
    String? displayName,
    String? avatarUrl,
    bool isVideoCall = false,
    int? callId,
    int? conversationId,
    int? groupId,
    bool isMuted = false,
    bool isVideoEnabled = false,
  }) {
    _currentDuration = Duration.zero;
    _hasConnectedPeer = room.remoteParticipants.isNotEmpty;
    _isMinimized = false;
    _disconnectEndTimer?.cancel();
    _disconnectEndTimer = null;
    _activeCall = LiveKitCallInfo(
      room: room,
      roomName: roomName,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isVideoCall: isVideoCall,
      callId: callId,
      conversationId: conversationId,
      groupId: groupId,
      callDuration: Duration.zero,
      isMuted: isMuted,
      isVideoEnabled: isVideoEnabled,
    );

    if (_hasConnectedPeer) {
      _startDurationTimer();
    }

    room.addListener(_onRoomChanged);
    notifyListeners();
  }

  void _onRoomChanged() {
    if (_activeCall == null) return;

    final room = _activeCall!.room;
    final cs = room.connectionState;

    if (cs == livekit.ConnectionState.connected ||
        cs == livekit.ConnectionState.reconnecting ||
        cs == livekit.ConnectionState.connecting) {
      _disconnectEndTimer?.cancel();
      _disconnectEndTimer = null;
    }

    if (cs == livekit.ConnectionState.disconnected) {
      _disconnectEndTimer?.cancel();
      final delay = _hasConnectedPeer
          ? const Duration(seconds: 12)
          : const Duration(milliseconds: 600);
      _disconnectEndTimer = Timer(delay, () {
        _disconnectEndTimer = null;
        if (_activeCall == null) return;
        if (_activeCall!.room.connectionState ==
            livekit.ConnectionState.disconnected) {
          unawaited(endCall());
        }
      });
      notifyListeners();
      return;
    }

    if (!_hasConnectedPeer && room.remoteParticipants.isNotEmpty) {
      _hasConnectedPeer = true;
      _startDurationTimer();
    }

    notifyListeners();
  }

  void updateMuteState(bool isMuted) {
    if (_activeCall == null) return;
    _activeCall = _activeCall!.copyWith(isMuted: isMuted);
    notifyListeners();
  }

  void updateVideoState(bool isVideoEnabled) {
    if (_activeCall == null) return;
    _activeCall = _activeCall!.copyWith(isVideoEnabled: isVideoEnabled);
    notifyListeners();
  }

  void minimizeCall() {
    if (_activeCall == null) return;
    _isMinimized = true;
    notifyListeners();
  }

  void maximizeCall() {
    _isMinimized = false;
    notifyListeners();
  }

  /// Disconnects LiveKit only; API hang-up is handled by the call screen / overlay.
  Future<void> endCall({bool disposeRoom = true}) async {
    _disconnectEndTimer?.cancel();
    _disconnectEndTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;

    if (_activeCall != null) {
      _activeCall!.room.removeListener(_onRoomChanged);
      if (disposeRoom) {
        try {
          await _activeCall!.room
              .disconnect()
              .timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('LiveKitCallService: disconnect ignored: $e');
        }
        try {
          _activeCall!.room.dispose();
        } catch (_) {}
      }
    }

    _activeCall = null;
    _isMinimized = false;
    _hasConnectedPeer = false;
    _currentDuration = Duration.zero;
    notifyListeners();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _currentDuration += const Duration(seconds: 1);
      if (_activeCall != null) {
        _activeCall = _activeCall!.copyWith(callDuration: _currentDuration);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disconnectEndTimer?.cancel();
    _durationTimer?.cancel();
    if (_activeCall != null) {
      _activeCall!.room.removeListener(_onRoomChanged);
    }
    super.dispose();
  }
}

final liveKitCallServiceProvider =
    ChangeNotifierProvider<LiveKitCallService>((ref) {
  return LiveKitCallService();
});
