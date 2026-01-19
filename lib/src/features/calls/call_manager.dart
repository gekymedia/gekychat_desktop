// lib/src/features/calls/call_manager.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:permission_handler/permission_handler.dart';
import '../realtime/pusher_service.dart';
import 'call_repository.dart';
import 'call_session.dart';

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
  
  webrtc.RTCPeerConnection? _peerConnection;
  webrtc.MediaStream? _localStream;
  webrtc.MediaStream? _remoteStream;
  
  CallSession? _currentCall;
  CallState _callState = CallState.idle;
  String _callType = 'voice'; // 'voice' or 'video'
  bool _isCaller = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  
  // ICE candidate queueing
  final List<webrtc.RTCIceCandidate> _iceCandidateQueue = [];
  bool _remoteDescriptionSet = false;
  
  // Call timeout
  Timer? _callTimeoutTimer;
  static const Duration _callTimeout = Duration(seconds: 60); // 60 seconds timeout
  
  // Reconnection handling
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  
  // Callbacks
  Function(CallState)? onCallStateChanged;
  Function(webrtc.MediaStream)? onRemoteStream;
  Function(Map<String, dynamic>)? onCallSignal;
  Function(String)? onError; // New error callback
  
  // WebRTC configuration with TURN support
  // PHASE 1: TURN/ICE server configuration (cached)
  Map<String, dynamic>? _cachedRtcConfig;

  // WebRTC configuration with TURN support
  // PHASE 1: Fetches TURN server config from backend API
  Future<Map<String, dynamic>> getRtcConfiguration() async {
    // Return cached config if available
    if (_cachedRtcConfig != null) {
      return _cachedRtcConfig!;
    }

    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    try {
      // PHASE 1: Fetch TURN config from backend
      final callConfig = await _callRepo.getCallConfig();
      
      if (callConfig['status'] == 'success') {
        final turnConfig = callConfig['config'];
        
        // Add TURN servers if available
        if (turnConfig['turn'] != null && turnConfig['turn'] is List) {
          final turnServers = turnConfig['turn'] as List;
          final iceServers = config['iceServers'] as List;
          for (final server in turnServers) {
            if (server is Map && server['urls'] != null) {
              // Handle both String and List<String> for urls
              final urls = server['urls'];
              iceServers.add({
                'urls': urls is String ? urls : (urls is List ? urls.join(',') : urls.toString()),
                if (server['username'] != null) 'username': server['username'] as String,
                if (server['credential'] != null) 'credential': server['credential'] as String,
              });
            }
          }
        }
      }
    } catch (e) {
      // Silently fall back to STUN only if config fetch fails
      debugPrint('Failed to fetch TURN config: $e');
    }

    // Cache the config for future use
    _cachedRtcConfig = config;
    return config;
  }

  // Synchronous getter for backward compatibility (uses cached config or defaults)
  // Note: Prefer using getRtcConfiguration() for async TURN config fetching
  @Deprecated('Use getRtcConfiguration() instead for TURN server support')
  Map<String, dynamic> get _rtcConfiguration {
    if (_cachedRtcConfig != null) {
      return _cachedRtcConfig!;
    }
    
    // Return default STUN-only config
    return {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };
  }

  CallManager(this._callRepo, this._pusherService) {
    // WebRTC doesn't need explicit initialization in flutter_webrtc
  }

  CallState get callState => _callState;
  set callState(CallState value) {
    _callState = value;
    onCallStateChanged?.call(value);
  }
  
  CallSession? get currentCall => _currentCall;
  set currentCall(CallSession? value) => _currentCall = value;
  
  bool get isCaller => _isCaller;
  set isCaller(bool value) => _isCaller = value;
  
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  String get callType => _callType;
  set callType(String value) => _callType = value;
  
  webrtc.MediaStream? get localStream => _localStream;
  webrtc.MediaStream? get remoteStream => _remoteStream;

  /// Start a new call
  Future<void> startCall({
    int? calleeId,
    int? groupId,
    int? conversationId,
    required String type,
  }) async {
    try {
      _callType = type;
      _isCaller = true;
      _callState = CallState.calling;
      _remoteDescriptionSet = false;
      _iceCandidateQueue.clear();
      _reconnectAttempts = 0;
      onCallStateChanged?.call(_callState);

      // Request permissions
      await _requestPermissions(type == 'video');

      // Get user media
      await _getUserMedia(type == 'video');

      // Create call session
      final response = await _callRepo.startCall(
        calleeId: calleeId,
        groupId: groupId,
        conversationId: conversationId,
        type: type,
      );

      _currentCall = CallSession(
        id: response['session_id'] as int,
        callerId: 0, // Will be set from response if available
        calleeId: calleeId,
        groupId: groupId,
        conversationId: conversationId,
        type: type,
        status: 'pending',
        callLink: response['call_link'] as String?,
      );

      // Set up call timeout
      _startCallTimeout();

      // Set up signaling listeners
      await _setupSignaling();

      // Create peer connection and send offer
      await _createPeerConnection();
      await _createOffer();
    } catch (e) {
      debugPrint('Error starting call: $e');
      _callTimeoutTimer?.cancel();
      _callState = CallState.ended;
      onCallStateChanged?.call(_callState);
      onError?.call('Failed to start call: $e');
      rethrow;
    }
  }

  /// Accept an incoming call
  Future<void> acceptCall() async {
    if (_currentCall == null) return;

    try {
      _callState = CallState.connecting;
      _remoteDescriptionSet = false;
      _iceCandidateQueue.clear();
      _reconnectAttempts = 0;
      _callTimeoutTimer?.cancel(); // Cancel timeout when accepting
      onCallStateChanged?.call(_callState);

      // Request permissions
      await _requestPermissions(_callType == 'video');

      // Get user media
      await _getUserMedia(_callType == 'video');

      // Create peer connection
      await _createPeerConnection();

      // Set up signaling listeners
      await _setupSignaling();

      // Note: State will be set to connected when answer is sent and connection is established
    } catch (e) {
      debugPrint('Error accepting call: $e');
      _callTimeoutTimer?.cancel();
      _callState = CallState.ended;
      onCallStateChanged?.call(_callState);
      onError?.call('Failed to accept call: $e');
      rethrow;
    }
  }

  /// Decline an incoming call
  Future<void> declineCall() async {
    if (_currentCall == null) return;
    await endCall();
  }

  /// End the current call
  Future<void> endCall() async {
    try {
      _callTimeoutTimer?.cancel();
      _reconnectTimer?.cancel();
      
      if (_currentCall != null) {
        await _callRepo.endCall(_currentCall!.id);
      }

      await _cleanup();
      _callState = CallState.ended;
      onCallStateChanged?.call(_callState);
    } catch (e) {
      debugPrint('Error ending call: $e');
      await _cleanup();
      _callState = CallState.ended;
      onCallStateChanged?.call(_callState);
    }
  }

  /// Toggle mute
  void toggleMute() {
    if (_localStream == null) return;
    
    _isMuted = !_isMuted;
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  /// Toggle video
  void toggleVideo() {
    if (_localStream == null || _callType != 'video') return;
    
    _isVideoEnabled = !_isVideoEnabled;
    _localStream!.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
  }

  /// Request media permissions
  Future<void> _requestPermissions(bool requireVideo) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw Exception('Microphone permission denied');
    }

    if (requireVideo) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        throw Exception('Camera permission denied');
      }
    }
  }

  /// Get user media (audio/video)
  Future<void> _getUserMedia(bool video) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': video ? {
        'facingMode': 'user',
      } : false,
    };

    _localStream = await webrtc.navigator.mediaDevices.getUserMedia(constraints);
  }

  /// Create WebRTC peer connection
  Future<void> _createPeerConnection() async {
    // PHASE 1: Fetch TURN config before creating peer connection
    final rtcConfig = await getRtcConfiguration();
    _peerConnection = await webrtc.createPeerConnection(rtcConfig);

    // Add local stream tracks
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    }

    // Handle remote stream
    _peerConnection!.onTrack = (webrtc.RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
      }
    };

    // Handle ICE candidates with queueing
    _peerConnection!.onIceCandidate = (webrtc.RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        if (_remoteDescriptionSet) {
          // Remote description is set, send candidate immediately
          _sendSignal({
            'type': 'ice-candidate',
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMLineIndex': candidate.sdpMLineIndex,
              'sdpMid': candidate.sdpMid,
            },
          });
        } else {
          // Queue candidate until remote description is set
          _iceCandidateQueue.add(candidate);
        }
      }
    };

    // Monitor connection state
    _peerConnection!.onConnectionState = (state) {
      debugPrint('Peer connection state: $state');
      switch (state) {
        case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _callState = CallState.connected;
          _reconnectAttempts = 0;
          _reconnectTimer?.cancel();
          onCallStateChanged?.call(_callState);
          break;
        case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          // Handle temporary disconnection
          _handleDisconnection();
          break;
        case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          // Connection failed, try to reconnect if possible
          _handleConnectionFailure();
          break;
        case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          // Connection closed normally
          break;
        default:
          break;
      }
    };

    // Monitor ICE connection state
    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('ICE connection state: $state');
      if (state == webrtc.RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _handleConnectionFailure();
      }
    };
  }

  /// Create and send offer
  Future<void> _createOffer() async {
    if (_peerConnection == null) return;

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _sendSignal({
      'type': 'offer',
      'sdp': offer.sdp,
      'sdpType': offer.type,
    });
  }

  /// Handle incoming offer
  Future<void> _handleOffer(Map<String, dynamic> data) async {
    if (_peerConnection == null) return;

    final sdpType = data['sdpType'] as String? ?? data['type'] as String? ?? 'offer';
    final offer = webrtc.RTCSessionDescription(
      data['sdp'] as String,
      sdpType,
    );

    await _peerConnection!.setRemoteDescription(offer);
    
    // Mark remote description as set and process queued ICE candidates
    _remoteDescriptionSet = true;
    for (var candidate in _iceCandidateQueue) {
      _sendSignal({
        'type': 'ice-candidate',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        },
      });
    }
    _iceCandidateQueue.clear();
    
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _sendSignal({
      'type': 'answer',
      'sdp': answer.sdp,
      'sdpType': answer.type,
    });
    
    // Update state to connecting (will be set to connected when connection is established)
    if (_callState != CallState.connected) {
      _callState = CallState.connecting;
      onCallStateChanged?.call(_callState);
    }
  }

  /// Handle incoming answer
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    if (_peerConnection == null) return;

    final sdpType = data['sdpType'] as String? ?? data['type'] as String? ?? 'answer';
    final answer = webrtc.RTCSessionDescription(
      data['sdp'] as String,
      sdpType,
    );

    await _peerConnection!.setRemoteDescription(answer);
    
    // Mark remote description as set and process queued ICE candidates
    _remoteDescriptionSet = true;
    for (var candidate in _iceCandidateQueue) {
      _sendSignal({
        'type': 'ice-candidate',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        },
      });
    }
    _iceCandidateQueue.clear();
  }

  /// Handle ICE candidate
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    if (_peerConnection == null) return;

    final candidateData = data['candidate'] as Map<String, dynamic>;
    final candidate = webrtc.RTCIceCandidate(
      candidateData['candidate'] as String,
      candidateData['sdpMid'] as String?,
      candidateData['sdpMLineIndex'] as int?,
    );

    await _peerConnection!.addCandidate(candidate);
  }

  /// Send signaling data via API
  Future<void> _sendSignal(Map<String, dynamic> signalData) async {
    if (_currentCall == null) return;

    final payload = jsonEncode({
      'session_id': _currentCall!.id.toString(),
      ...signalData,
    });

    await _callRepo.sendSignal(_currentCall!.id, payload);
  }

  /// Set up Pusher listeners for call signaling
  Future<void> _setupSignaling() async {
    if (_currentCall == null) return;

    // Determine channel based on call type
    String channel;
    if (_currentCall!.groupId != null) {
      channel = 'group.${_currentCall!.groupId}.call';
    } else if (_currentCall!.conversationId != null) {
      channel = 'conversation.${_currentCall!.conversationId}';
    } else {
      // Fallback to user channel
      channel = 'call.${_currentCall!.calleeId}';
    }

    // Subscribe to channel
    await _pusherService.subscribePrivate(channel, (data) {
      // Handle channel-level events if needed
    });

    // Listen for CallSignal events
    _pusherService.listen(channel, 'CallSignal', (data) {
      try {
        final signalData = data is String ? jsonDecode(data) : data;
        final payload = signalData['payload'] is String
            ? jsonDecode(signalData['payload'] as String)
            : signalData['payload'] as Map<String, dynamic>;

        onCallSignal?.call(payload);

        // Handle different signal types
        if (payload['action'] == 'invite' && !_isCaller) {
          _callState = CallState.ringing;
          onCallStateChanged?.call(_callState);
        } else if (payload['action'] == 'ended') {
          endCall();
        } else if (payload['type'] == 'offer') {
          _handleOffer(payload);
        } else if (payload['type'] == 'answer') {
          _handleAnswer(payload);
        } else if (payload['type'] == 'ice-candidate') {
          _handleIceCandidate(payload);
        }
      } catch (e) {
        debugPrint('Error handling call signal: $e');
      }
    });
  }

  /// Start call timeout timer
  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(_callTimeout, () {
      if (_callState == CallState.calling || _callState == CallState.ringing) {
        debugPrint('Call timeout - no answer received');
        onError?.call('Call timed out - no answer');
        endCall();
      }
    });
  }

  /// Handle temporary disconnection
  void _handleDisconnection() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnection attempts reached');
      onError?.call('Connection lost - unable to reconnect');
      endCall();
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_callState == CallState.connected && 
          _peerConnection?.connectionState == webrtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _reconnectAttempts++;
        debugPrint('Attempting to reconnect (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
        _renegotiateConnection();
      }
    });
  }

  /// Handle connection failure
  void _handleConnectionFailure() {
    debugPrint('Connection failed');
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      onError?.call('Connection failed - unable to reconnect');
      endCall();
    } else {
      _handleDisconnection();
    }
  }

  /// Renegotiate connection (create new offer/answer)
  Future<void> _renegotiateConnection() async {
    try {
      if (_peerConnection == null || _currentCall == null) return;
      
      if (_isCaller) {
        // Caller creates new offer
        await _createOffer();
      } else {
        // Callee waits for new offer from caller
        // In a full implementation, you might want to trigger caller to send new offer
      }
    } catch (e) {
      debugPrint('Error renegotiating connection: $e');
      _handleConnectionFailure();
    }
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    _callTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _iceCandidateQueue.clear();
    _remoteDescriptionSet = false;
    _reconnectAttempts = 0;

    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream?.dispose();
    _localStream = null;

    _remoteStream?.getTracks().forEach((track) {
      track.stop();
    });
    _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    _currentCall = null;
    _isCaller = false;
    _isMuted = false;
    _isVideoEnabled = true;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _cleanup();
  }
}

