// lib/src/features/calls/call_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'call_manager.dart';
import 'call_session.dart';

class CallScreen extends ConsumerStatefulWidget {
  final CallSession call;
  final String? userName;
  final String? userAvatar;
  final bool isIncoming;
  final CallManager callManager;

  const CallScreen({
    super.key,
    required this.call,
    this.userName,
    this.userAvatar,
    this.isIncoming = false,
    required this.callManager,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  webrtc.RTCVideoRenderer? _remoteRenderer;
  webrtc.RTCVideoRenderer? _localRenderer;
  AudioPlayer? _ringtonePlayer;
  Timer? _ringtoneTimer;

  @override
  void initState() {
    super.initState();
    widget.callManager.onCallStateChanged = _onCallStateChanged;
    widget.callManager.onRemoteStream = _onRemoteStream;
    widget.callManager.onError = _onError;
    _initializeRenderers();
    _initializeRingtone();
  }
  
  Future<void> _initializeRingtone() async {
    _ringtonePlayer = AudioPlayer();
    await _ringtonePlayer?.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> _initializeRenderers() async {
    _remoteRenderer = webrtc.RTCVideoRenderer();
    _localRenderer = webrtc.RTCVideoRenderer();
    await _remoteRenderer!.initialize();
    await _localRenderer!.initialize();
    if (mounted) {
      _updateRenderers();
    }
  }

  void _updateRenderers() {
    if (widget.callManager.remoteStream != null && _remoteRenderer != null) {
      _remoteRenderer!.srcObject = widget.callManager.remoteStream;
    }
    if (widget.callManager.localStream != null && _localRenderer != null) {
      _localRenderer!.srcObject = widget.callManager.localStream;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _stopRingtone();
    _ringtonePlayer?.dispose();
    _remoteRenderer?.dispose();
    _localRenderer?.dispose();
    super.dispose();
  }
  
  Future<void> _playRingtone() async {
    if (_ringtonePlayer == null) return;
    try {
      // Play system notification sound as ringtone
      await _ringtonePlayer?.setReleaseMode(ReleaseMode.loop);
      
      // Play system sound repeatedly for ringing
      // Use a timer to play system sound every second
      _ringtoneTimer?.cancel();
      _ringtoneTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        SystemSound.play(SystemSoundType.alert);
      });
      
      // Also play immediately
      SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }
  
  Future<void> _stopRingtone() async {
    _ringtoneTimer?.cancel();
    await _ringtonePlayer?.stop();
  }

  void _onCallStateChanged(CallState state) {
    if (mounted) {
      setState(() {});
      
      // Handle ringtone based on call state
      if (state == CallState.ringing && widget.isIncoming) {
        _playRingtone();
      } else if (state == CallState.calling && !widget.isIncoming) {
        // Play dial tone for outgoing calls (optional)
        // _playRingtone();
      } else {
        _stopRingtone();
      }
      
      // Navigate back when call ends
      if (state == CallState.ended) {
        _stopRingtone();
        Navigator.of(context).pop();
      }
    }
  }

  void _onRemoteStream(webrtc.MediaStream stream) {
    _updateRenderers();
  }

  void _onError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = widget.callManager.callState;
    final isVideoCall = widget.call.type == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (for video calls) or avatar (for voice calls)
            if (isVideoCall && _remoteRenderer != null && widget.callManager.remoteStream != null)
              Positioned.fill(
                child: webrtc.RTCVideoView(
                  _remoteRenderer!,
                  mirror: false,
                  objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else if (!isVideoCall || widget.callManager.remoteStream == null)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0B141A),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: widget.userAvatar != null
                              ? CachedNetworkImageProvider(widget.userAvatar!)
                              : null,
                          child: widget.userAvatar == null
                              ? Text(
                                  (widget.userName ?? 'User')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 48),
                                )
                              : null,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.userName ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getCallStateText(callState),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Local video (for video calls)
            if (isVideoCall && _localRenderer != null && widget.callManager.localStream != null)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: webrtc.RTCVideoView(
                      _localRenderer!,
                      mirror: true,
                    ),
                  ),
                ),
              ),

            // Call controls
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
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (callState == CallState.ringing && widget.isIncoming)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCallButton(
                            icon: Icons.call_end,
                            backgroundColor: Colors.red,
                            size: 60,
                            onPressed: () => widget.callManager.declineCall(),
                          ),
                          _buildCallButton(
                            icon: Icons.call,
                            backgroundColor: Colors.green,
                            size: 60,
                            onPressed: () => widget.callManager.acceptCall(),
                          ),
                        ],
                      )
                    else if (callState == CallState.calling || callState == CallState.connecting)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCallButton(
                            icon: Icons.call_end,
                            backgroundColor: Colors.red,
                            size: 60,
                            onPressed: () => widget.callManager.endCall(),
                          ),
                        ],
                      )
                    else if (callState == CallState.connected)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCallButton(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            backgroundColor: _isMuted ? Colors.red : Colors.grey[800]!,
                            size: 50,
                            onPressed: () {
                              widget.callManager.toggleMute();
                              setState(() {
                                _isMuted = widget.callManager.isMuted;
                              });
                            },
                          ),
                          if (isVideoCall)
                            _buildCallButton(
                              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                              backgroundColor: _isVideoEnabled ? Colors.grey[800]! : Colors.red,
                              size: 50,
                              onPressed: () {
                                widget.callManager.toggleVideo();
                                setState(() {
                                  _isVideoEnabled = widget.callManager.isVideoEnabled;
                                });
                              },
                            ),
                          _buildCallButton(
                            icon: Icons.call_end,
                            backgroundColor: Colors.red,
                            size: 60,
                            onPressed: () => widget.callManager.endCall(),
                          ),
                        ],
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

  Widget _buildCallButton({
    required IconData icon,
    required Color backgroundColor,
    required double size,
    required VoidCallback onPressed,
  }) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }

  String _getCallStateText(CallState state) {
    switch (state) {
      case CallState.calling:
        return 'Calling...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.connecting:
        return 'Connecting...';
      case CallState.connected:
        return 'Connected';
      case CallState.ended:
        return 'Call ended';
      default:
        return '';
    }
  }
}

