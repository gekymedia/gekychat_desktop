import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final response = await _apiService.joinLiveBroadcast(id);
    return Map<String, dynamic>.from(response.data);
  }

  /// End a live broadcast
  Future<void> endBroadcast(int id) async {
    await _apiService.endLiveBroadcast(id);
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
}

final liveBroadcastRepositoryProvider = Provider<LiveBroadcastRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return LiveBroadcastRepository(apiService);
});

