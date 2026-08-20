import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/api_service.dart';

/// Builds LiveKit [RTCConfiguration] from GET /calls/config (STUN + optional TURN).
///
/// LiveKit also advertises ICE servers from the SFU join response. Extra client
/// servers help on strict NATs when the LiveKit node has incomplete TURN.
Future<RTCConfiguration> fetchLiveKitRtcConfiguration(ApiService api) async {
  final servers = <RTCIceServer>[
    const RTCIceServer(urls: ['stun:stun.l.google.com:19302']),
    const RTCIceServer(urls: ['stun:stun1.l.google.com:19302']),
  ];

  try {
    final response = await api.get('/calls/config');
    final data = response.data;
    if (data is! Map) return RTCConfiguration(iceServers: servers);

    final config = data['config'];
    if (config is! Map) return RTCConfiguration(iceServers: servers);

    final stun = config['stun'];
    if (stun is List) {
      for (final entry in stun) {
        final urls = _urlsFromIceEntry(entry);
        if (urls.isNotEmpty) {
          servers.add(RTCIceServer(urls: urls));
        }
      }
    }

    final turn = config['turn'];
    if (turn is List) {
      for (final entry in turn) {
        if (entry is! Map) continue;
        final urls = _urlsFromIceEntry(entry);
        if (urls.isEmpty) continue;
        final username = entry['username']?.toString();
        final credential = entry['credential']?.toString();
        servers.add(
          RTCIceServer(
            urls: urls,
            username: (username != null && username.isNotEmpty) ? username : null,
            credential:
                (credential != null && credential.isNotEmpty) ? credential : null,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('fetchLiveKitRtcConfiguration: $e');
  }

  // De-dupe by url list string.
  final seen = <String>{};
  final unique = <RTCIceServer>[];
  for (final s in servers) {
    final key = (s.urls ?? const []).join('|');
    if (key.isEmpty || !seen.add(key)) continue;
    unique.add(s);
  }

  return RTCConfiguration(iceServers: unique);
}

List<String> _urlsFromIceEntry(Object? entry) {
  if (entry is Map) {
    final urls = entry['urls'];
    if (urls is String && urls.trim().isNotEmpty) return [urls.trim()];
    if (urls is List) {
      return urls
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }
  return const [];
}

/// User-facing copy for LiveKit / WebRTC connect failures.
String friendlyLiveKitConnectError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('mediaconnectexception') ||
      lower.contains('ice connectivity') ||
      lower.contains('peerconnection') ||
      lower.contains('timed out waiting for peerconnection')) {
    return 'Could not establish a media connection (ICE). '
        'Check firewall/VPN, or ask an admin to enable TURN on the LiveKit server.';
  }
  if (lower.contains('unauthorized') || lower.contains('403')) {
    return 'Call credentials expired. Leave and join the call again.';
  }
  if (lower.contains('socket') || lower.contains('websocket')) {
    return 'Could not reach the call server. Check your internet connection.';
  }
  if (raw.length > 160) {
    return '${raw.substring(0, 157)}…';
  }
  return raw;
}
