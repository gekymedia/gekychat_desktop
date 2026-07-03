// lib/src/features/calls/livekit_call_screen.dart
//
// Desktop LiveKit call screen.
import 'dart:async';
import 'dart:convert';

import 'call_duration_format.dart';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show DesktopCapturerSource;
import 'package:livekit_client/livekit_client.dart';

import '../../services/livekit_call_service.dart';
import '../../core/session.dart';
import 'call_manager.dart';
import 'call_rating_sheet.dart';
import 'providers.dart';
import 'incoming_call_handler.dart';
import 'livekit_token_service.dart';

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
  void Function(CallState)? _callManagerStateBeforeIncoming;
  String? _error;
  DateTime? _connectedAt;
  Timer? _durationTicker;

  bool get _hasRemoteParticipants => _room.remoteParticipants.isNotEmpty;

  bool get _useParticipantGrid =>
      widget.groupId != null && _room.remoteParticipants.length > 1;

  bool _shouldLeaveGroupCallWithoutEnding() =>
      widget.groupId != null && _room.remoteParticipants.isNotEmpty;

  bool get _canUpgradeToVideo =>
      _hasRemoteParticipants && widget.groupId == null;

  String? get _safePeerAvatar {
    final url = widget.peerAvatar;
    if (url == null || url.isEmpty || !url.startsWith('http')) return null;
    return url;
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
    _room = widget.existingRoom ?? Room();
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
      });

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          final t = message.trim().toLowerCase();
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A participant left the call')),
          );
          setState(() {});
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

  Future<void> _handleEndedByManager() async {
    if (_isEnding) return;
    _isEnding = true;
    _durationTicker?.cancel();
    await ref.read(liveKitCallServiceProvider).endCall(disposeRoom: _ownsRoom);
    if (_ownsRoom) {
      await _room.disconnect();
    }
    try {
      final cm = ref.read(callManagerProvider);
      cm.onCallStateChanged = null;
      cm.onNoAnswerUi = null;
      cm.onParticipantLeft = null;
      if (widget.isOutgoingCall) {
        cm.onError = null;
      }
    } catch (_) {}
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _onRoomChanged() {
    if (_room.remoteParticipants.isNotEmpty) {
      ref.read(callManagerProvider).notifyRemoteParticipantJoined();
      _connectedAt ??= DateTime.now();
      _durationTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (widget.groupId == null &&
        _connectedAt != null &&
        !_isEnding &&
        !_connecting) {
      // 1:1 call — remote party left LiveKit; close instead of showing "Waiting…".
      unawaited(_hangUp());
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
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
        url = tokenResult.url;
        token = tokenResult.token;
      } catch (e) {
        if (mounted) {
          setState(() {
            _connecting = false;
            _error = 'Could not connect: $e';
          });
        }
        return;
      }
    }
    if (url == null || token == null) {
      setState(() {
        _connecting = false;
        _error = 'Missing LiveKit credentials';
      });
      return;
    }

    try {
      await _room.connect(
        url,
        token,
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
        fastConnectOptions: FastConnectOptions(
          microphone: const TrackOption(enabled: true),
          camera: TrackOption(enabled: widget.videoEnabled),
        ),
      );
      if (mounted) {
        setState(() => _connecting = false);
        _registerWithOverlayService();
        try {
          ref.read(callManagerProvider).notifyLiveKitRoomConnected();
        } catch (_) {}
        if (!widget.isOutgoingCall) {
          await ref
              .read(callRepositoryProvider)
              .acceptIncomingCallSession(widget.callId);
          await _notifyLiveKitJoinedSignal();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.toString();
        });
      }
    }
  }

  void _onIncomingAwaitCallStateChanged(CallState state) {
    _callManagerStateBeforeIncoming?.call(state);
    if (!mounted) return;
    if (state == CallState.ended) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not join call. Please try again.')),
      );
      return;
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
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
    Navigator.of(context).pop();
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
    if (_awaitingIncomingAccept &&
        _callManager.onCallStateChanged == _onIncomingAwaitCallStateChanged) {
      _callManager.onCallStateChanged = _callManagerStateBeforeIncoming;
    }
    if (_callManager.onCallStateChanged == _onManagerCallStateChanged) {
      _callManager.onCallStateChanged = null;
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
        _room.disconnect();
        _room.dispose();
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
    if (lp == null) return;
    _muted
        ? await lp.setMicrophoneEnabled(true)
        : await lp.setMicrophoneEnabled(false);
    setState(() => _muted = !_muted);
    ref.read(liveKitCallServiceProvider).updateMuteState(_muted);
  }

  Future<void> _toggleVideo() async {
    final lp = _room.localParticipant;
    if (lp == null) return;
    _videoOff
        ? await lp.setCameraEnabled(true)
        : await lp.setCameraEnabled(false);
    setState(() => _videoOff = !_videoOff);
    ref.read(liveKitCallServiceProvider).updateVideoState(!_videoOff);
  }

  Future<void> _toggleScreenShare() async {
    final lp = _room.localParticipant;
    if (lp == null) return;
    try {
      if (_screenSharing) {
        await lp.setScreenShareEnabled(false);
        setState(() => _screenSharing = false);
        return;
      }

      if (lkPlatformIsDesktop()) {
        final source = await showDialog<DesktopCapturerSource>(
          context: context,
          builder: (context) => ScreenSelectDialog(),
        );
        if (source == null || !mounted) return;

        final track = await LocalVideoTrack.createScreenShareTrack(
          ScreenShareCaptureOptions(
            sourceId: source.id,
            maxFrameRate: 15.0,
          ),
        );
        await lp.publishVideoTrack(track);
        if (mounted) setState(() => _screenSharing = true);
        return;
      }

      await lp.setScreenShareEnabled(true);
      setState(() => _screenSharing = !_screenSharing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screen share failed: $e')),
        );
      }
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
    await ref.read(liveKitCallServiceProvider).endCall(disposeRoom: _ownsRoom);
    if (_ownsRoom) {
      await _room.disconnect();
    }
    final cm = ref.read(callManagerProvider);
    if (_shouldLeaveGroupCallWithoutEnding()) {
      await cm.leaveCall(sessionIdOverride: widget.callId);
    } else {
      await cm.endCall(sessionIdOverride: widget.callId);
    }
    if (mounted) Navigator.of(context).pop();
    if (hadPeer) {
      _maybePromptRating();
    }
  }

  String _statusText() {
    if (_noAnswer) return 'No answer';
    if (_connecting) {
      return widget.isOutgoingCall ? 'Calling…' : 'Connecting…';
    }
    if (_error != null) return 'Connection failed';
    if (!_hasRemoteParticipants) {
      return widget.isOutgoingCall ? 'Calling…' : 'Waiting…';
    }
    final start = _connectedAt;
    if (start != null) {
      return formatCallDurationHms(DateTime.now().difference(start));
    }
    return 'Connected';
  }

  Widget _participantTile(Participant participant, {bool compact = false}) {
    final name = participant.name.isNotEmpty
        ? participant.name
        : (participant.identity.isNotEmpty ? participant.identity : 'Guest');
    final video = participant.getTrackPublicationBySource(TrackSource.camera)
            ?.track as VideoTrack? ??
        participant.getTrackPublicationBySource(TrackSource.screenShareVideo)
            ?.track as VideoTrack?;

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
            VideoTrackRenderer(video)
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
    final remoteVideo = remote != null
        ? (remote.getTrackPublicationBySource(TrackSource.camera)?.track
                as VideoTrack? ??
            remote
                .getTrackPublicationBySource(TrackSource.screenShareVideo)
                ?.track as VideoTrack?)
        : null;
    final localVideo = _room.localParticipant != null && !_videoOff
        ? _room.localParticipant!
                .getTrackPublicationBySource(TrackSource.camera)
                ?.track as VideoTrack?
        : null;
    final avatarUrl = _safePeerAvatar;

    return Stack(
      children: [
        if (remoteVideo != null)
          Positioned.fill(child: VideoTrackRenderer(remoteVideo))
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
                child: VideoTrackRenderer(localVideo),
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
              child: Container(
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
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 16),
                    _ControlBtn(
                      icon: _videoOff ? Icons.videocam_off : Icons.videocam,
                      bg: _videoOff ? Colors.red : Colors.grey[800]!,
                      onTap: _toggleVideo,
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
            ),
            if (_error != null)
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Connection failed: $_error',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
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
