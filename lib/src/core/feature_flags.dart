import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'providers.dart';

/// PHASE 2: Feature Flags Service
class FeatureFlagService {
  final ApiService _apiService;

  FeatureFlagService(this._apiService);

  Future<Map<String, bool>> getFeatureFlags({String platform = 'desktop'}) async {
    try {
      final response = await _apiService.getFeatureFlags(platform: platform);
      if (response.data is Map && response.data['data'] != null) {
        // API returns array of flags, convert to map
        final flags = response.data['data'] as List<dynamic>;
        final Map<String, bool> result = {};
        for (var flag in flags) {
          if (flag is Map) {
            result[flag['key'] as String] = flag['enabled'] as bool? ?? false;
          }
        }
        return result;
      }
      return {};
    } catch (e) {
      // Return empty map on error (e.g., 401 unauthenticated)
      // Features will be disabled by default
      return {};
    }
  }
}

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return FeatureFlagService(apiService);
});

final featureFlagsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final service = ref.read(featureFlagServiceProvider);
  return await service.getFeatureFlags(platform: 'desktop');
});

/// Helper function to check if a feature is enabled
bool featureEnabled(WidgetRef ref, String featureName) {
  final flagsAsync = ref.watch(featureFlagsProvider);
  return flagsAsync.when(
    data: (flags) => flags[featureName] ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
}

