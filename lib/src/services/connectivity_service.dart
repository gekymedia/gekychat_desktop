import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// Service to check internet connectivity
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  /// connectivity_plus 6.x returns a list of active interface types.
  static ConnectivityResult _primaryResult(List<ConnectivityResult> results) {
    if (results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none)) {
      return ConnectivityResult.none;
    }
    for (final preferred in [
      ConnectivityResult.wifi,
      ConnectivityResult.ethernet,
      ConnectivityResult.mobile,
      ConnectivityResult.vpn,
      ConnectivityResult.other,
    ]) {
      if (results.contains(preferred)) return preferred;
    }
    return results.firstWhere(
      (r) => r != ConnectivityResult.none,
      orElse: () => ConnectivityResult.none,
    );
  }

  /// Check if device has internet connectivity
  /// Returns true if connected, false otherwise
  static Future<bool> hasInternetConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final connectivityResult = _primaryResult(results);

      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('📡 No network connectivity');
        return false;
      }

      // Desktop: a live network interface is enough for Pusher/API — DNS probes
      // (e.g. google.com) often fail on LAN/corporate networks and blocked realtime.
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        debugPrint('✅ Desktop network interface available');
        return true;
      }

      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));

        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          debugPrint('✅ Internet connection available');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Network available but no internet access: $e');
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      return false;
    }
  }

  /// Get current connectivity status
  static Future<ConnectivityResult> getConnectivityStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _primaryResult(results);
    } catch (e) {
      debugPrint('❌ Error getting connectivity status: $e');
      return ConnectivityResult.none;
    }
  }

  /// Stream of connectivity changes (collapsed to a single primary result).
  static Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged.map(_primaryResult);
}
