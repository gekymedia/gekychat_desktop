// lib/src/features/calls/livekit_call_screen.dart
//
// Desktop LiveKit call screen.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'call_duration_format.dart';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc show DesktopCapturerSource;
import 'package:livekit_client/livekit_client.dart';

import '../../services/livekit_call_service.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../widgets/desktop_microphone_permission_dialog.dart';
import '../../widgets/desktop_voice_permission.dart';
import 'call_manager.dart';
import 'call_rating_sheet.dart';
import 'livekit_ice_config.dart';
import 'providers.dart';
import 'incoming_call_handler.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/storage_url.dart';

class LiveKitCallScreen extends ConsumerStatefulWidget {
  final String? url;
  final String? token;
  final String roomName;
  final bool videoEnabled;
  final int callId;
  final String? peerName;
  final String? peerAvatar;
  final int? groupId;
  final int? conversationId;
  final bool isOutgoingCall;
  final Room? existingRoom;
  final bool isRestoredFromOverlay;
  final bool awaitIncomingAccept;
  final bool deferCredentialFetch;

  const LiveKitCallScreen({
    super.key,
    this.url,
    this.token,
    required this.roomName,
    required this.callId,
    this.videoEnabled = false,
    this.peerName,
    this.peerAvatar,
    this.groupId,
    this.conversationId,
    this.isOutgoingCall = false,
    this.existingRoom,
    this.isRestoredFromOverlay = false,
    this.awaitIncomingAccept = false,
    this.deferCredentialFetch = false,
  });

  @override
  ConsumerState<LiveKitCallScreen> createState() => _LiveKitCallScreenState();
}

class _LiveKitCallScreenState extends ConsumerState<LiveKitCallScreen> {
  late final Room _room;
  late final EventsListener<RoomEvent> _roomListener;
  late final LiveKitCallService _liveKitService;
  late final CallManager _callManager;
  late final bool _ownsRoom;
  bool _connecting = true;
  bool _muted = false;
  bool _videoOff = true;
  bool _screenSharing = false;
  bool _isEnding = false;
  bool _isMinimizing = false;
  bool _noAnswer = false;
  bool _awaitingIncomingAccept = false;
  bool _isAcceptingIncoming = false;
  String? _videoUpgradeRequester;
  bool _hasRequestedVideoUpgrade = false;
  void Function(CallState)? _callManagerStateBeforeIncoming;
  String? _error;
  MediaDevice? _selectedAudioOutput;
  DateTime? _connectedAt;
  Timer? _durationTicker;
  DateTime? _mediaRenegotiationGraceUntil;
  Timer? _remoteLeftHangupTimer;

  bool get _hasRemoteParticipants => _room.remoteParticipants.isNotEmpty;

