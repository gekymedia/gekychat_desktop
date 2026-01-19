import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:permission_handler/permission_handler.dart';
import 'live_broadcast_repository.dart';

/// PHASE 2: Broadcast Streaming Screen for Desktop
/// Allows broadcaster to stream their video
class BroadcastStreamingScreen extends ConsumerStatefulWidget {
  final int broadcastId;
  final Map<String, dynamic> startData; // Contains token, room_name, websocket_url

  const BroadcastStreamingScreen({
    super.key,
    required this.broadcastId,
    required this.startData,
  });

  @override
  ConsumerState<BroadcastStreamingScreen> createState() => _BroadcastStreamingScreenState();
}

class _BroadcastStreamingScreenState extends ConsumerState<BroadcastStreamingScreen> {
  Room? _room;
  bool _isStreaming = false;
  bool _isConnecting = true;
  String? _errorMessage;
  bool _cameraEnabled = true;
  bool _microphoneEnabled = true;

  @override
  void initState() {
    super.initState();
    _connectAndStartStreaming();
  }

  @override
  void dispose() {
    _room?.disconnect();
    super.dispose();
  }

  Future<void> _connectAndStartStreaming() async {
    try {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
      });

      // Request camera and microphone permissions first
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      
      if (!cameraStatus.isGranted) {
        throw Exception('Camera permission is required to start broadcasting');
      }
      
      if (!micStatus.isGranted) {
        throw Exception('Microphone permission is required to start broadcasting');
      }

      final roomName = widget.startData['room_name'] as String? ?? '';
      final token = widget.startData['token'] as String? ?? '';
      final websocketUrl = widget.startData['websocket_url'] as String? ?? '';

      if (token.isEmpty || roomName.isEmpty) {
        throw Exception('Missing token or room name');
      }

      // Create LiveKit room
      final room = Room();
      
      // Connect to room
      await room.connect(
        websocketUrl,
        token,
      );

      // Enable camera and microphone after connection
      await room.localParticipant?.setCameraEnabled(_cameraEnabled);
      await room.localParticipant?.setMicrophoneEnabled(_microphoneEnabled);

      setState(() {
        _room = room;
        _isConnecting = false;
        _isStreaming = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start streaming: $e';
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_room == null) return;
    
    try {
      _cameraEnabled = !_cameraEnabled;
      await _room!.localParticipant?.setCameraEnabled(_cameraEnabled);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle camera: $e')),
        );
      }
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_room == null) return;
    
    try {
      _microphoneEnabled = !_microphoneEnabled;
      await _room!.localParticipant?.setMicrophoneEnabled(_microphoneEnabled);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle microphone: $e')),
        );
      }
    }
  }

  Future<void> _endBroadcast() async {
    if (_room != null) {
      await _room!.disconnect();
    }

    try {
      final repo = ref.read(liveBroadcastRepositoryProvider);
      await repo.endBroadcast(widget.broadcastId);
    } catch (e) {
      debugPrint('Failed to end broadcast: $e');
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Local Video Preview
          if (_isConnecting)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Starting broadcast...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _connectAndStartStreaming,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_room != null && _cameraEnabled)
            _LocalVideoPreview(room: _room!)
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off,
                    size: 100,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera is off',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Live Indicator
          if (_isStreaming)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top Controls
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _endBroadcast,
                ),
                if (_isStreaming)
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                          color: Colors.white,
                        ),
                        onPressed: _toggleCamera,
                      ),
                      IconButton(
                        icon: Icon(
                          _microphoneEnabled ? Icons.mic : Icons.mic_off,
                          color: Colors.white,
                        ),
                        onPressed: _toggleMicrophone,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Bottom End Broadcast Button
          if (_isStreaming)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _endBroadcast,
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: const Text(
                    'End Broadcast',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget to render local video preview
class _LocalVideoPreview extends StatefulWidget {
  final Room room;

  const _LocalVideoPreview({required this.room});

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoTrack? _localVideoTrack;

  @override
  void initState() {
    super.initState();
    widget.room.localParticipant?.addListener(_onLocalParticipantChanged);
    _onLocalParticipantChanged();
  }

  @override
  void dispose() {
    widget.room.localParticipant?.removeListener(_onLocalParticipantChanged);
    super.dispose();
  }

  void _onLocalParticipantChanged() {
    final localParticipant = widget.room.localParticipant;
    if (localParticipant == null) {
      setState(() => _localVideoTrack = null);
      return;
    }
    
    final trackPublications = localParticipant.trackPublications.values;
    final videoTracks = trackPublications
        .where((pub) => pub.track != null && pub.track is LocalVideoTrack)
        .map((pub) => pub.track as LocalVideoTrack);

    setState(() {
      _localVideoTrack = videoTracks.isNotEmpty ? videoTracks.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_localVideoTrack != null) {
      return Center(
        child: VideoTrackRenderer(
          _localVideoTrack!,
          fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 100,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Camera is off',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
