import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../realtime/pusher_service.dart';
import '../../../core/providers.dart';
import '../../../core/session.dart';

/// Provider that tracks typing status for all conversations
final typingStatusProvider = StateNotifierProvider<TypingStatusNotifier, Map<int, bool>>((ref) {
  return TypingStatusNotifier(ref);
});

/// Provider that tracks recording status separately
final recordingStatusProvider = StateNotifierProvider<RecordingStatusNotifier, Map<int, bool>>((ref) {
  return RecordingStatusNotifier(ref);
});

class TypingStatusNotifier extends StateNotifier<Map<int, bool>> {
  final Ref _ref;
  TypingStatusNotifier(this._ref) : super({}) {
    _initializeListener();
  }
  
  PusherService? _pusherService;
  final Map<int, Timer> _typingTimers = {};
  final Set<int> _subscribedConversations = {};
  
  void _initializeListener() async {
    // Get or create PusherService instance
    _pusherService = PusherService();
    await _pusherService!.connect();
  }
  
  /// Subscribe to typing events for a conversation
  void subscribeToConversation(int conversationId) {
    if (_subscribedConversations.contains(conversationId)) {
      return; // Already subscribed
    }
    
    if (_pusherService == null) {
      _initializeListener();
      return;
    }
    
    _subscribedConversations.add(conversationId);
    
    // Listen for typing events on this conversation channel
    _pusherService!.listen(
      'conversation.$conversationId',
      'UserTyping',
      (data) {
        if (data is Map) {
          final userId = data['user_id'] as int?;
          final isTyping = data['is_typing'] as bool? ?? false;
          
          // Get current user ID to ignore own typing
          final currentUserAsync = _ref.read(currentUserProvider.future);
          currentUserAsync.then((currentUser) {
            // Only track typing from other users
            if (userId != null && userId != currentUser.id) {
              // Cancel existing timer for this conversation
              _typingTimers[conversationId]?.cancel();
              
              // Update typing status
              final newState = Map<int, bool>.from(state);
              newState[conversationId] = isTyping;
              state = newState;
              
              // Auto-clear typing after 3 seconds
              if (isTyping) {
                _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
                  final updatedState = Map<int, bool>.from(state);
                  updatedState[conversationId] = false;
                  state = updatedState;
                  _typingTimers.remove(conversationId);
                });
              } else {
                _typingTimers.remove(conversationId);
              }
            }
          });
        }
      },
    );
  }
  
  /// Subscribe to multiple conversations at once
  void subscribeToConversations(List<int> conversationIds) {
    for (final id in conversationIds) {
      subscribeToConversation(id);
    }
  }
  
  /// Unsubscribe from typing events for a conversation
  void unsubscribeFromConversation(int conversationId) {
    _subscribedConversations.remove(conversationId);
    _typingTimers[conversationId]?.cancel();
    _typingTimers.remove(conversationId);
    final newState = Map<int, bool>.from(state);
    newState.remove(conversationId);
    state = newState;
  }
  
  /// Get typing status for a conversation
  bool isTyping(int conversationId) {
    return state[conversationId] ?? false;
  }
  
  /// Clear typing status for a conversation
  void clearTyping(int conversationId) {
    _typingTimers[conversationId]?.cancel();
    _typingTimers.remove(conversationId);
    final newState = Map<int, bool>.from(state);
    newState[conversationId] = false;
    state = newState;
  }
  
  @override
  void dispose() {
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _subscribedConversations.clear();
    super.dispose();
  }
}

class RecordingStatusNotifier extends StateNotifier<Map<int, bool>> {
  final Ref _ref;
  RecordingStatusNotifier(this._ref) : super({}) {
    _initializeListener();
  }
  
  PusherService? _pusherService;
  final Set<int> _subscribedConversations = {};
  
  void _initializeListener() async {
    // Get or create PusherService instance
    _pusherService = PusherService();
    await _pusherService!.connect();
  }
  
  /// Subscribe to recording events for a conversation
  void subscribeToConversation(int conversationId) {
    if (_subscribedConversations.contains(conversationId)) {
      return; // Already subscribed
    }
    
    if (_pusherService == null) {
      _initializeListener();
      return;
    }
    
    _subscribedConversations.add(conversationId);
    
    // Listen for recording events on this conversation channel
    _pusherService!.listen(
      'conversation.$conversationId',
      'UserRecording',
      (data) {
        if (data is Map) {
          final userId = data['user_id'] as int?;
          final isRecording = data['is_recording'] as bool? ?? false;
          
          // Get current user ID to ignore own recording
          final currentUserAsync = _ref.read(currentUserProvider.future);
          currentUserAsync.then((currentUser) {
            // Only track recording from other users
            if (userId != null && userId != currentUser.id) {
              // Update recording status
              final newState = Map<int, bool>.from(state);
              newState[conversationId] = isRecording;
              state = newState;
            }
          });
        }
      },
    );
  }
  
  /// Subscribe to multiple conversations at once
  void subscribeToConversations(List<int> conversationIds) {
    for (final id in conversationIds) {
      subscribeToConversation(id);
    }
  }
  
  /// Unsubscribe from recording events for a conversation
  void unsubscribeFromConversation(int conversationId) {
    _subscribedConversations.remove(conversationId);
    final newState = Map<int, bool>.from(state);
    newState.remove(conversationId);
    state = newState;
  }
  
  /// Get recording status for a conversation
  bool isRecording(int conversationId) {
    return state[conversationId] ?? false;
  }
  
  /// Clear recording status for a conversation
  void clearRecording(int conversationId) {
    final newState = Map<int, bool>.from(state);
    newState[conversationId] = false;
    state = newState;
  }
  
  @override
  void dispose() {
    _subscribedConversations.clear();
    super.dispose();
  }
}