  bool get _inMediaRenegotiationGrace {
    final until = _mediaRenegotiationGraceUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _armMediaRenegotiationGrace([
    Duration grace = const Duration(seconds: 12),
  ]) {
    _mediaRenegotiationGraceUntil = DateTime.now().add(grace);
  }

  bool get _useParticipantGrid =>
      widget.groupId != null && _room.remoteParticipants.length > 1;

  bool _shouldLeaveGroupCallWithoutEnding() =>
      widget.groupId != null && _room.remoteParticipants.isNotEmpty;

  bool get _canUpgradeToVideo =>
      _hasRemoteParticipants && widget.groupId == null;

  String? get _safePeerAvatar => resolveAvatarUrl(widget.peerAvatar);

  bool get _roomIsLive {
    final cs = _room.connectionState;
    return cs == ConnectionState.connecting ||
        cs == ConnectionState.connected ||
        cs == ConnectionState.reconnecting;
  }

  @override
  void initState() {
    super.initState();
    _liveKitService = ref.read(liveKitCallServiceProvider);
    _callManager = ref.read(callManagerProvider);
    _videoOff = !widget.videoEnabled;
    _awaitingIncomingAccept = widget.awaitIncomingAccept;
    if (_awaitingIncomingAccept) {
      _connecting = false;
    }
    _ownsRoom = widget.existingRoom == null;
    _room = widget.existingRoom ??
        Room(
          roomOptions: const RoomOptions(
            adaptiveStream: false,
            dynacast: true,
            defaultVideoPublishOptions: VideoPublishOptions(
              simulcast: true,
            ),
          ),
        );
    _room.addListener(_onRoomChanged);
    _roomListener = _room.createListener()
      ..on<RoomConnectedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<RoomReconnectingEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<RoomReconnectedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<TrackSubscribedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<TrackUnsubscribedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<TrackPublishedEvent>((event) {
        final source = event.publication.source;
        if (source == TrackSource.screenShareVideo ||
            source == TrackSource.camera) {
          _armMediaRenegotiationGrace();
        }
        if (mounted) setState(() {});
      })
      ..on<LocalTrackPublishedEvent>((event) {
        final source = event.publication.source;
        if (source == TrackSource.screenShareVideo ||
            source == TrackSource.camera) {
          _armMediaRenegotiationGrace();
        }
        if (mounted) setState(() {});
      })
      ..on<ParticipantConnectedEvent>((_) {
        _remoteLeftHangupTimer?.cancel();
        _remoteLeftHangupTimer = null;
        if (mounted) setState(() {});
      })
      ..on<DataReceivedEvent>(_handleDataMessage);

      if (widget.isRestoredFromOverlay) {
      _connecting = false;
      final service = ref.read(liveKitCallServiceProvider);
      final active = service.activeCall;
      if (active != null) {
        _muted = active.isMuted;
        _videoOff = !active.isVideoEnabled;
      }
      if (_room.remoteParticipants.isNotEmpty) {
        final elapsed = service.currentDuration;
        _connectedAt = DateTime.now().subtract(elapsed);
        _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    } else if (_awaitingIncomingAccept) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _callManagerStateBeforeIncoming = _callManager.onCallStateChanged;
        _callManager.onCallStateChanged = _onIncomingAwaitCallStateChanged;
      });
    } else {
      _connect();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cm = ref.read(callManagerProvider);
      cm.onCallStateChanged = _onManagerCallStateChanged;
      cm.onCallSignal = _onCallSignalPayload;
      if (widget.isOutgoingCall || widget.groupId == null) {
        unawaited(cm.ensureSignalingSubscribed());
      }
      if (widget.isOutgoingCall) {
        cm.onNoAnswerUi = () {
          if (!mounted || _isEnding) return;
          setState(() => _noAnswer = true);
        };
        cm.onError = (message) {
          if (!mounted || _isEnding) return;
                    context.showInfoToast(message);          final t = message.trim().toLowerCase();
          if (t == 'call declined' ||
              t == 'no answer' ||
              t == 'the call ended' ||
              t == 'call ended' ||
              t == 'call ended.' ||
              (t.contains('couldn') && t.contains('take the call'))) {
            unawaited(_handleEndedByManager());
          }
        };
      } else if (widget.groupId != null) {
        cm.onParticipantLeft = (_) {
          if (!mounted) return;
                    context.showInfoToast('A participant left the call');          setState(() {});
        };
      }
    });
  }

  void _registerWithOverlayService() {
    ref.read(liveKitCallServiceProvider).startCall(
          room: _room,
          roomName: widget.roomName,
          displayName: widget.peerName,
          avatarUrl: _safePeerAvatar,
          isVideoCall: widget.videoEnabled || !_videoOff,
          callId: widget.callId,
          conversationId: widget.conversationId,
          groupId: widget.groupId,
          isMuted: _muted,
          isVideoEnabled: !_videoOff,
        );
  }

  void _onManagerCallStateChanged(CallState state) {
    if (!mounted || _isEnding) return;
    if (state == CallState.ended) {
      _handleEndedByManager();
    }
  }

  void _safePopRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    });
  }

  /// Disconnect without throwing — cancelled/never-connected rooms often hang.
  Future<void> _safeDisconnectRoom({bool disposeOwned = true}) async {
    if (_roomIsLive) {
      try {
        await _room.disconnect().timeout(const Duration(milliseconds: 800));
      } catch (e) {
        debugPrint('LiveKitCallScreen: disconnect ignored: $e');
      }
    }
    if (disposeOwned && _ownsRoom) {
      try {
        _room.dispose();
      } catch (_) {}
    }
  }

  Future<void> _handleEndedByManager() async {
    if (_isEnding) return;
    _isEnding = true;
    _durationTicker?.cancel();
    // Pop immediately — don't freeze the UI on WebRTC teardown.
    _safePopRoute();
    try {
      await ref
          .read(liveKitCallServiceProvider)
          .endCall(disposeRoom: false);
    } catch (e) {
      debugPrint('LiveKitCallScreen: endCall overlay clear: $e');
    }
    unawaited(_safeDisconnectRoom());
    try {
      final cm = ref.read(callManagerProvider);
      cm.onCallStateChanged = null;
      cm.onNoAnswerUi = null;
      cm.onParticipantLeft = null;
      if (widget.isOutgoingCall) {
        cm.onError = null;
      }
    } catch (_) {}
  }

  void _onRoomChanged() {
    if (_room.remoteParticipants.isNotEmpty) {
      _remoteLeftHangupTimer?.cancel();
      _remoteLeftHangupTimer = null;
      ref.read(callManagerProvider).notifyRemoteParticipantJoined();
      _connectedAt ??= DateTime.now();
      _durationTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (widget.groupId == null &&
        _connectedAt != null &&
        !_isEnding &&
        !_connecting) {
      if (_inMediaRenegotiationGrace ||
          _room.connectionState == ConnectionState.reconnecting) {
        if (mounted) setState(() {});
        return;
      }
      // 1:1 — peer can briefly disappear during ICE renegotiation (screen share / video).
      _remoteLeftHangupTimer?.cancel();
      _remoteLeftHangupTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted || _isEnding) return;
        if (_inMediaRenegotiationGrace ||
            _room.connectionState == ConnectionState.reconnecting) {
          return;
        }
        if (_room.remoteParticipants.isEmpty) {
          unawaited(_hangUp());
        }
      });
      if (mounted) setState(() {});
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    if (_isEnding || !mounted) return;

    final micOk = await ensureDesktopMicrophoneForCall(context);
    if (!mounted || _isEnding) return;
    if (!micOk) {
      setState(() {
        _connecting = false;
        _error = 'Microphone permission is required for calls';
      });
      return;
    }

    var url = widget.url;
    var token = widget.token;
    if ((url == null || token == null) && widget.deferCredentialFetch) {
      try {
        final liveKitTokenService = ref.read(liveKitTokenServiceProvider);
        final name = ref.read(currentUserProvider).valueOrNull?.name.trim();
        final displayName =
            (name != null && name.isNotEmpty) ? name : 'User';
        final tokenResult = await liveKitTokenService.fetchToken(
          roomName: widget.roomName,
          displayName: displayName,
        );
        if (_isEnding || !mounted) return;
        url = tokenResult.url;
        token = tokenResult.token;
      } catch (e) {
        if (mounted && !_isEnding) {
          setState(() {
            _connecting = false;
            _error = 'Could not connect: $e';
          });
        }
        return;
      }
    }
    if (_isEnding || !mounted) return;
    if (url == null || token == null) {
      setState(() {
        _connecting = false;
        _error = 'Missing LiveKit credentials';
      });
      return;
    }

    try {
      final rtcConfiguration = await fetchLiveKitRtcConfiguration(
        ref.read(apiServiceProvider),
      );
      if (!mounted || _isEnding) return;
      await _room.connect(
        url,
        token,
        connectOptions: ConnectOptions(
          rtcConfiguration: rtcConfiguration,
        ),
        fastConnectOptions: FastConnectOptions(
          microphone: const TrackOption(enabled: true),
          camera: TrackOption(enabled: widget.videoEnabled),
        ),
      );
      if (!mounted || _isEnding) {
        unawaited(_safeDisconnectRoom());
        return;
      }
      setState(() {
        _connecting = false;
        _error = null;
      });
      final lp = _room.localParticipant;
      try {
        await lp?.setMicrophoneEnabled(true);
      } catch (e) {
        if (!mounted || _isEnding) return;
        if (desktopMicrophoneNotFoundError(e)) {
          await showDesktopMicrophoneNotFoundDialog(
            context,
            purpose: DesktopMicrophonePurpose.call,
          );
        } else if (mounted) {
          context.showErrorToast('Could not enable microphone');
        }
      }
      if (widget.videoEnabled && !_videoOff) {
        await lp?.setCameraEnabled(true);
      }
      if (!mounted || _isEnding) {
        unawaited(_safeDisconnectRoom());
        return;
      }
      _registerWithOverlayService();
      try {
        ref.read(callManagerProvider).notifyLiveKitRoomConnected();
      } catch (_) {}
      if (!widget.isOutgoingCall) {
        await ref
            .read(callRepositoryProvider)
            .acceptIncomingCallSession(widget.callId);
        if (!mounted || _isEnding) return;
        await _notifyLiveKitJoinedSignal();
      }
    } catch (e) {
      if (mounted && !_isEnding) {
        setState(() {
          _connecting = false;
          _error = friendlyLiveKitConnectError(e);
        });
      }
    }
  }

  void _onIncomingAwaitCallStateChanged(CallState state) {
    _callManagerStateBeforeIncoming?.call(state);
    if (!mounted) return;
    if (state == CallState.ended) {
      _isEnding = true;
      _safePopRoute();
    }
  }

  Future<void> _acceptIncomingCall() async {
    if (_isAcceptingIncoming || !_awaitingIncomingAccept) return;
    setState(() => _isAcceptingIncoming = true);
    final handler = ref.read(incomingCallHandlerProvider);
    final ok = await handler.acceptPendingCallInPlace();
    if (!mounted) return;
    if (!ok) {
      setState(() => _isAcceptingIncoming = false);
            context.showErrorToast('Could not join call. Please try again.');      return;
    }
    setState(() {
      _awaitingIncomingAccept = false;
      _connecting = true;
      _isAcceptingIncoming = false;
    });
    if (_callManager.onCallStateChanged == _onIncomingAwaitCallStateChanged) {
      _callManager.onCallStateChanged = _onManagerCallStateChanged;
    }
    _callManagerStateBeforeIncoming = null;
    await _connect();
  }

  Future<void> _declineIncomingCall() async {
    final sessionId = widget.callId;
    if (sessionId > 0) {
      await ref.read(incomingCallHandlerProvider).declinePendingIncomingCall(
            sessionId,
            groupId: widget.groupId,
          );
    } else {
      await _callManager.declineCall(
            sessionIdOverride: sessionId,
            groupId: widget.groupId,
          );
    }
    if (mounted) {
      _safePopRoute();
    }
  }

  Widget _buildIncomingAcceptOverlay() {
    final name = widget.peerName ?? 'Unknown';
    final avatarUrl = _safePeerAvatar;
    return ColoredBox(
      color: const Color(0xFF0B141A),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            CircleAvatar(
              radius: 90,
              backgroundColor: Colors.grey[800],
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 67,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.videoEnabled
                  ? 'Incoming video call'
                  : 'Incoming voice call',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(flex: 3),
            if (_isAcceptingIncoming)
              const CircularProgressIndicator(color: Colors.white)
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 52),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _incomingActionButton(
                      icon: Icons.call_end,
                      label: 'Decline',
                      color: Colors.red,
                      onTap: () => unawaited(_declineIncomingCall()),
                    ),
                    _incomingActionButton(
                      icon: widget.videoEnabled ? Icons.videocam : Icons.call,
                      label: 'Accept',
                      color: Colors.green,
                      onTap: () => unawaited(_acceptIncomingCall()),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _incomingActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Future<void> _notifyLiveKitJoinedSignal() async {
    if (widget.groupId != null) return;
    try {
      final payload = jsonEncode({
        'session_id': widget.callId.toString(),
        'type': 'livekit-joined',
      });
      await ref.read(callRepositoryProvider).sendSignal(widget.callId, payload);
    } catch (e) {
      debugPrint('LiveKitCallScreen: livekit-joined notify failed: $e');
    }
  }

  void _minimizeCall() {
    if (_isEnding) return;
    _isMinimizing = true;
    if (ref.read(liveKitCallServiceProvider).activeCall == null) {
      _registerWithOverlayService();
    }
    ref.read(liveKitCallServiceProvider).updateMuteState(_muted);
    ref.read(liveKitCallServiceProvider).updateVideoState(!_videoOff);
    ref.read(liveKitCallServiceProvider).minimizeCall();
    _safePopRoute();
  }

  int? _callDurationSeconds() {
    final start = _connectedAt;
    if (start == null) return null;
    return DateTime.now().difference(start).inSeconds;
  }

  void _maybePromptRating() {
    if (!_hasRemoteParticipants || _connectedAt == null) return;
    scheduleCallRatingPrompt(
      repository: ref.read(callRepositoryProvider),
      sessionId: widget.callId,
      callType: widget.videoEnabled || !_videoOff ? 'video' : 'voice',
      durationSeconds: _callDurationSeconds(),
    );
  }

  @override
  void dispose() {
    _durationTicker?.cancel();
    _remoteLeftHangupTimer?.cancel();
    if (_awaitingIncomingAccept &&
        _callManager.onCallStateChanged == _onIncomingAwaitCallStateChanged) {
      _callManager.onCallStateChanged = _callManagerStateBeforeIncoming;
    }
    if (_callManager.onCallStateChanged == _onManagerCallStateChanged) {
      _callManager.onCallStateChanged = null;
    }
    if (_callManager.onCallSignal == _onCallSignalPayload) {
      _callManager.onCallSignal = null;
    }
    _callManager.onNoAnswerUi = null;
    _callManager.onParticipantLeft = null;
    if (widget.isOutgoingCall) {
      _callManager.onError = null;
    }
    _roomListener.dispose();
    _room.removeListener(_onRoomChanged);

    final stillActiveInOverlay =
        _isMinimizing && _liveKitService.activeCall?.room == _room;

    if (!stillActiveInOverlay && !_isEnding) {
      if (_ownsRoom) {
        unawaited(() async {
          try {
            if (_roomIsLive) {
              await _room.disconnect().timeout(const Duration(milliseconds: 800));
            }
          } catch (_) {}
          try {
            _room.dispose();
          } catch (_) {}
        }());
      }
      if (_liveKitService.activeCall?.room == _room) {
        unawaited(_liveKitService.endCall(disposeRoom: false));
      }
      _callManager.notifyLiveKitRoomDisconnected();
    }
    super.dispose();
  }

  Future<void> _toggleMute() async {
    final lp = _room.localParticipant;
    if (lp == null) {
      if (mounted) {
        context.showWarningToast('Microphone not ready yet');
      }
      return;
    }
    final nextMuted = !_muted;
    try {
      await lp.setMicrophoneEnabled(!nextMuted);
      if (!mounted) return;
      setState(() => _muted = nextMuted);
      ref.read(liveKitCallServiceProvider).updateMuteState(_muted);
    } catch (e) {
      if (!mounted) return;
      if (desktopMicrophoneNotFoundError(e)) {
        await showDesktopMicrophoneNotFoundDialog(
          context,
          purpose: DesktopMicrophonePurpose.call,
        );
      } else {
        context.showErrorToast('Could not toggle mute');
      }
    }
  }

  Future<void> _showAudioOutputPicker() async {
    try {
      final devices = await Hardware.instance.audioOutputs();
      if (!mounted) return;
      if (devices.isEmpty) {
        context.showInfoToast('No audio output devices found');
        return;
      }
      final currentId = _selectedAudioOutput?.deviceId ??
          _room.selectedAudioOutputDeviceId;
      final picked = await showDialog<MediaDevice>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1F2C34),
            title: const Text(
              'Audio output',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 360,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final selected = device.deviceId == currentId;
                  final label = device.label.trim().isEmpty
                      ? 'Audio device ${index + 1}'
                      : device.label.trim();
                  return ListTile(
                    leading: Icon(
                      Icons.volume_up_rounded,
                      color: selected ? Colors.greenAccent : Colors.white70,
                    ),
                    title: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check, color: Colors.greenAccent)
                        : null,
                    onTap: () => Navigator.pop(ctx, device),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
      if (picked == null || !mounted) return;
      await _room.setAudioOutputDevice(picked);
      if (!mounted) return;
      setState(() => _selectedAudioOutput = picked);
      context.showSuccessToast('Audio output updated');
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Could not change audio output');
      }
    }
  }

  void _onCallSignalPayload(Map<String, dynamic> payload) {
    final type = payload['type']?.toString();
    if (type != 'video-upgrade-request' &&
        type != 'video-upgrade-accepted' &&
        type != 'video-upgrade-declined') {
      return;
    }
    final sid = int.tryParse(payload['session_id']?.toString() ?? '');
    if (sid != null && sid != widget.callId) return;
    if (!mounted) return;

    if (type == 'video-upgrade-request') {
      final name = payload['requester_name']?.toString();
      if (_videoUpgradeRequester != null) return;
      setState(() => _videoUpgradeRequester = (name != null && name.isNotEmpty)
          ? name
          : 'Someone');
    } else if (type == 'video-upgrade-accepted') {
      if (_hasRequestedVideoUpgrade) {
        unawaited(_enableCameraAfterVideoUpgradeAccepted());
      }
    } else if (type == 'video-upgrade-declined') {
      if (_hasRequestedVideoUpgrade) {
        context.showWarningToast('Video call declined');
        setState(() => _hasRequestedVideoUpgrade = false);
      }
    }
  }

  void _handleDataMessage(DataReceivedEvent event) {
    try {
      final data = String.fromCharCodes(event.data);
      if (data.startsWith('VIDEO_UPGRADE_REQUEST:')) {
        final senderName = event.participant?.name ??
            event.participant?.identity ??
            'Someone';
        if (!mounted || _videoUpgradeRequester != null) return;
        setState(() => _videoUpgradeRequester = senderName);
      } else if (data == 'VIDEO_UPGRADE_ACCEPTED') {
        if (mounted && _hasRequestedVideoUpgrade) {
          unawaited(_enableCameraAfterVideoUpgradeAccepted());
        }
      } else if (data == 'VIDEO_UPGRADE_DECLINED') {
        if (mounted && _hasRequestedVideoUpgrade) {
          context.showWarningToast(
            '${event.participant?.name ?? 'User'} declined video call',
          );
          setState(() => _hasRequestedVideoUpgrade = false);
        }
      }
    } catch (e) {
      debugPrint('LiveKitCallScreen: data message error: $e');
    }
  }

  Future<void> _sendVideoUpgradeSignal(String type, {String? requesterName}) async {
    try {
      final map = <String, dynamic>{
        'type': type,
        'session_id': widget.callId.toString(),
      };
      if (requesterName != null && requesterName.isNotEmpty) {
        map['requester_name'] = requesterName;
      }
      await ref.read(callRepositoryProvider).sendSignal(
            widget.callId,
            jsonEncode(map),
          );
    } catch (e) {
      debugPrint('LiveKitCallScreen: $type signal failed: $e');
    }
  }

  Future<bool> _confirmSwitchToVideo({String? requesterName}) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1F2C34),
            title: const Text(
              'Switch to video call?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              requesterName != null
                  ? '$requesterName wants to switch to video.'
                  : 'Ask the other person to switch this voice call to video?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Switch'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _requestVideoUpgrade() async {
    final lp = _room.localParticipant;
    if (lp == null) return;
    try {
      setState(() => _hasRequestedVideoUpgrade = true);
      // Prefer CallSignal — LiveKit data often times out on Windows peers.
      await _sendVideoUpgradeSignal(
        'video-upgrade-request',
        requesterName: lp.name.isNotEmpty ? lp.name : 'Someone',
      );
      try {
        final data = 'VIDEO_UPGRADE_REQUEST:${lp.name}';
        await lp
            .publishData(
              Uint8List.fromList(data.codeUnits),
              reliable: true,
            )
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('LiveKitCallScreen: publishData ignored: $e');
      }
      if (mounted) {
        context.showInfoToast('Video call request sent');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasRequestedVideoUpgrade = false);
        context.showErrorToast('Failed to request video: $e');
      }
    }
  }

  Future<void> _enableCameraAfterVideoUpgradeAccepted() async {
    final lp = _room.localParticipant;
    if (lp == null) return;
    try {
      _armMediaRenegotiationGrace();
      await lp.setCameraEnabled(true);
      if (!mounted) return;
      setState(() {
        _videoOff = false;
        _hasRequestedVideoUpgrade = false;
      });
      ref.read(liveKitCallServiceProvider).updateVideoState(true);
      context.showSuccessToast('Switched to video call');
    } catch (e) {
      if (mounted) {
        setState(() => _hasRequestedVideoUpgrade = false);
        context.showErrorToast('Failed to enable camera: $e');
      }
    }
  }

  Future<void> _acceptVideoUpgrade() async {
    final lp = _room.localParticipant;
    if (lp == null) return;
    try {
      _armMediaRenegotiationGrace();
      await lp.setCameraEnabled(true);
      if (mounted) {
        setState(() {
          _videoOff = false;
          _videoUpgradeRequester = null;
        });
      }
      ref.read(liveKitCallServiceProvider).updateVideoState(true);
      await _sendVideoUpgradeSignal('video-upgrade-accepted');
      try {
        await lp
            .publishData(
              Uint8List.fromList('VIDEO_UPGRADE_ACCEPTED'.codeUnits),
              reliable: true,
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to enable camera: $e');
      }
    }
  }

  Future<void> _declineVideoUpgrade() async {
    final lp = _room.localParticipant;
    if (lp == null) return;
    try {
      await _sendVideoUpgradeSignal('video-upgrade-declined');
      try {
        await lp
            .publishData(
              Uint8List.fromList('VIDEO_UPGRADE_DECLINED'.codeUnits),
              reliable: true,
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (mounted) {
        setState(() => _videoUpgradeRequester = null);
      }
    } catch (e) {
      debugPrint('LiveKitCallScreen: decline video upgrade: $e');
      if (mounted) {
        setState(() => _videoUpgradeRequester = null);
      }
    }
  }

  Future<void> _toggleVideo() async {
    final lp = _room.localParticipant;
    if (lp == null) return;

    // Voice call → request peer consent before turning camera on (matches iOS).
    if (_videoOff &&
        !widget.videoEnabled &&
        !_hasRequestedVideoUpgrade &&
        widget.groupId == null) {
      final confirm = await _confirmSwitchToVideo();
      if (!confirm || !mounted) return;
      await _requestVideoUpgrade();
      return;
    }

    if (_videoOff) {
      _armMediaRenegotiationGrace();
      await lp.setCameraEnabled(true);
    } else {
      await lp.setCameraEnabled(false);
      _hasRequestedVideoUpgrade = false;
    }
    if (!mounted) return;
    setState(() => _videoOff = !_videoOff);
    ref.read(liveKitCallServiceProvider).updateVideoState(!_videoOff);
  }

  Widget _buildVideoUpgradeBanner() {
    final requester = _videoUpgradeRequester ?? 'Someone';
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Video call request',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$requester wants to switch to video',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => unawaited(_declineVideoUpgrade()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => unawaited(_acceptVideoUpgrade()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1565C0),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleScreenShare() async {
    final lp = _room.localParticipant;
    if (lp == null) return;
    try {
      if (_screenSharing) {
        _armMediaRenegotiationGrace();
        await lp.setScreenShareEnabled(false);
        setState(() => _screenSharing = false);
        return;
      }

      if (lkPlatformIsDesktop()) {
        final source = await showDialog<rtc.DesktopCapturerSource>(
          context: context,
          builder: (context) => ScreenSelectDialog(),
        );
        if (source == null || !mounted) return;

        _armMediaRenegotiationGrace();
        final track = await LocalVideoTrack.createScreenShareTrack(
          ScreenShareCaptureOptions(
            sourceId: source.id,
            maxFrameRate: 15.0,
          ),
        );
        await lp.publishVideoTrack(
          track,
          publishOptions: const VideoPublishOptions(simulcast: false),
        );
        if (mounted) setState(() => _screenSharing = true);
        return;
      }

      _armMediaRenegotiationGrace();
      await lp.setScreenShareEnabled(true);
      setState(() => _screenSharing = !_screenSharing);
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Screen share failed: $e');      }
    }
  }

  Future<void> _hangUp() async {
    if (_isEnding) return;
    _isEnding = true;
    _durationTicker?.cancel();
    final hadPeer = _hasRemoteParticipants;
    if (widget.isOutgoingCall) {
      try {
        final cm = ref.read(callManagerProvider);
        cm.onCallStateChanged = null;
        cm.onNoAnswerUi = null;
        cm.onError = null;
      } catch (_) {}
    }
    // Leave the call UI immediately; finish teardown in the background.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) nav.pop();
        if (hadPeer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybePromptRating();
          });
        }
      });
    } else if (hadPeer) {
      _maybePromptRating();
    }
    try {
      await ref
          .read(liveKitCallServiceProvider)
          .endCall(disposeRoom: false);
    } catch (e) {
      debugPrint('LiveKitCallScreen: hangUp endCall: $e');
    }
    unawaited(_safeDisconnectRoom());
    final cm = ref.read(callManagerProvider);
    if (_shouldLeaveGroupCallWithoutEnding()) {
      unawaited(cm.leaveCall(sessionIdOverride: widget.callId));
    } else {
      unawaited(cm.endCall(sessionIdOverride: widget.callId));
    }
  }

  String _statusText() {
    if (_noAnswer) return 'No answer';
    if (_error != null) return 'Connection failed';

    final cs = _room.connectionState;
    final connectedOnce = _connectedAt != null;

    // After media is up, brief ICE/reconnect blips must not flash "Connecting…".
    if (connectedOnce || cs == ConnectionState.connected) {
      if (cs == ConnectionState.reconnecting ||
          cs == ConnectionState.connecting ||
          cs == ConnectionState.disconnected) {
        if (_hasRemoteParticipants && _connectedAt != null) {
          return formatCallDurationHms(
            DateTime.now().difference(_connectedAt!),
          );
        }
        return 'Reconnecting…';
      }
      if (!_hasRemoteParticipants) {
        return widget.isOutgoingCall ? 'Calling…' : 'Waiting…';
      }
      final remotes = _room.remoteParticipants.values.toList();
      if (remotes.isNotEmpty && _remoteVideoPending(remotes.first)) {
        // Keep duration visible once established — video attach is not a new connect.
        if (_connectedAt != null) {
          return formatCallDurationHms(
            DateTime.now().difference(_connectedAt!),
          );
        }
        return 'Connecting video…';
      }
      if (_connectedAt != null) {
        return formatCallDurationHms(DateTime.now().difference(_connectedAt!));
      }
      return 'Connected';
    }

    if (cs == ConnectionState.reconnecting) {
      return 'Reconnecting…';
    }
    if (_connecting) {
      return widget.isOutgoingCall ? 'Calling…' : 'Connecting…';
    }
    if (!_hasRemoteParticipants) {
      return widget.isOutgoingCall ? 'Calling…' : 'Waiting…';
    }
    final remotes = _room.remoteParticipants.values.toList();
    if (remotes.isNotEmpty && _remoteVideoPending(remotes.first)) {
      return 'Connecting video…';
    }
    return 'Connected';
  }

  Future<void> _retryConnect() async {
    if (_isEnding || _connecting) return;
    setState(() {
      _error = null;
      _connecting = true;
    });
    await _connect();
  }

  bool _remoteVideoPending(Participant participant) {
    for (final source in [TrackSource.screenShareVideo, TrackSource.camera]) {
      final pub = participant.getTrackPublicationBySource(source);
      if (pub != null && !pub.muted && pub.track == null) {
        return true;
      }
    }
    return false;
  }

  VideoTrack? _videoTrackFor(Participant participant, TrackSource source) {
    final pub = participant.getTrackPublicationBySource(source);
    if (pub == null) return null;
    if (pub.muted) return null;
    final track = pub.track;
    return track is VideoTrack ? track : null;
  }

  VideoTrack? _primaryVideoFor(Participant participant) {
    return _videoTrackFor(participant, TrackSource.screenShareVideo) ??
        _videoTrackFor(participant, TrackSource.camera);
  }

  Widget _videoRenderer(VideoTrack track, {bool screenShare = false}) {
    return VideoTrackRenderer(
      track,
      fit: screenShare ? VideoViewFit.contain : VideoViewFit.cover,
    );
  }

  Widget _participantTile(Participant participant, {bool compact = false}) {
    final name = participant.name.isNotEmpty
        ? participant.name
        : (participant.identity.isNotEmpty ? participant.identity : 'Guest');
    final screenShare =
        _videoTrackFor(participant, TrackSource.screenShareVideo);
    final camera = _videoTrackFor(participant, TrackSource.camera);
    final video = screenShare ?? camera;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video != null)
            _videoRenderer(video, screenShare: screenShare != null)
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: compact ? 28 : 40,
                    backgroundColor: Colors.grey[800],
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 22 : 32,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 11 : 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantGrid() {
    final remotes = _room.remoteParticipants.values.toList();
    final tiles = <Widget>[
      ...remotes.map((p) => _participantTile(p)),
      if (_room.localParticipant != null)
        _participantTile(_room.localParticipant!, compact: false),
    ];

    final count = tiles.length;
    final crossAxisCount = count <= 2 ? 1 : (count <= 4 ? 2 : 3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 56, 12, 120),
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: crossAxisCount == 1 ? 16 / 9 : 1,
        children: tiles,
      ),
    );
  }

  Widget _buildSingleParticipantView() {
    final remotes = _room.remoteParticipants.values.toList();
    final remote = remotes.isNotEmpty ? remotes.first : null;
    final remoteVideo =
        remote != null ? _primaryVideoFor(remote) : null;
    final remoteScreenShare = remote != null
        ? _videoTrackFor(remote, TrackSource.screenShareVideo)
        : null;
    final localVideo = _room.localParticipant != null && !_videoOff
        ? _videoTrackFor(_room.localParticipant!, TrackSource.camera)
        : null;
    final avatarUrl = _safePeerAvatar;

    return Stack(
      children: [
        if (remoteVideo != null)
          Positioned.fill(
            child: _videoRenderer(
              remoteVideo,
              screenShare: remoteScreenShare != null,
            ),
          )
        else
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 90,
                    backgroundColor: Colors.grey[800],
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            (widget.peerName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 67,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.peerName ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusText(),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (localVideo != null)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _videoRenderer(localVideo),
              ),
            ),
          ),
        if (_hasRemoteParticipants && remoteVideo != null)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_muted)
                    const Icon(Icons.mic_off,
                        color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _statusText(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingIncomingAccept) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop || _isEnding) return;
          unawaited(_declineIncomingCall());
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0B141A),
          body: _buildIncomingAcceptOverlay(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isEnding) {
          _minimizeCall();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: Stack(
          children: [
            Positioned.fill(
              child: _useParticipantGrid
                  ? _buildParticipantGrid()
                  : _buildSingleParticipantView(),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                tooltip: 'Minimize call',
                onPressed: _minimizeCall,
              ),
            ),
            if (_useParticipantGrid)
              Positioned(
                top: 16,
                left: 56,
                right: 16,
                child: Row(
                  children: [
                    Text(
                      widget.peerName ?? 'Group call',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _statusText(),
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_videoUpgradeRequester != null) ...[
                    _buildVideoUpgradeBanner(),
                    const SizedBox(height: 16),
                  ] else if (_hasRequestedVideoUpgrade) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Waiting for video response…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlBtn(
                      icon: _muted ? Icons.mic_off : Icons.mic,
                      bg: _muted ? Colors.red : Colors.grey[800]!,
                      onTap: () => unawaited(_toggleMute()),
                    ),
                    const SizedBox(width: 16),
                    _ControlBtn(
                      icon: Icons.volume_up_rounded,
                      bg: Colors.grey[800]!,
                      onTap: () => unawaited(_showAudioOutputPicker()),
                    ),
                    const SizedBox(width: 16),
                    _ControlBtn(
                      icon: _hasRequestedVideoUpgrade
                          ? Icons.hourglass_top
                          : (_videoOff ? Icons.videocam_off : Icons.videocam),
                      bg: _videoOff ? Colors.red : Colors.grey[800]!,
                      onTap: _hasRequestedVideoUpgrade ? () {} : _toggleVideo,
                    ),
                    if (_canUpgradeToVideo || widget.groupId != null) ...[
                      const SizedBox(width: 16),
                      _ControlBtn(
                        icon: _screenSharing
                            ? Icons.stop_screen_share
                            : Icons.screen_share,
                        bg: _screenSharing
                            ? Colors.blue
                            : Colors.grey[800]!,
                        onTap: _toggleScreenShare,
                      ),
                    ],
                    const SizedBox(width: 16),
                    _ControlBtn(
                      icon: Icons.call_end,
                      bg: Colors.red,
                      onTap: _hangUp,
                    ),
                  ],
                ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  decoration: BoxDecoration(
                    color: Colors.red[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _connecting
                            ? null
                            : () => unawaited(_retryConnect()),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final VoidCallback onTap;
  const _ControlBtn(
      {required this.icon, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
