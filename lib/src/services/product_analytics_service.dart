import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/api_service.dart';
import '../core/providers.dart';

final productAnalyticsProvider = Provider<ProductAnalyticsService>((ref) {
  final service = ProductAnalyticsService(ref.read(apiServiceProvider));
  ProductAnalytics.bind(service);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Static helper for repos/screens without WidgetRef access.
class ProductAnalytics {
  static ProductAnalyticsService? _service;

  static void bind(ProductAnalyticsService service) => _service = service;

  static void action(
    String actionKey, {
    String? feature,
    Map<String, dynamic>? properties,
  }) {
    _service?.trackAction(
      actionKey,
      featureKey: feature,
      properties: properties,
    );
  }
}

/// Owner-level product analytics SDK (sessions, screen time, actions).
class ProductAnalyticsService {
  ProductAnalyticsService(this._api);

  final ApiService _api;
  static const _sessionKey = 'product_analytics_session_uuid';
  static const _uuid = Uuid();

  String? _sessionUuid;
  String? _currentFeature;
  DateTime? _featureOpenedAt;
  Timer? _heartbeatTimer;
  Timer? _flushTimer;
  final List<Map<String, dynamic>> _queue = [];
  bool _started = false;
  String _platform = 'desktop';

  void dispose() {
    _heartbeatTimer?.cancel();
    _flushTimer?.cancel();
    unawaited(endSession());
  }

  String get platform => _platform;

  void configurePlatform({String? platform}) {
    if (platform != null) {
      _platform = platform;
      return;
    }
    if (kIsWeb) {
      _platform = 'web';
    } else if (Platform.isWindows) {
      _platform = 'windows';
    } else if (Platform.isMacOS) {
      _platform = 'macos';
    } else if (Platform.isLinux) {
      _platform = 'linux';
    } else if (Platform.isAndroid) {
      _platform = 'android';
    } else if (Platform.isIOS) {
      _platform = 'ios';
    } else {
      _platform = 'unknown';
    }
  }

  Future<void> startSession() async {
    if (_started) return;
    configurePlatform();
    final prefs = await SharedPreferences.getInstance();
    _sessionUuid = prefs.getString(_sessionKey) ?? _uuid.v4();
    await prefs.setString(_sessionKey, _sessionUuid!);

    try {
      await _api.post('/analytics/session/start', data: {
        'session_uuid': _sessionUuid,
        'platform': _platform,
        'device_type': _platform,
        'os_version': Platform.operatingSystemVersion,
      });
      _started = true;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) => _heartbeat());
      _flushTimer?.cancel();
      _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
    } catch (e) {
      debugPrint('ProductAnalytics startSession: $e');
    }
  }

  Future<void> endSession() async {
    if (!_started || _sessionUuid == null) return;
    await _closeCurrentFeature();
    await flush();
    try {
      await _api.post('/analytics/session/end', data: {
        'session_uuid': _sessionUuid,
      });
    } catch (e) {
      debugPrint('ProductAnalytics endSession: $e');
    }
    _started = false;
    _heartbeatTimer?.cancel();
    _flushTimer?.cancel();
  }

  Future<void> trackFeature(String featureKey) async {
    if (!_started) await startSession();
    final normalized = _normalizeFeature(featureKey);
    if (_currentFeature == normalized) return;

    await _closeCurrentFeature();
    _currentFeature = normalized;
    _featureOpenedAt = DateTime.now().toUtc();
    _enqueue('screen_view', featureKey: normalized);
  }

  void trackAction(String actionKey, {String? featureKey, Map<String, dynamic>? properties}) {
    _enqueue('action', featureKey: featureKey != null ? _normalizeFeature(featureKey) : _currentFeature, actionKey: actionKey, properties: properties);
  }

  Future<void> flush() async {
    if (_queue.isEmpty || _sessionUuid == null) return;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      await _api.post('/analytics/events', data: {
        'session_uuid': _sessionUuid,
        'platform': _platform,
        'events': batch,
      });
    } catch (e) {
      debugPrint('ProductAnalytics flush: $e');
      _queue.insertAll(0, batch);
    }
  }

  Future<void> _closeCurrentFeature() async {
    if (_currentFeature == null || _featureOpenedAt == null) return;
    final seconds = DateTime.now().toUtc().difference(_featureOpenedAt!).inSeconds;
    if (seconds > 0) {
      _enqueue('screen_view', featureKey: _currentFeature, properties: {
        'duration_seconds': seconds,
        'ended': true,
      });
    }
    _currentFeature = null;
    _featureOpenedAt = null;
    await flush();
  }

  Future<void> _heartbeat() async {
    if (_sessionUuid == null) return;
    try {
      await _api.post('/analytics/session/heartbeat', data: {
        'session_uuid': _sessionUuid,
      });
    } catch (_) {}
  }

  void _enqueue(
    String eventName, {
    String? featureKey,
    String? actionKey,
    Map<String, dynamic>? properties,
  }) {
    _queue.add({
      'event_name': eventName,
      if (featureKey != null) 'feature_key': featureKey,
      if (actionKey != null) 'action_key': actionKey,
      if (properties != null && properties.isNotEmpty) 'properties': properties,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (_queue.length >= 20) {
      unawaited(flush());
    }
  }

  String _normalizeFeature(String key) {
    var k = key.toLowerCase().trim();
    if (k.startsWith('/')) k = k.substring(1);
    const map = {
      'chat': 'chats',
      'live-broadcast': 'live',
      'sika': 'wallet',
    };
    return map[k] ?? k;
  }
}

/// Call from app lifecycle (resume/pause).
class ProductAnalyticsLifecycle {
  static Future<void> onResumed(WidgetRef ref) async {
    await ref.read(productAnalyticsProvider).startSession();
  }

  static Future<void> onPaused(WidgetRef ref) async {
    await ref.read(productAnalyticsProvider).endSession();
  }
}
