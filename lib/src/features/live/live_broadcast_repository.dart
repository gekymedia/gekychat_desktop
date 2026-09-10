import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/providers.dart';

/// Thrown when [LiveBroadcastRepository.joinBroadcast] fails; [message] is safe to show in UI.
class LiveBroadcastJoinException implements Exception {
  LiveBroadcastJoinException(this.message, {this.errorCode});

  final String message;
  final String? errorCode;

  @override
  String toString() => message;
}

/// PHASE 2: Live Broadcast Repository
class LiveBroadcastRepository {
  final ApiService _apiService;

  LiveBroadcastRepository(this._apiService);

  /// Start a live broadcast
  Future<Map<String, dynamic>> startBroadcast({String? title}) async {
    final response = await _apiService.startLiveBroadcast(title: title ?? '');
    return Map<String, dynamic>.from(response.data);
  }

  /// Join a live broadcast
  Future<Map<String, dynamic>> joinBroadcast(int id) async {
    try {
      final response = await _apiService.joinLiveBroadcast(id);
      final raw = response.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      throw LiveBroadcastJoinException('Invalid join response.');
    } on DioException catch (e) {
      throw _joinFailureFromDio(e);
    }
  }

  LiveBroadcastJoinException _joinFailureFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['error_code']?.toString();
      final m = data['message']?.toString();
      if (m != null && m.isNotEmpty) {
        return LiveBroadcastJoinException(m, errorCode: code);
      }
    }
    switch (e.response?.statusCode) {
      case 410:
        return LiveBroadcastJoinException(
          'This live has ended.',
          errorCode: 'BROADCAST_ENDED',
        );
      case 404:
        return LiveBroadcastJoinException(
          'This broadcast is no longer available.',
          errorCode: 'BROADCAST_NOT_FOUND',
        );
      default:
        break;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return LiveBroadcastJoinException(
        'Could not join the live. Check your connection and try again.',
      );
    }
    return LiveBroadcastJoinException(
      'Could not join the live. Please try again.',
    );
  }

  /// End a live broadcast
  Future<void> endBroadcast(int id) async {
    await _apiService.endLiveBroadcast(id);
  }

  /// Creator dashboard: total broadcasts, views, watch time, recent list.
  Future<Map<String, dynamic>> getCreatorAnalytics() async {
    final response = await _apiService.getLiveCreatorAnalytics();
    if (response.data is Map && response.data['data'] != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    return {};
  }

  /// Get active broadcasts
  Future<List<Map<String, dynamic>>> getActiveBroadcasts() async {
    final response = await _apiService.getActiveLiveBroadcasts();
    if (response.data is Map && response.data['data'] != null) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    return [];
  }

  /// Send chat message in live broadcast
  Future<void> sendChatMessage(int id, {required String message}) async {
    await _apiService.sendLiveBroadcastChat(id, message: message);
  }

  /// Lightweight counters/status refresh used as fallback when a realtime event is missed.
  Future<Map<String, dynamic>> getBroadcastStats(int broadcastId) async {
    final response = await _apiService.getLiveBroadcastStats(broadcastId);
    final raw = response.data;
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  /// Get LiveKit token for joining broadcast
  Future<String> getLiveKitToken({
    required String roomName,
    required String role, // 'publisher' or 'viewer'
  }) async {
    final response = await _apiService.getLiveKitToken(
      roomName: roomName,
      role: role,
    );
    return response.data['token'] as String;
  }

  Future<Map<String, dynamic>> startRecording(int id) async {
    final response = await _apiService.startLiveEgressRecord(id);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> startRtmpOut(int id, {required String rtmpUrl}) async {
    final response =
        await _apiService.startLiveEgressRtmp(id, rtmpUrl: rtmpUrl);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> stopEgress(int id) async {
    final response = await _apiService.stopLiveEgress(id);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createIngress(int id) async {
    final response = await _apiService.createLiveIngress(id);
    return Map<String, dynamic>.from(response.data as Map);
  }
}

final liveBroadcastRepositoryProvider = Provider<LiveBroadcastRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return LiveBroadcastRepository(apiService);
});

