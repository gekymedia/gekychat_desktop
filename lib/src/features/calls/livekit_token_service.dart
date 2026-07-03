// lib/src/features/calls/livekit_token_service.dart
import '../../core/api_service.dart';

class LiveKitTokenResult {
  final String url;
  final String token;
  final String roomName;

  const LiveKitTokenResult({
    required this.url,
    required this.token,
    required this.roomName,
  });
}

class LiveKitTokenService {
  final ApiService _api;

  LiveKitTokenService(this._api);

  Future<LiveKitTokenResult> fetchToken({
    required String roomName,
    required String displayName,
  }) async {
    final response = await _api.get(
      '/calls/livekit-token',
      queryParameters: {'room': roomName, 'name': displayName},
    );
    final data = response.data as Map<String, dynamic>;
    return LiveKitTokenResult(
      url: data['url'] as String,
      token: data['token'] as String,
      roomName: roomName,
    );
  }
}
