import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_service.dart';
import '../../core/device_id.dart';
import '../../core/installation_id.dart';
import '../../services/product_analytics_service.dart';
import 'call_phone_guard.dart';
import 'models.dart';

class CallJoinException implements Exception {
  final String userMessage;
  const CallJoinException(this.userMessage);

  @override
  String toString() => userMessage;
}

class CallStartException implements Exception {
  final String userMessage;
  const CallStartException(this.userMessage);

  @override
  String toString() => userMessage;
}

class CallRepository {
  final ApiService _api;

  CallRepository(this._api);

  Future<Map<String, dynamic>> startCall({
    int? calleeId,
    int? groupId,
    int? conversationId,
    required String type,
  }) async {
    await requireCallerPhoneOnFile();
    try {
      final data = <String, dynamic>{'type': type};

      if (calleeId != null) data['callee_id'] = calleeId;
      if (groupId != null) data['group_id'] = groupId;
      if (conversationId != null) data['conversation_id'] = conversationId;

      final response = await _api.post('/calls/start', data: data);
      final result = response.data as Map<String, dynamic>;
      if (result['status'] == 'success') {
        ProductAnalytics.action(
          'call_started',
          feature: 'calls',
          properties: {
            'type': type,
            if (result['session_id'] != null) 'session_id': result['session_id'],
          },
        );
      }
      return result;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      if (status == 409) {
        throw const CallStartException(
          'User is busy on another call. Try again later.',
        );
      }
      if (status == 422 && body is Map) {
        final code = body['code'];
        if (code == 'caller_phone_required' || code == 'callee_phone_required') {
          final message = body['message'];
          throw CallStartException(
            message is String && message.isNotEmpty
                ? message
                : 'A phone number is required to place this call.',
          );
        }
      }
      if (body is Map) {
        final busy = body['status'] == 'busy' ||
            body['call_status'] == 'busy' ||
            body['reason'] == 'busy';
        if (busy) {
          throw const CallStartException(
            'User is busy on another call. Try again later.',
          );
        }
      }
      throw Exception('Failed to start call: $e');
    } catch (e) {
      if (e is CallStartException) rethrow;
      throw Exception('Failed to start call: $e');
    }
  }

  Future<void> sendSignal(int sessionId, String payload) async {
    try {
      await _api.post('/calls/$sessionId/signal', data: {
        'payload': payload,
      });
    } catch (e) {
      throw Exception('Failed to send signal: $e');
    }
  }

  Future<void> endCall(int sessionId, {String? reason}) async {
    try {
      final data = reason != null && reason.isNotEmpty
          ? <String, dynamic>{'reason': reason}
          : null;
      await _api.post('/calls/$sessionId/end', data: data);
    } catch (e) {
      throw Exception('Failed to end call: $e');
    }
  }

  Future<void> declineCall(int sessionId) async {
    try {
      await _api.post('/calls/$sessionId/decline');
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final data = e.response?.data;
        final message = data is Map ? data['message']?.toString() ?? '' : '';
        if (message.contains('Group calls do not use decline')) {
          return;
        }
      }
      throw Exception('Failed to decline call: $e');
    } catch (e) {
      throw Exception('Failed to decline call: $e');
    }
  }

  Future<void> leaveCall(int sessionId) async {
    try {
      await _api.post('/calls/$sessionId/leave');
    } catch (e) {
      throw Exception('Failed to leave call: $e');
    }
  }

  /// Mark participant joined on server before / when opening LiveKit.
  Future<void> acceptIncomingCallSession(int sessionId) async {
    const delays = [
      Duration.zero,
      Duration(milliseconds: 400),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1800),
      Duration(milliseconds: 3500),
    ];
    // Lets the server exclude THIS device from the "stop ringing on other
    // devices" cancel it broadcasts on accept — without it, that cancel also
    // reaches (and can tear down) the very device that just answered.
    String? installationId;
    String? deviceId;
    try {
      installationId = await getOrCreateInstallationId();
      deviceId = await getOrCreateDeviceId();
    } catch (_) {}
    final identifiers = <String, dynamic>{
      if (installationId != null && installationId.isNotEmpty)
        'installation_id': installationId,
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    };
    Object? lastError;
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }
      try {
        await _api.post(
          '/calls/$sessionId/join-call',
          data: identifiers.isNotEmpty ? identifiers : null,
        );
        return;
      } catch (e) {
        lastError = e;
        debugPrint(
          'acceptIncomingCallSession($sessionId) attempt failed: $e',
        );
      }
    }
    debugPrint(
      'acceptIncomingCallSession($sessionId) failed after retries: $lastError',
    );
  }

  Future<String?> fetchCallSessionStatus(int sessionId) async {
    try {
      final response = await _api.get('/calls/$sessionId/status');
      final data = response.data;
      if (data is Map) {
        return data['call_status'] as String?;
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 410) {
        return 'ended';
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> joinCall(String callId) async {
    try {
      final response = await _api.get('/calls/join/$callId');
      return response.data;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 410 || statusCode == 404) {
        throw const CallJoinException(
          'This call is no longer available. It may have ended already.',
        );
      }
      if (statusCode == 409) {
        throw const CallJoinException(
          'Unable to join this call right now. Please try again.',
        );
      }
      throw const CallJoinException(
        'Unable to join call. Check your connection and try again.',
      );
    } catch (e) {
      if (e is CallJoinException) rethrow;
      throw const CallJoinException(
        'Unable to join call. Please try again.',
      );
    }
  }

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

  Future<void> submitCallRating({
    required int sessionId,
    required int rating,
    List<String>? issues,
    String? comment,
    String? callType,
    int? durationSeconds,
    Map<String, dynamic>? clientMeta,
  }) async {
    try {
      final data = <String, dynamic>{'rating': rating};
      if (issues != null && issues.isNotEmpty) data['issues'] = issues;
      if (comment != null && comment.isNotEmpty) data['comment'] = comment;
      if (callType != null && callType.isNotEmpty) data['call_type'] = callType;
      if (durationSeconds != null) data['duration_seconds'] = durationSeconds;
      if (clientMeta != null && clientMeta.isNotEmpty) {
        data['client_meta'] = clientMeta;
      }
      await _api.post('/calls/$sessionId/rate', data: data);
    } catch (e) {
      throw Exception('Failed to submit call rating: $e');
    }
  }

  /// Offline ring recovery when the app comes back online.
  Future<Map<String, dynamic>> getPendingInvite() async {
    try {
      final response = await _api.get('/calls/pending-invite');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'invite': null};
    }
  }
}
