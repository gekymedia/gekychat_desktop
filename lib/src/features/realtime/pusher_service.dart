import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pusher_client/pusher_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class PusherService {
  PusherClient? _pusher;
  bool _isConnected = false;
  bool _usePolling = false; // Fallback to polling on Windows
  final Map<String, Channel> _subscribedChannels = {};
  final Map<String, Function(dynamic)> _listeners = {};
  final Map<String, Timer> _pollingTimers = {}; // Polling timers for Windows fallback
  late final Dio _dio;

  late final String _pusherKey;
  late final String _pusherCluster;
  late final String _pusherHost;
  late final bool _pusherEncrypted;
  late final String _authEndpoint;

  PusherService() {
    _loadConfiguration();
    _initializeDio();
    // Detect Windows platform - Pusher doesn't work on Windows
    _usePolling = Platform.isWindows;
    if (_usePolling) {
      debugPrint('⚠️ Windows detected - using polling fallback instead of Pusher');
    }
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
    if (_isConnected && (_pusher != null || _usePolling)) {
      debugPrint('🔌 Already connected');
      return;
    }

    // On Windows, skip Pusher and use polling
    if (_usePolling) {
      debugPrint('🔄 Using polling fallback (Windows platform)');
      _isConnected = true;
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
    } catch (e, stackTrace) {
      // If MissingPluginException on Windows, fall back to polling
      if (e.toString().contains('MissingPluginException') || Platform.isWindows) {
        debugPrint('⚠️ Pusher not available, falling back to polling: $e');
        _usePolling = true;
        _isConnected = true;
      } else {
        debugPrint('❌ Error connecting to Pusher: $e');
        debugPrint('Stack trace: $stackTrace');
      }
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
    if (!_isConnected) {
      debugPrint('⚠️ Not connected yet');
      return;
    }

    final channelName = channel.startsWith('private-') || channel.startsWith('public-') 
        ? channel 
        : 'private-$channel';
    
    // If using polling fallback, set up polling instead of Pusher
    if (_usePolling) {
      _setupPolling(channelName, event, callback);
      return;
    }

    if (_pusher == null) {
      debugPrint('⚠️ Pusher not initialized');
      return;
    }

    final normalizedEvent = event.startsWith('.') ? event : '.$event';
    
    Channel? pusherChannel = _subscribedChannels[channelName];
    if (pusherChannel == null) {
      debugPrint('⚠️ Channel $channelName not subscribed. Subscribing now...');
      try {
        pusherChannel = _pusher!.subscribe(channelName);
        _subscribedChannels[channelName] = pusherChannel;
      } catch (e) {
        debugPrint('❌ Error subscribing to channel: $e');
        // Fall back to polling if Pusher fails
        _usePolling = true;
        _setupPolling(channelName, event, callback);
        return;
      }
    }

    try {
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
    } catch (e) {
      debugPrint('❌ Error binding to event: $e');
      // Fall back to polling
      _usePolling = true;
      _setupPolling(channelName, event, callback);
    }
  }

  /// Set up polling fallback for Windows or when Pusher fails
  void _setupPolling(String channelName, String event, Function(dynamic) callback) {
    // Stop existing polling timer for this channel/event combo
    final timerKey = '$channelName:$event';
    _pollingTimers[timerKey]?.cancel();
    
    debugPrint('🔄 Setting up polling for $channelName:$event');
    
    // Store listener
    _listeners[channelName] = callback;
    
    // Extract conversation/group ID from channel name
    // Format: conversation.123 or group.123
    final parts = channelName.replaceFirst('private-', '').split('.');
    if (parts.length < 2) {
      debugPrint('⚠️ Could not parse channel name for polling: $channelName');
      return;
    }
    
    final type = parts[0]; // 'conversation' or 'group'
    final id = int.tryParse(parts[1]);
    if (id == null) {
      debugPrint('⚠️ Could not parse ID from channel: $channelName');
      return;
    }
    
    // Start polling based on event type
    if (event == 'MessageSent') {
      _startMessagePolling(type, id, callback);
    } else if (event == 'UserTyping') {
      _startTypingPolling(type, id, callback);
    }
  }

  /// Poll for new messages
  void _startMessagePolling(String type, int id, Function(dynamic) callback) async {
    final timerKey = '${type}.$id:MessageSent';
    int? lastMessageId;
    
    // Get API base URL
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000/api/v1';
    final baseUrl = apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    
    _pollingTimers[timerKey] = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final token = await _getAuthToken();
        if (token == null) return;
        
        final endpoint = type == 'conversation' 
            ? '$baseUrl/api/v1/conversations/$id/messages'
            : '$baseUrl/api/v1/groups/$id/messages';
        
        final response = await _dio.get(
          endpoint,
          queryParameters: lastMessageId != null 
              ? {'after': lastMessageId.toString(), 'limit': 10}
              : {'limit': 1},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ),
        );
        
        if (response.data != null) {
          final data = response.data;
          final messages = data['data'] ?? data;
          
          if (messages is List && messages.isNotEmpty) {
            // Process new messages
            for (final msgData in messages) {
              final msgId = msgData['id'];
              final msgIdInt = msgId is int ? msgId : (msgId is num ? msgId.toInt() : null);
              if (msgIdInt != null) {
                final currentLastId = lastMessageId ?? 0;
                if (msgIdInt > currentLastId) {
                  lastMessageId = msgIdInt;
                  callback(msgData);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Polling error: $e');
      }
    });
  }

  /// Poll for typing indicators
  void _startTypingPolling(String type, int id, Function(dynamic) callback) {
    // Typing indicators are less critical, poll less frequently
    final timerKey = '${type}.$id:UserTyping';
    _pollingTimers[timerKey] = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // Typing indicators are typically handled client-side
      // This is a placeholder - typing polling can be implemented if needed
    });
  }

  Future<void> unsubscribe(String channel) async {
    final channelName = channel.startsWith('private-') || channel.startsWith('public-') 
        ? channel 
        : 'private-$channel';

    // Stop polling timers for this channel
    _pollingTimers.removeWhere((key, timer) {
      if (key.startsWith(channelName)) {
        timer.cancel();
        return true;
      }
      return false;
    });

    if (_pusher != null) {
      try {
        await _pusher!.unsubscribe(channelName);
      } catch (e) {
        debugPrint('⚠️ Error unsubscribing from Pusher: $e');
      }
    }
    
    _subscribedChannels.remove(channelName);
    _listeners.remove(channelName);

    debugPrint('🔕 Unsubscribed from $channelName');
  }

  Future<void> disconnect() async {
    // Cancel all polling timers
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();

    if (_pusher != null) {
      try {
        await _pusher!.disconnect();
      } catch (e) {
        debugPrint('⚠️ Error disconnecting from Pusher: $e');
      }
      _pusher = null;
    }
    
    _isConnected = false;
    _subscribedChannels.clear();
    _listeners.clear();

    debugPrint('🔌 Disconnected');
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  bool get isConnected => _isConnected;
  PusherClient? get pusher => _pusher;
}


