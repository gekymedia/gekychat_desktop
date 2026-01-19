// lib/src/features/calls/call_repository.dart
import '../../core/api_service.dart';
import 'models.dart';

class CallRepository {
  final ApiService _api;

  CallRepository(this._api);

  /// Start a call (voice or video)
  /// Returns call session with session_id and call_link
  Future<Map<String, dynamic>> startCall({
    int? calleeId,
    int? groupId,
    int? conversationId,
    required String type, // 'voice' or 'video'
  }) async {
    try {
      final data = <String, dynamic>{
        'type': type,
      };
      
      if (calleeId != null) data['callee_id'] = calleeId;
      if (groupId != null) data['group_id'] = groupId;
      if (conversationId != null) data['conversation_id'] = conversationId;

      final response = await _api.post('/calls/start', data: data);
      return response.data;
    } catch (e) {
      throw Exception('Failed to start call: $e');
    }
  }

  /// Send WebRTC signaling data (offer/answer/ICE candidate)
  /// payload should be a JSON string
  Future<void> sendSignal(int sessionId, String payload) async {
    try {
      await _api.post('/calls/$sessionId/signal', data: {
        'payload': payload,
      });
    } catch (e) {
      throw Exception('Failed to send signal: $e');
    }
  }

  /// End a call
  Future<void> endCall(int sessionId) async {
    try {
      await _api.post('/calls/$sessionId/end');
    } catch (e) {
      throw Exception('Failed to end call: $e');
    }
  }

  /// Join an existing call by call ID
  Future<Map<String, dynamic>> joinCall(String callId) async {
    try {
      final response = await _api.get('/calls/join/$callId');
      return response.data;
    } catch (e) {
      throw Exception('Failed to join call: $e');
    }
  }

  /// Get call logs (existing method)
  Future<List<CallLog>> getCallLogs() async {
    try {
      final response = await _api.get('/calls');
      final data = response.data;
      final callsData = data['data'] is List ? data['data'] as List : [];
      return callsData.map((json) => CallLog.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load call logs: $e');
    }
  }

  /// PHASE 1: Get TURN/ICE server configuration
  Future<Map<String, dynamic>> getCallConfig() async {
    try {
      final response = await _api.get('/calls/config');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get call config: $e');
    }
  }
}

