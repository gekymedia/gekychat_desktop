// lib/src/features/calls/incoming_call_handler.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers.dart';
import '../realtime/pusher_service.dart';
import 'call_manager.dart';
import 'call_screen.dart';
import 'call_session.dart';
import 'providers.dart';

/// Global handler for incoming calls
class IncomingCallHandler {
  final PusherService _pusherService;
  BuildContext? _context;
  CallManager? _callManager;
  int? _currentUserId;

  IncomingCallHandler(this._pusherService);

  /// Initialize and set up listeners
  Future<void> initialize(WidgetRef ref) async {
    // Get current user ID
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');
    
    if (_currentUserId == null) return;

    // Get call manager
    _callManager = ref.read(callManagerProvider);

    // Listen for incoming calls on user's private channel
    await _pusherService.subscribePrivate('call.$_currentUserId', (data) {
      // Channel-level callback
    });

    _pusherService.listen('call.$_currentUserId', 'CallSignal', (data) {
      _handleIncomingCall(data);
    });
  }

  void _handleIncomingCall(dynamic data) {
    handleIncomingCallFromConversation(data, null);
  }
  
  void handleIncomingCallFromConversation(dynamic data, int? conversationId) {
    try {
      final signalData = data is String ? jsonDecode(data) : data;
      final payload = signalData['payload'] is String
          ? jsonDecode(signalData['payload'] as String)
          : signalData['payload'] as Map<String, dynamic>;

      if (payload['action'] == 'invite' && _context != null && _callManager != null) {
        final sessionId = payload['session_id'] as int;
        final callType = payload['type'] as String? ?? 'voice';
        final caller = payload['caller'] as Map<String, dynamic>?;
        final calleeId = payload['callee_id'] as int?;
        
        // Check if this call is for the current user
        if (calleeId != null && calleeId != _currentUserId) {
          // This call is not for us, ignore it
          return;
        }

        // Create call session
        final call = CallSession(
          id: sessionId,
          callerId: caller?['id'] as int? ?? 0,
          calleeId: calleeId ?? _currentUserId,
          conversationId: conversationId ?? payload['conversation_id'] as int?,
          type: callType,
          status: 'pending',
        );

        // Set up call manager for incoming call
        _callManager!.currentCall = call;
        _callManager!.callType = callType;
        _callManager!.isCaller = false;
        _callManager!.callState = CallState.ringing;

        // Show incoming call screen
        Navigator.push(
          _context!,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              call: call,
              userName: caller?['name'] as String? ?? 'Unknown',
              userAvatar: caller?['avatar'] as String?,
              isIncoming: true,
              callManager: _callManager!,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling incoming call: $e');
    }
  }

  void setContext(BuildContext context) {
    _context = context;
  }
}

final incomingCallHandlerProvider = Provider<IncomingCallHandler>((ref) {
  final pusherService = ref.read(pusherServiceProvider);
  return IncomingCallHandler(pusherService);
});

