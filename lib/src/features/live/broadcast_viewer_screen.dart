import 'dart:async';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import '../calls/livekit_ice_config.dart';
import 'live_broadcast_repository.dart';
import 'live_broadcast_social_overlay.dart';
import 'live_broadcast_screen.dart' show liveBroadcastsProvider;
import '../../core/providers.dart';
import '../../utils/snackbar_helper.dart';
import '../calls/livekit_quality.dart';

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
  bool _streamEnded = false;
  bool _hadBroadcaster = false;
  bool _isReconnecting = false;
  Timer? _statsPollTimer;
  Timer? _hostAbsentTimer;
  void Function(dynamic)? _endedListener;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachEndedListener());
  }

  void _attachEndedListener() {
    final pusher = ref.read(pusherServiceProvider);
    unawaited(pusher.connect());
    _endedListener = (raw) {
      final m = decodePusherPayload(raw);
      if (m == null) return;
      final id = int.tryParse(m['id']?.toString() ?? '');
      if (id == widget.broadcastId) {
        _handleStreamEnded();
      }
    };
    pusher.listen('live-broadcasts', 'LiveBroadcastEnded', _endedListener!);
    _startStatsPolling();
  }

  void _handleStreamEnded() {
    if (_streamEnded || !mounted) return;
    _streamEnded = true;
    _statsPollTimer?.cancel();
    _hostAbsentTimer?.cancel();
    unawaited(_room?.disconnect());
    ref.invalidate(liveBroadcastsProvider);
    setState(() {
      _broadcaster = null;
      _isReconnecting = false;
    });
    context.showInfoToast('This live has ended');
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _clearReconnecting() {
    _hostAbsentTimer?.cancel();
    if (!mounted || _streamEnded || !_isReconnecting) return;
    setState(() => _isReconnecting = false);
  }

  void _onHostPossiblyAbsent() {
    if (_streamEnded || !mounted) return;
    if (_room?.connectionState == ConnectionState.reconnecting) {
      setState(() {
        _isReconnecting = true;
        _broadcaster = null;
      });
      return;
    }
    setState(() {
      _isReconnecting = true;
      _broadcaster = null;
    });
    _hostAbsentTimer?.cancel();
    _hostAbsentTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || _streamEnded) return;
      unawaited(_confirmStillLiveOrEnd());
    });
  }

  Future<void> _confirmStillLiveOrEnd() async {
    if (!mounted || _streamEnded) return;
    try {
      final stats = await ref
          .read(liveBroadcastRepositoryProvider)
          .getBroadcastStats(widget.broadcastId);
      final status = stats['status']?.toString();
      if (status != null && status != 'live') {
        _handleStreamEnded();
        return;
      }
    } catch (_) {}

    final room = _room;
    if (room != null &&
        room.connectionState == ConnectionState.disconnected &&
        !_streamEnded) {
      try {
        final url = widget.joinData['websocket_url'] as String? ?? '';
        final token = widget.joinData['token'] as String? ?? '';
        if (url.isNotEmpty && token.isNotEmpty) {
          final rtcConfiguration = await fetchLiveKitRtcConfiguration(
            ref.read(apiServiceProvider),
          );
          await room.connect(
            url,
            token,
            connectOptions: ConnectOptions(rtcConfiguration: rtcConfiguration),
          );
        }
      } catch (_) {}
    }

    if (!mounted || _streamEnded) return;
    if (_room != null && _room!.remoteParticipants.isNotEmpty) {
      _clearReconnecting();
    }
  }

  void _onRoomDisconnected(RoomDisconnectedEvent event) {
    if (!mounted || _streamEnded) return;
    final reason = event.reason;
    if (reason == DisconnectReason.clientInitiated) return;
    if (reason == DisconnectReason.roomDeleted ||
        reason == DisconnectReason.serverShutdown ||
        reason == DisconnectReason.participantRemoved) {
      _handleStreamEnded();
      return;
    }
    setState(() => _isReconnecting = true);
    unawaited(_confirmStillLiveOrEnd());
  }

  void _startStatsPolling() {
    _statsPollTimer?.cancel();
    _statsPollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!mounted || _streamEnded) return;
      try {
        final repo = ref.read(liveBroadcastRepositoryProvider);
        final stats = await repo.getBroadcastStats(widget.broadcastId);
        if (!mounted || _streamEnded || stats.isEmpty) return;
        final status = stats['status']?.toString();
        if (status != null && status != 'live') {
          _handleStreamEnded();
        }
      } catch (_) {}
    });
  }

  EventsListener<RoomEvent>? _listener;

  @override
  void dispose() {
    _statsPollTimer?.cancel();
    _hostAbsentTimer?.cancel();
    if (_endedListener != null) {
      ref.read(pusherServiceProvider).removeListener(
            'live-broadcasts',
            'LiveBroadcastEnded',
            _endedListener!,
          );
    }
    _chatController.dispose();
    _listener?.dispose();
    _room?.disconnect();
    super.dispose();
  }
  
  /// Subscribe to all video tracks from a remote participant
  /// Note: LiveKit auto-subscribes tracks by default, but we ensure we're listening for them
  void _subscribeToParticipantTracks(RemoteParticipant participant) {
    // Tracks are auto-subscribed in LiveKit by default
    // This method ensures we update the UI when tracks are available
    if (mounted) {
      setState(() {
        // Force UI update to check for available tracks
      });
    }
  }

  Future<void> _connectToRoom() async {
    String websocketUrl = '';
    try {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
      });

      final roomName = widget.joinData['room_name'] as String? ?? '';
      final token = widget.joinData['token'] as String? ?? '';
      websocketUrl = widget.joinData['websocket_url'] as String? ?? '';
      
      // Debug: Log the join data
      debugPrint('🔍 LiveKit Join Data: room_name=$roomName, token=${token.isNotEmpty ? "present" : "missing"}, websocket_url=$websocketUrl');

      if (token.isEmpty || roomName.isEmpty) {
        throw Exception('Missing token or room name. Token: ${token.isEmpty ? "missing" : "present"}, Room: ${roomName.isEmpty ? "missing" : roomName}');
      }

      if (websocketUrl.isEmpty) {
        throw Exception('LiveKit server URL is not configured. Please check server settings.\n\n'
            'The backend did not provide a websocket_url. Please ensure:\n'
            '• LIVEKIT_URL is set in server .env file\n'
            '• LiveKitService is properly configured\n'
            '• The /live/{id}/join endpoint returns websocket_url');
      }

      // Validate websocket URL format
      if (!websocketUrl.startsWith('ws://') && !websocketUrl.startsWith('wss://')) {
        throw Exception('Invalid LiveKit WebSocket URL format. Expected ws:// or wss://');
      }

      // Create LiveKit room
      final room = Room(roomOptions: LiveKitQuality.viewerRoomOptions());
      
      // Connect to room with timeout
      final rtcConfiguration = await fetchLiveKitRtcConfiguration(
        ref.read(apiServiceProvider),
      );
      await room.connect(
        websocketUrl,
        token,
        connectOptions: ConnectOptions(rtcConfiguration: rtcConfiguration),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. LiveKit server may be unreachable at $websocketUrl');
        },
      );

      // Listen for remote participants
      room.addListener(() {
        if (!mounted || _streamEnded) return;
        setState(() {
          final next = room.remoteParticipants.values.isNotEmpty
              ? room.remoteParticipants.values.first
              : null;
          if (next != null) {
            _hadBroadcaster = true;
            _hostAbsentTimer?.cancel();
            _isReconnecting = false;
          } else if (_hadBroadcaster) {
            _onHostPossiblyAbsent();
            return;
          }
          _broadcaster = next;
        });
      });

      // Listen for participant events
      _listener = room.createListener();
      _listener!
        ..on<RoomDisconnectedEvent>(_onRoomDisconnected)
        ..on<RoomReconnectingEvent>((_) {
          if (!mounted || _streamEnded) return;
          setState(() => _isReconnecting = true);
        })
        ..on<RoomReconnectedEvent>((_) {
          if (!mounted || _streamEnded) return;
          _clearReconnecting();
        })
        ..on<ParticipantConnectedEvent>((event) {
          if (mounted && !_streamEnded) {
            final participant = event.participant;
            // Only handle remote participants (broadcasters)
            if (participant is! LocalParticipant) {
              setState(() {
                _broadcaster = participant;
                _hadBroadcaster = true;
                _isReconnecting = false;
              });
              _hostAbsentTimer?.cancel();
              // Check for existing tracks and update UI
              _subscribeToParticipantTracks(participant);
              debugPrint('📹 Broadcaster connected: ${participant.identity}, tracks: ${(participant).trackPublications.length}');
            }
          }
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          if (!mounted || _streamEnded) return;
          final left = event.participant;
          if (_broadcaster?.sid == left.sid) {
            _onHostPossiblyAbsent();
          }
        })
        ..on<TrackPublishedEvent>((event) {
          // When a track is published, update UI
          if (mounted) {
            final participant = event.participant;
            // Only handle remote participants (broadcasters)
            if (participant is! LocalParticipant) {
              debugPrint('📹 Track published: ${event.publication.kind}, subscribed: ${event.publication.subscribed}');
              setState(() {
                // Force UI update when track is published
              });
            }
          }
        })
        ..on<TrackSubscribedEvent>((event) {
          // Track subscribed successfully - update UI
          if (mounted) {
            setState(() {
              // Force UI update when track is subscribed
            });
          }
        });
      
      // Subscribe to tracks of existing participants
      for (final participant in room.remoteParticipants.values) {
        _subscribeToParticipantTracks(participant);
      }

      setState(() {
        _room = room;
        _isConnecting = false;
      });
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to connect: $e';
        String errorString = e.toString();
        
        // Provide more helpful error messages
        if (errorString.contains('Page Not Found') || errorString.contains('404') || errorString.contains('<!doctype html>')) {
          errorMsg = 'LiveKit server not found. Please check server configuration.\n\n'
              'The LiveKit server may not be running or the URL is incorrect.\n'
              'Please verify:\n'
              '• LIVEKIT_URL is configured in server .env file\n'
              '• LiveKit server is running and accessible\n'
              '• The WebSocket URL format is correct (ws:// or wss://)\n\n'
              'Attempted URL: ${websocketUrl.isEmpty ? "Not provided" : websocketUrl}\n\n'
              'Error: ${errorString.length > 300 ? "${errorString.substring(0, 300)}..." : errorString}';
        } else if (errorString.contains('timeout') || errorString.contains('Timeout')) {
          errorMsg = 'Connection timeout. LiveKit server may be unreachable.\n\n'
              'The server at ${websocketUrl.isEmpty ? "unknown URL" : websocketUrl} did not respond.\n\n'
              'Error: $e';
        } else if (errorString.contains('ConnectException') || errorString.contains('Connection')) {
          errorMsg = 'Cannot connect to LiveKit server. Please verify the server is running and the URL is correct.\n\n'
              'Attempted to connect to: ${websocketUrl.isEmpty ? "Not provided" : websocketUrl}\n\n'
              'Error: $e';
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
                context.showErrorToast('Failed to send message: $e');      }
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
                else if (_streamEnded)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_off_outlined,
                          size: 100,
                          color: Colors.white.withOpacity(0.55),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'This live has ended',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Leaving…',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isReconnecting)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 24),
                        Text(
                          'Reconnecting…',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stream connection dropped — trying again',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_errorMessage != null)
                  Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
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
                      ),
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
                if (!_isConnecting && _errorMessage == null && !_streamEnded)
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
        fit: VideoViewFit.cover,
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
