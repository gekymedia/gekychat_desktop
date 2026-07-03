// lib/src/features/realtime/pusher_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pusher_client_socket/pusher_client_socket.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/connectivity_service.dart';

/// Pusher/Reverb WebSocket Service for real-time communication
/// Uses pusher_client_socket package which supports self-hosted servers like Laravel Reverb

/// Helper class to queue listeners until Pusher is connected
class _QueuedListener {
  final String channel;
  final String event;
  final Function(dynamic) callback;
  
  _QueuedListener(this.channel, this.event, this.callback);
}

/// Tracks listeners registered by a view so dispose removes only its callbacks.
class PusherListenerRegistry {
  final List<({String channel, String event, void Function(dynamic) callback})>
      _entries = [];

  void listen(
    PusherService pusher,
    String channel,
    String event,
    void Function(dynamic) callback,
  ) {
    pusher.listen(channel, event, callback);
    _entries.add((channel: channel, event: event, callback: callback));
  }

  void removeAll(PusherService? pusher) {
    if (pusher == null) return;
    for (final entry in _entries) {
      pusher.removeListener(entry.channel, entry.event, entry.callback);
    }
    _entries.clear();
  }
}

class PusherService {
  /// Laravel public broadcast channels (not private- prefixed).
  static const Set<String> _publicChannelNames = {
    'status.updates',
    'live-broadcasts',
  };

  PusherClient? _pusher;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  /// Soft cap for exponential backoff; does not permanently stop reconnects (see [resetReconnectPolicyAndConnect] on app resume).
  static const int _maxReconnectAttempts = 32;
  Timer? _reconnectTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  DateTime? _lastReconnectAttempt;
  Timer? _connectivityDebounceTimer;
  final Map<String, Channel> _subscribedChannels = {};
  final Map<String, Function(dynamic)> _listeners = {};
  final Map<String, Map<String, List<Function(dynamic)>>> _eventListeners = {};
  final Map<String, Set<String>> _boundEvents = {};
  final List<_QueuedListener> _queuedListeners = [];

  late final String _pusherKey;
  late final String _pusherCluster;
  late final String _authEndpoint;
  late final String? _customHost;
  late final int _wsPort;
  late final int _wssPort;
  late final bool _useTLS;

  PusherService() {
    _loadConfiguration();
    _setupConnectivityListener();
  }
  
  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivityDebounceTimer?.cancel();
    
