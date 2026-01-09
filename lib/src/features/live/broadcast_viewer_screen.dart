import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'live_broadcast_repository.dart';

/// PHASE 2: Broadcast Viewer Screen for Desktop
/// Shows the live broadcast stream and chat with LiveKit integration
class BroadcastViewerScreen extends ConsumerStatefulWidget {
  final int broadcastId;
  final Map<String, dynamic> joinData; // Contains token, room_name, websocket_url

  const BroadcastViewerScreen({
    super.key,
    required this.broadcastId,
    required this.joinData,
  });

  @override
  ConsumerState<BroadcastViewerScreen> createState() => _BroadcastViewerScreenState();
}

class _BroadcastViewerScreenState extends ConsumerState<BroadcastViewerScreen> {
  final TextEditingController _chatController = TextEditingController();
  bool _isFullScreen = false;
  Room? _room;
  RemoteParticipant? _broadcaster;
  bool _isConnecting = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  EventsListener<RoomEvent>? _listener;

  @override
  void dispose() {
    _chatController.dispose();
    _listener?.dispose();
    _room?.disconnect();
    super.dispose();
  }

  Future<void> _connectToRoom() async {
    try {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
      });

      final roomName = widget.joinData['room_name'] as String? ?? '';
      final token = widget.joinData['token'] as String? ?? '';
      final websocketUrl = widget.joinData['websocket_url'] as String? ?? '';

      if (token.isEmpty || roomName.isEmpty) {
        throw Exception('Missing token or room name');
      }

      if (websocketUrl.isEmpty) {
        throw Exception('LiveKit server URL is not configured. Please check server settings.');
      }

      // Validate websocket URL format
      if (!websocketUrl.startsWith('ws://') && !websocketUrl.startsWith('wss://')) {
        throw Exception('Invalid LiveKit WebSocket URL format. Expected ws:// or wss://');
      }

      // Create LiveKit room
      final room = Room();
      
      // Connect to room with timeout
      await room.connect(
        websocketUrl,
        token,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. LiveKit server may be unreachable at $websocketUrl');
        },
      );

      // Listen for remote participants
      room.addListener(() {
        if (mounted) {
          setState(() {
            // Get first remote participant (broadcaster)
            _broadcaster = room.remoteParticipants.values.isNotEmpty
                ? room.remoteParticipants.values.first
                : null;
          });
        }
      });

      // Listen for participant events
      _listener = room.createListener();
      _listener!
        ..on<RoomDisconnectedEvent>((event) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Disconnected from broadcast';
              _isConnecting = false;
              _broadcaster = null;
            });
          }
        })
        ..on<ParticipantConnectedEvent>((event) {
          if (mounted) {
            setState(() {
              _broadcaster = event.participant as RemoteParticipant?;
            });
          }
        });

      setState(() {
        _room = room;
        _isConnecting = false;
      });
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to connect: $e';
        // Provide more helpful error messages
        if (e.toString().contains('Page Not Found') || e.toString().contains('404')) {
          errorMsg = 'LiveKit server not found. Please check server configuration.\n\nError: $e';
        } else if (e.toString().contains('timeout')) {
          errorMsg = 'Connection timeout. LiveKit server may be unreachable.\n\nError: $e';
        } else if (e.toString().contains('ConnectException')) {
          errorMsg = 'Cannot connect to LiveKit server. Please verify the server is running and the URL is correct.\n\nError: $e';
        }
        setState(() {
          _errorMessage = errorMsg;
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _sendChatMessage() async {
    if (_chatController.text.trim().isEmpty) return;

    try {
      final repo = ref.read(liveBroadcastRepositoryProvider);
      await repo.sendChatMessage(widget.broadcastId, message: _chatController.text.trim());
      _chatController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Main Video Area
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // Video Stream
                if (_isConnecting)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          'Connecting to broadcast...',
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
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
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
                          onPressed: _connectToRoom,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (_broadcaster != null)
                  _BroadcastVideoView(participant: _broadcaster!)
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.live_tv,
                          size: 100,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Waiting for stream...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Live Indicator
                if (!_isConnecting && _errorMessage == null)
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          _room?.disconnect();
                          Navigator.pop(context);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() => _isFullScreen = !_isFullScreen);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chat Sidebar
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              border: Border(
                left: BorderSide(
                  color: isDark ? const Color(0xFF2A3942) : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Chat Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF2A3942) : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Live Chat',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat Messages (placeholder - can be enhanced with real-time chat)
                Expanded(
                  child: Center(
                    child: Text(
                      'Chat messages will appear here',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                // Chat Input
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF2A3942) : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF2A3942) : Colors.grey.shade300,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF111B21) : Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendChatMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF008069)),
                        onPressed: _sendChatMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to render video from a remote participant
class _BroadcastVideoView extends StatefulWidget {
  final RemoteParticipant participant;

  const _BroadcastVideoView({required this.participant});

  @override
  State<_BroadcastVideoView> createState() => _BroadcastVideoViewState();
}

class _BroadcastVideoViewState extends State<_BroadcastVideoView> {
  TrackPublication? _videoPub;

  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onParticipantChanged);
    _onParticipantChanged();
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onParticipantChanged);
    super.dispose();
  }

  void _onParticipantChanged() {
    final trackPublications = widget.participant.trackPublications.values;
    final subscribedVideos = trackPublications.where((pub) {
      return pub.kind == TrackType.VIDEO &&
          !pub.isScreenShare &&
          pub.subscribed &&
          !pub.muted;
    });

    setState(() {
      _videoPub = subscribedVideos.isNotEmpty ? subscribedVideos.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_videoPub?.track != null && _videoPub!.track is VideoTrack) {
      return VideoTrackRenderer(
        _videoPub!.track as VideoTrack,
        fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.live_tv,
            size: 100,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Waiting for video stream...',
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
