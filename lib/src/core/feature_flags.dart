import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';
import 'providers.dart';

/// When true, [featureEnabled] returns true for every feature (sidebar, gates, etc.).
///
/// Enable via `--dart-define=FEATURE_FLAGS_BYPASS=true` and/or `.env`:
/// `FEATURE_FLAGS_BYPASS=true` or `GEKYCHAT_BYPASS_FEATURE_FLAGS=true`
bool featureFlagsClientBypassAll() {
  const fromDefine = bool.fromEnvironment(
    'FEATURE_FLAGS_BYPASS',
    defaultValue: false,
  );
  if (fromDefine) return true;
  try {
    final a = dotenv.env['FEATURE_FLAGS_BYPASS']?.toLowerCase();
    final b = dotenv.env['GEKYCHAT_BYPASS_FEATURE_FLAGS']?.toLowerCase();
    return a == 'true' || a == '1' || b == 'true' || b == '1';
  } catch (_) {
    return false;
  }
}

/// Platform string expected by GET /api/v1/feature-flags.
String featureFlagsClientPlatform() {
  if (kIsWeb) return 'web';
  try {
    if (Platform.isIOS || Platform.isAndroid) return 'mobile';
  } catch (_) {}
  return 'desktop';
}

/// PHASE 2: Feature Flags Service
class FeatureFlagService {
  final ApiService _apiService;

  /// Last successful fetch — preserved across failed refreshes so UI gates
  /// (e.g. Sika) are not wiped when attach opens offline / with a bad token.
  Map<String, bool>? _cachedFlags;

  FeatureFlagService(this._apiService);

  void clearCache() {
    _cachedFlags = null;
  }

  Future<Map<String, bool>> getFeatureFlags({String? platform}) async {
    final resolved = platform ?? featureFlagsClientPlatform();
    try {
      final response = await _apiService.getFeatureFlags(platform: resolved);

      // Handle different response formats
      if (response.data is Map) {
        // Check if response has 'data' key (new format)
        if (response.data['data'] != null) {
          final flags = response.data['data'] as List<dynamic>;
          final Map<String, bool> result = {};
          for (var flag in flags) {
            if (flag is Map) {
              final key = flag['key']?.toString();
              if (key == null || key.isEmpty) continue;
              result[key] = flag['enabled'] as bool? ?? true;
            }
          }
          _cachedFlags = Map<String, bool>.from(result);
          return result;
        }
        // Check if response is direct map (old format)
        else if (response.data is Map<String, dynamic>) {
          final Map<String, bool> result = {};
          response.data.forEach((key, value) {
            if (value is bool) {
              result[key] = value;
            }
          });
          _cachedFlags = Map<String, bool>.from(result);
          return result;
        }
      }

      // Unexpected format: keep prior cache if any.
      if (_cachedFlags != null) {
        return Map<String, bool>.from(_cachedFlags!);
      }
      return {};
    } catch (e) {
      debugPrint(
        '⚠️ Feature flags error (this is normal if not authenticated): ${e.toString()}',
      );
      if (_cachedFlags != null) {
        return Map<String, bool>.from(_cachedFlags!);
      }
      // No prior cache — rethrow so refreshFeatureFlags callers can catch
      // without replacing a previous AsyncData with empty flags.
      rethrow;
    }
  }
}

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return FeatureFlagService(apiService);
});

final featureFlagsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final service = ref.read(featureFlagServiceProvider);
  return await service.getFeatureFlags();
});

/// Force a fresh fetch from the API (e.g. when opening the attach menu).
/// Fetches before invalidating so a failure never replaces good cached flags
/// with `{}`. Rethrows only when there was nothing to preserve.
Future<Map<String, bool>> refreshFeatureFlags(WidgetRef ref) async {
  final service = ref.read(featureFlagServiceProvider);
  final flags = await service.getFeatureFlags();
  ref.invalidate(featureFlagsProvider);
  try {
    return await ref.read(featureFlagsProvider.future);
  } catch (_) {
    return flags;
  }
}

/// Helper function to check if a feature is enabled
bool featureEnabled(WidgetRef ref, String featureName) {
  // Temporary product override: World Feed must always be visible.
  if (featureName == 'world_feed') return true;
  if (featureFlagsClientBypassAll()) return true;
  final flagsAsync = ref.watch(featureFlagsProvider);
  return flagsAsync.when(
    data: (flags) => flags[featureName] ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
}