    _connectivitySubscription = ConnectivityService.connectivityStream.listen((result) {
      _connectivityDebounceTimer?.cancel();
      _connectivityDebounceTimer = Timer(const Duration(seconds: 2), () {
        _handleConnectivityChange(result);
      });
    });
  }
  
  void _handleConnectivityChange(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      if (_isConnected) {
        debugPrint('📡 Network lost, Pusher will reconnect when network is restored');
        _isConnected = false;
      }
      return;
    }
    
    if (_isConnected || _isConnecting || !_shouldReconnect) {
      return;
    }
    
    final now = DateTime.now();
    if (_lastReconnectAttempt != null) {
      final timeSinceLastAttempt = now.difference(_lastReconnectAttempt!);
      if (timeSinceLastAttempt.inSeconds < 5) {
        debugPrint('⏳ Reconnection rate limited (last attempt ${timeSinceLastAttempt.inSeconds}s ago)');
        return;
      }
    }
    
    ConnectivityService.hasInternetConnection().then((hasInternet) {
      if (hasInternet && !_isConnected && !_isConnecting && _shouldReconnect) {
        debugPrint('📡 Network restored, attempting Pusher reconnection...');
        _lastReconnectAttempt = DateTime.now();
        _reconnectAttempts = 0;
        connect().catchError((e) {
          debugPrint('⚠️ Reconnection after network restore failed: $e');
        });
      }
    });
  }

  static const String _productionApiBaseUrl =
      'https://chat.gekychat.com/api/v1';

  void _loadConfiguration() {
    _pusherKey =
        dotenv.env['PUSHER_APP_KEY'] ?? dotenv.env['PUSHER_KEY'] ?? '';
    _pusherCluster =
        dotenv.env['PUSHER_APP_CLUSTER'] ?? dotenv.env['PUSHER_CLUSTER'] ?? 'mt1';

    // Self-hosted Reverb when REVERB_HOST (or PUSHER_HOST) is set — must match BROADCAST_DRIVER=reverb.
    final reverbHost = dotenv.env['REVERB_HOST'] ?? dotenv.env['PUSHER_HOST'];
    _customHost =
        (reverbHost != null && reverbHost.trim().isNotEmpty) ? reverbHost.trim() : null;

    final wsPortStr = dotenv.env['REVERB_PORT'] ?? dotenv.env['PUSHER_WSS_PORT'];
    _wssPort = wsPortStr != null ? int.tryParse(wsPortStr) ?? 443 : 443;
    _wsPort = int.tryParse(dotenv.env['PUSHER_WS_PORT'] ?? '') ?? 80;

    final reverbScheme = (dotenv.env['REVERB_SCHEME'] ?? '').trim().toLowerCase();
    final forceTlsRaw = (dotenv.env['PUSHER_FORCE_TLS'] ?? '').trim().toLowerCase();
    if (reverbScheme == 'https') {
      _useTLS = true;
    } else if (reverbScheme == 'http') {
      _useTLS = false;
    } else if (forceTlsRaw == 'true' || forceTlsRaw == '1') {
      _useTLS = true;
    } else if (forceTlsRaw == 'false' || forceTlsRaw == '0') {
      _useTLS = false;
    } else {
      _useTLS = _wssPort == 443;
    }

    if (_customHost != null &&
        !_useTLS &&
        _wsPort != 80 &&
        reverbScheme.isEmpty &&
        forceTlsRaw.isEmpty) {
      debugPrint(
        '⚠️ Pusher: plain WS on port $_wsPort — if connection times out, set REVERB_SCHEME=https or PUSHER_FORCE_TLS=true in .env',
      );
    }

    final authEndpoint = dotenv.env['PUSHER_AUTH_ENDPOINT'];
    if (authEndpoint != null && authEndpoint.isNotEmpty) {
      _authEndpoint = authEndpoint;
    } else {
      final apiBaseUrl =
          dotenv.env['API_BASE_URL'] ?? _productionApiBaseUrl;
      final base = apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
      _authEndpoint = '${base}broadcasting/auth';
    }

    if (_pusherKey.isEmpty) {
      debugPrint('❌ Pusher key not configured — realtime will not work');
    }
    final mode = _customHost != null ? 'Reverb@$_customHost' : 'PusherCloud($_pusherCluster)';
    debugPrint(
      '🔧 Pusher config: mode=$mode, key=${_pusherKey.isEmpty ? "(missing)" : "${_pusherKey.substring(0, _pusherKey.length.clamp(0, 8))}..."}, wsPort=$_wsPort, wssPort=$_wssPort, tls=$_useTLS, auth=$_authEndpoint',
    );
  }

  bool _isPublicChannel(String name) => _publicChannelNames.contains(name);

  /// Storage key used in [_subscribedChannels] / [_eventListeners].
  String _channelStorageKey(String channel) {
    if (channel.startsWith('private-')) return channel;
    if (channel.startsWith('public-')) return channel.substring(7);
    if (_isPublicChannel(channel)) return channel;
    return 'private-$channel';
  }

  Channel _openChannel(String storageKey) {
    if (_isPublicChannel(storageKey)) {
      return _pusher!.channel(storageKey);
    }
    return _pusher!.private(storageKey.replaceFirst('private-', ''));
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    return {
      'Accept': 'application/json',
      // pusher_client_socket posts socket_id/channel_name as form fields — not JSON.
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> connect() async {
    final hasInternet = await ConnectivityService.hasInternetConnection();
    if (!hasInternet) {
      debugPrint('📡 No internet connection, skipping Pusher connection');
      return;
    }
    
    if (_isConnected && _pusher != null) {
      unawaited(_processQueuedListeners());
      return;
    }
    
    if (_isConnecting) {
      debugPrint('⏳ Pusher connection already in progress, skipping...');
      return;
    }
    
    if (_pusherKey.isEmpty) {
      debugPrint('❌ Pusher key not configured');
      return;
    }

    _isConnecting = true;
    _reconnectAttempts++;

    try {
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('❌ No auth token found');
        _isConnecting = false;
        return;
      }

      // Dispose existing instance if any
      if (_pusher != null) {
        try {
          _pusher!.disconnect();
        } catch (e) {
          debugPrint('⚠️ Error disconnecting old Pusher instance: $e');
        }
        _pusher = null;
      }

      // Configure PusherOptions for Reverb or Pusher cloud
      final PusherOptions options;
      
      final reverbHost = _customHost;
      if (reverbHost != null && reverbHost.isNotEmpty) {
        // Self-hosted Reverb server
        options = PusherOptions(
          key: _pusherKey,
          host: reverbHost,
          wsPort: _wsPort,
          wssPort: _wssPort,
          encrypted: _useTLS,
          authOptions: PusherAuthOptions(
            _authEndpoint,
            headers: _getAuthHeaders,
          ),
          autoConnect: false,
          enableLogging: kDebugMode,
        );
        debugPrint('🔌 Connecting to Reverb at $reverbHost (TLS: $_useTLS, port: ${_useTLS ? _wssPort : _wsPort})');
      } else {
        // Pusher cloud
        options = PusherOptions(
          key: _pusherKey,
          cluster: _pusherCluster,
          wsPort: _wsPort,
          wssPort: _wssPort,
          encrypted: _useTLS,
          authOptions: PusherAuthOptions(
            _authEndpoint,
            headers: _getAuthHeaders,
          ),
          autoConnect: false,
          enableLogging: kDebugMode,
        );
        debugPrint('🔌 Connecting to Pusher cloud (cluster: $_pusherCluster)');
      }

      _pusher = PusherClient(options: options);
      
      // Setup connection handlers
      _pusher!.onConnectionEstablished((data) {
        _isConnected = true;
        _isConnecting = false;
        _reconnectAttempts = 0;
        debugPrint('✅ Connected to Pusher/Reverb - socket-id: ${_pusher!.socketId}');
        unawaited(_processQueuedListeners());
      });
      
      _pusher!.onConnectionError((error) {
        debugPrint('❌ Pusher connection error: $error');
        _isConnecting = false;
        _isConnected = false;
        
        // Don't schedule reconnect for auth errors
        final errorStr = error.toString().toLowerCase();
        if (errorStr.contains('auth') || errorStr.contains('401') || errorStr.contains('403')) {
          debugPrint('🔒 Auth error detected, stopping auto-reconnect');
          _shouldReconnect = false;
          return;
        }
        
        _scheduleReconnect();
      });
      
      _pusher!.onError((error) {
        debugPrint('❌ Pusher error: $error');
        
        // Treat duplicate subscription as non-fatal
        if (error.toString().contains('Existing subscription') || 
            error.toString().contains('already subscribed')) {
          debugPrint('ℹ️ Duplicate subscription reported; skipping reconnect');
          return;
        }
      });
      
      _pusher!.onDisconnected((data) {
        debugPrint('🔌 Pusher disconnected: $data');
        _isConnected = false;
        _isConnecting = false;
        
        if (_shouldReconnect) {
          _scheduleReconnect();
        }
      });

      // Connect
      _pusher!.connect();
      
    } catch (e) {
      debugPrint('❌ Error connecting to Pusher: $e');
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }
  
  void _scheduleReconnect() {
    if (!_shouldReconnect) {
      return;
    }
    
    _reconnectTimer?.cancel();
    
    final cappedAttempt = _reconnectAttempts.clamp(0, _maxReconnectAttempts);
    final delaySeconds = cappedAttempt < 6
        ? (1 << cappedAttempt)
        : (cappedAttempt < 12 ? 60 : 120);
    
    debugPrint('⏰ Scheduling Pusher reconnection in $delaySeconds seconds (attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (!_isConnected && _shouldReconnect && !_isConnecting) {
        final hasInternet = await ConnectivityService.hasInternetConnection();
        if (hasInternet) {
          connect().catchError((e) {
            debugPrint('⚠️ Scheduled reconnection failed: $e');
          });
        } else {
          debugPrint('📡 No internet, will retry when network is restored');
        }
      }
    });
  }
  
  void _queueListener(String channel, String event, Function(dynamic) callback) {
    _queuedListeners.add(_QueuedListener(channel, event, callback));
    if (!_isConnected && _pusher == null) {
      connect().catchError((e) {
        debugPrint('⚠️ Background Pusher connection failed: $e');
      });
    }
  }

  void _addEventListener(
    String channelName,
    String eventName,
    Function(dynamic) callback,
  ) {
    final listeners = _eventListeners.putIfAbsent(channelName, () => {});
    final list = listeners.putIfAbsent(eventName, () => []);
    if (!list.contains(callback)) {
      list.add(callback);
    }
  }

  bool _channelHasListeners(String channelName) {
    final events = _eventListeners[channelName];
    if (events == null || events.isEmpty) return false;
    return events.values.any((list) => list.isNotEmpty);
  }

  /// Removes a single callback without unsubscribing the whole channel when
  /// other listeners (e.g. chats-list typing) still need it.
  void removeListener(
    String channel,
    String event,
    Function(dynamic) callback,
  ) {
    final channelName = _channelStorageKey(channel);
    final eventName = event.startsWith('.') ? event.substring(1) : event;
    final events = _eventListeners[channelName];
    final list = events?[eventName];
    if (list == null) return;

    list.remove(callback);
    if (list.isEmpty) {
      events!.remove(eventName);
    }
    if (events != null && events.isEmpty) {
      _eventListeners.remove(channelName);
    }

    if (!_channelHasListeners(channelName)) {
      unawaited(_unsubscribeChannelIfIdle(channelName));
    }
  }

  Future<void> _unsubscribeChannelIfIdle(String channelName) async {
    if (_pusher == null || _channelHasListeners(channelName)) return;
    try {
      final ch = _subscribedChannels[channelName];
      ch?.unsubscribe();
      _subscribedChannels.remove(channelName);
      _listeners.remove(channelName);
      _boundEvents.remove(channelName);
      debugPrint('🔕 Unsubscribed idle channel $channelName');
    } catch (e) {
      debugPrint('❌ Error unsubscribing idle channel: $e');
    }
  }

  void _dispatchEventListeners(
    String channelName,
    String eventName,
    dynamic data,
  ) {
    final callbacks = _eventListeners[channelName]?[eventName];
    if (callbacks == null || callbacks.isEmpty) return;
    for (final cb in List<Function(dynamic)>.from(callbacks)) {
      try {
        cb(data);
      } catch (e) {
        debugPrint('❌ Pusher listener error ($eventName on $channelName): $e');
      }
    }
  }

  void _bindEventIfNeeded(Channel channel, String channelName, String eventName) {
    final bound = _boundEvents.putIfAbsent(channelName, () => {});
    if (bound.contains(eventName)) return;
    bound.add(eventName);
    channel.bind(eventName, (data) {
      _dispatchEventListeners(channelName, eventName, data);
    });
  }
  
  Future<void> _processQueuedListeners() async {
    if (!_isConnected || _pusher == null) return;

    final queued = List<_QueuedListener>.from(_queuedListeners);
    _queuedListeners.clear();

    if (queued.isEmpty) return;

    final uniqueChannels =
        queued.map((q) => _channelStorageKey(q.channel)).toSet().toList();

    // Subscribe to channels
    for (final channelName in uniqueChannels) {
      if (_subscribedChannels.containsKey(channelName)) continue;
      try {
        final ch = _openChannel(channelName);
        _subscribedChannels[channelName] = ch;
        _listeners[channelName] = (_) {};
        debugPrint('✅ Subscribed to $channelName');
      } catch (e) {
        if (e.toString().contains('Already subscribed') || e.toString().contains('already subscribed')) {
          debugPrint('⚠️ Pusher reported already subscribed to $channelName');
        } else {
          debugPrint('❌ Error subscribing to $channelName: $e');
        }
      }
    }

    // Register event listeners
    for (final q in queued) {
      try {
        final channelName = _channelStorageKey(q.channel);
        final eventName = q.event.startsWith('.') ? q.event.substring(1) : q.event;
        
        _addEventListener(channelName, eventName, q.callback);

        final channel = _subscribedChannels[channelName];
        if (channel != null) {
          _bindEventIfNeeded(channel, channelName, eventName);
        }
        
        debugPrint('👂 Registered listener for event $eventName on channel $channelName');
      } catch (e) {
        debugPrint('❌ Error processing queued listener: $e');
      }
    }
  }

  Future<void> subscribePrivate(String channel, Function(dynamic) callback) async {
    if (!_isConnected && _pusher == null) {
      await connect();
    }

    if (_pusher == null) {
      debugPrint('❌ Pusher not initialized');
      return;
    }

    final channelName = channel.startsWith('private-') ? channel : 'private-$channel';
    
    try {
      if (_subscribedChannels.containsKey(channelName)) {
        debugPrint('⚠️ Already subscribed to $channelName, skipping duplicate subscription');
        _listeners[channelName] = callback;
        return;
      }

      final pusherChannel = _pusher!.private(channel.replaceFirst('private-', ''));
      _subscribedChannels[channelName] = pusherChannel;
      _listeners[channelName] = callback;
      debugPrint('✅ Subscribed to $channelName');
    } catch (e) {
      if (e.toString().contains('Already subscribed') || e.toString().contains('already subscribed')) {
        debugPrint('⚠️ Pusher reported already subscribed to $channelName, updating our map');
        _listeners[channelName] = callback;
      } else {
        debugPrint('❌ Error subscribing to $channelName: $e');
      }
    }
  }

  Future<void> subscribePublic(String channel, Function(dynamic) callback) async {
    if (!_isConnected && _pusher == null) {
      await connect();
    }

    if (_pusher == null) {
      debugPrint('❌ Pusher not initialized');
      return;
    }

    final channelName = channel.startsWith('public-') ? channel.substring(7) : channel;
    
    try {
      if (_subscribedChannels.containsKey(channelName)) {
        debugPrint('⚠️ Already subscribed to public channel: $channelName');
        return;
      }

      final pusherChannel = _pusher!.channel(channelName);
      _subscribedChannels[channelName] = pusherChannel;
      _listeners[channelName] = callback;
      debugPrint('✅ Subscribed to public channel: $channelName');
    } catch (e) {
      debugPrint('❌ Error subscribing to public channel $channelName: $e');
    }
  }

  void listen(String channel, String event, Function(dynamic) callback) {
    if (!_isConnected || _pusher == null) {
      _queueListener(channel, event, callback);
      return;
    }

    final channelName = _channelStorageKey(channel);
    final eventName = event.startsWith('.') ? event.substring(1) : event;

    _addEventListener(channelName, eventName, callback);

    debugPrint('👂 Registered listener for event $eventName on channel $channelName');

    // Ensure channel is subscribed and bind event once per event name
    if (!_subscribedChannels.containsKey(channelName)) {
      final ch = _openChannel(channelName);
      _subscribedChannels[channelName] = ch;
      _bindEventIfNeeded(ch, channelName, eventName);
    } else {
      final ch = _subscribedChannels[channelName];
      if (ch != null) {
        _bindEventIfNeeded(ch, channelName, eventName);
      }
    }
  }

  Future<void> unsubscribe(String channel) async {
    if (_pusher == null) return;

    final channelName = _channelStorageKey(channel);

    try {
      final ch = _subscribedChannels[channelName];
      ch?.unsubscribe();
      _subscribedChannels.remove(channelName);
      _listeners.remove(channelName);
      _eventListeners.remove(channelName);
      _boundEvents.remove(channelName);
      debugPrint('🔕 Unsubscribed from $channelName');
    } catch (e) {
      debugPrint('❌ Error unsubscribing: $e');
    }
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    if (_pusher == null) return;

    try {
      _pusher!.disconnect();
      _pusher = null;
      _isConnected = false;
      _isConnecting = false;
      _subscribedChannels.clear();
      _listeners.clear();
      _eventListeners.clear();
      _boundEvents.clear();
      _queuedListeners.clear();
      debugPrint('🔌 Disconnected from Pusher');
    } catch (e) {
      debugPrint('❌ Error disconnecting: $e');
    }
  }
  
  void dispose() {
    disconnect();
    _reconnectTimer?.cancel();
    _connectivityDebounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _connectivityDebounceTimer = null;
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accountId = prefs.getInt('current_account_id');
    String? token;
    if (accountId != null) {
      token = prefs.getString('auth_token_$accountId');
    }
    token ??= prefs.getString('auth_token');
    return token;
  }

  bool get isConnected => _isConnected;
  PusherClient? get pusher => _pusher;

  /// Resets backoff and reconnects — call when the app returns to foreground so realtime
  /// is not left offline after repeated failures.
  Future<void> resetReconnectPolicyAndConnect() async {
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await connect();
  }
  
  /// Get the current socket ID (useful for excluding sender from broadcasts)
  String? get socketId => _pusher?.socketId;
}
