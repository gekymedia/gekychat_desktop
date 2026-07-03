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

/// PHASE 2: Feature Flags Service
class FeatureFlagService {
  final ApiService _apiService;

  FeatureFlagService(this._apiService);

  Future<Map<String, bool>> getFeatureFlags({String platform = 'desktop'}) async {
    try {
      final response = await _apiService.getFeatureFlags(platform: platform);
      
      // Handle different response formats
      if (response.data is Map) {
        // Check if response has 'data' key (new format)
        if (response.data['data'] != null) {
          final flags = response.data['data'] as List<dynamic>;
          final Map<String, bool> result = {};
          for (var flag in flags) {
            if (flag is Map) {
              result[flag['key'] as String] = flag['enabled'] as bool? ?? false;
            }
          }
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
          return result;
        }
      }
      
      // Empty result if format is unexpected
      return {};
    } catch (e) {
      // Silently handle errors (401 unauthenticated, network errors, etc.)
      // Features will be disabled by default until user authenticates
      debugPrint('⚠️ Feature flags error (this is normal if not authenticated): ${e.toString()}');
      return {};
    }
  }
}

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return FeatureFlagService(apiService);
});

final featureFlagsProvider = FutureProvider<Map<String, bool>>((ref) async {
  try {
    final service = ref.read(featureFlagServiceProvider);
    return await service.getFeatureFlags(platform: 'desktop');
  } catch (e) {
    // Return empty map on any error (401 unauthenticated, network errors, etc.)
    // Features will be disabled by default until user is authenticated
    debugPrint('⚠️ Error loading feature flags: $e');
    return {};
  }
});

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

