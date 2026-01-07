import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_client/pusher_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class PusherService {
  PusherClient? _pusher;
  bool _isConnected = false;
  final Map<String, Channel> _subscribedChannels = {};
  final Map<String, Function(dynamic)> _listeners = {};
  late final Dio _dio;

  late final String _pusherKey;
  late final String _pusherCluster;
  late final String _pusherHost;
  late final bool _pusherEncrypted;
  late final String _authEndpoint;

  PusherService() {
    _loadConfiguration();
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );
  }

  void _loadConfiguration() {
    _pusherKey = dotenv.env['PUSHER_APP_KEY'] ?? dotenv.env['PUSHER_KEY'] ?? '';
    _pusherCluster = dotenv.env['PUSHER_APP_CLUSTER'] ?? dotenv.env['PUSHER_CLUSTER'] ?? 'mt1';
    _pusherHost = dotenv.env['PUSHER_HOST'] ?? 'api-${_pusherCluster}.pusher.com';
    _pusherEncrypted = dotenv.env['PUSHER_FORCE_TLS'] == 'true' || true;
    
    final authEndpoint = dotenv.env['PUSHER_AUTH_ENDPOINT'];
    if (authEndpoint != null && authEndpoint.isNotEmpty) {
      _authEndpoint = authEndpoint;
    } else {
      final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000/api/v1';
      final baseUrl = apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      _authEndpoint = '$baseUrl/broadcasting/auth';
    }
  }

  Future<void> connect() async {
    if (_isConnected && _pusher != null) {
      debugPrint('🔌 Already connected to Pusher');
      return;
    }

    if (_pusherKey.isEmpty) {
      debugPrint('❌ Pusher key not configured');
      return;
    }

    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('❌ No auth token found');
        return;
      }

      final auth = PusherAuth(
        _authEndpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final options = PusherOptions(
        auth: auth,
        cluster: _pusherCluster,
        host: _pusherHost,
        encrypted: _pusherEncrypted,
        activityTimeout: 120000,
        pongTimeout: 30000,
        maxReconnectionAttempts: 6,
        maxReconnectGapInSeconds: 30,
      );

      debugPrint('🔌 Connecting to Pusher: $_pusherHost (cluster: $_pusherCluster)');

      _pusher = PusherClient(
        _pusherKey,
        options,
        enableLogging: kDebugMode,
        autoConnect: true,
      );

      _setupEventHandlers();
    } catch (e) {
      debugPrint('❌ Error connecting to Pusher: $e');
    }
  }

  void _setupEventHandlers() {
    _pusher?.onConnectionStateChange((state) {
      if (state != null) {
        _isConnected = state.currentState == 'CONNECTED';
        if (_isConnected) {
          debugPrint('✅ Connected to Pusher WebSocket');
        } else {
          debugPrint('❌ Disconnected from Pusher: ${state.currentState}');
        }
      }
    });

    _pusher?.onConnectionError((error) {
      debugPrint('❌ Pusher connection error: ${error?.message}');
    });
  }

  Future<void> subscribePrivate(String channel, Function(dynamic) callback) async {
    if (!_isConnected && _pusher == null) {
      debugPrint('⚠️ Not connected, connecting first...');
      await connect();
    }

    final channelName = channel.startsWith('private-') 
        ? channel 
        : 'private-$channel';
    
    try {
      if (_subscribedChannels.containsKey(channelName)) {
        debugPrint('⚠️ Already subscribed to $channelName');
        return;
      }

      final pusherChannel = _pusher!.subscribe(channelName);
      _subscribedChannels[channelName] = pusherChannel;
      _listeners[channelName] = callback;

      debugPrint('✅ Subscribed to $channelName');
    } catch (e) {
      debugPrint('❌ Error subscribing to $channelName: $e');
    }
  }

  void subscribePublic(String channel, Function(dynamic) callback) {
    if (!_isConnected || _pusher == null) {
      debugPrint('⚠️ Not connected yet');
      return;
    }

    final channelName = 'public-$channel';
    
    try {
      if (_subscribedChannels.containsKey(channelName)) {
        debugPrint('⚠️ Already subscribed to $channelName');
        return;
      }

      final pusherChannel = _pusher!.subscribe(channelName);
      _subscribedChannels[channelName] = pusherChannel;
      _listeners[channelName] = callback;

      debugPrint('✅ Subscribed to $channelName');
    } catch (e) {
      debugPrint('❌ Error subscribing to $channelName: $e');
    }
  }

  void listen(String channel, String event, Function(dynamic) callback) {
    if (!_isConnected || _pusher == null) {
      debugPrint('⚠️ Not connected yet');
      return;
    }

    final channelName = channel.startsWith('private-') || channel.startsWith('public-') 
        ? channel 
        : 'private-$channel';
    
    final normalizedEvent = event.startsWith('.') ? event : '.$event';
    
    Channel? pusherChannel = _subscribedChannels[channelName];
    if (pusherChannel == null) {
      debugPrint('⚠️ Channel $channelName not subscribed. Subscribing now...');
      pusherChannel = _pusher!.subscribe(channelName);
      _subscribedChannels[channelName] = pusherChannel;
    }

    pusherChannel.bind(normalizedEvent, (pusherEvent) {
      debugPrint('👂 Received event $normalizedEvent on $channelName');
      try {
        dynamic data = pusherEvent?.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            debugPrint('⚠️ Could not parse event data as JSON: $e');
          }
        }
        callback(data);
        final channelCallback = _listeners[channelName];
        if (channelCallback != null) {
          channelCallback(data);
        }
      } catch (e) {
        debugPrint('❌ Error handling event $normalizedEvent: $e');
      }
    });
    
    if (normalizedEvent.startsWith('.')) {
      final eventWithoutDot = normalizedEvent.substring(1);
      pusherChannel.bind(eventWithoutDot, (pusherEvent) {
        debugPrint('👂 Received event $eventWithoutDot on $channelName (compat mode)');
        try {
          dynamic data = pusherEvent?.data;
          if (data is String) {
            try {
              data = jsonDecode(data);
            } catch (e) {
              debugPrint('⚠️ Could not parse event data as JSON: $e');
            }
          }
          callback(data);
        } catch (e) {
          debugPrint('❌ Error handling event $eventWithoutDot: $e');
        }
      });
    }
  }

  Future<void> unsubscribe(String channel) async {
    if (_pusher == null) return;

    final channelName = channel.startsWith('private-') || channel.startsWith('public-') 
        ? channel 
        : 'private-$channel';

    await _pusher!.unsubscribe(channelName);
    _subscribedChannels.remove(channelName);
    _listeners.remove(channelName);

    debugPrint('🔕 Unsubscribed from $channelName');
  }

  Future<void> disconnect() async {
    if (_pusher == null) return;

    await _pusher!.disconnect();
    _pusher = null;
    _isConnected = false;
    _subscribedChannels.clear();
    _listeners.clear();

    debugPrint('🔌 Disconnected from Pusher');
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  bool get isConnected => _isConnected;
  PusherClient? get pusher => _pusher;
}


