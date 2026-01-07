import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'models.dart';
import 'package:dio/dio.dart';

final twoFactorRepositoryProvider = Provider<TwoFactorRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return TwoFactorRepository(api);
});

class TwoFactorRepository {
  final ApiService _api;

  TwoFactorRepository(this._api);

  Future<TwoFactorStatus> getStatus() async {
    try {
      final response = await _api.get('/two-factor/status');
      final data = response.data;
      // Handle both direct response and wrapped in 'data' key
      final statusData = data is Map && data.containsKey('data') 
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      return TwoFactorStatus.fromJson(statusData);
    } catch (e) {
      throw Exception('Failed to get 2FA status: $e');
    }
  }

  Future<TwoFactorSetup> setup() async {
    try {
      final response = await _api.get('/two-factor/setup');
      return TwoFactorSetup.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to setup 2FA: $e');
    }
  }

  Future<List<String>> enable(String code) async {
    try {
      final response = await _api.post('/two-factor/enable', data: {'code': code});
      final data = response.data;
      if (data['recovery_codes'] != null) {
        return (data['recovery_codes'] as List).map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data is Map
            ? e.response?.data['error'] ?? e.message
            : e.message;
        throw Exception(message ?? 'Failed to enable 2FA');
      }
      throw Exception('Failed to enable 2FA: $e');
    }
  }

  Future<void> disable(String password) async {
    try {
      await _api.post('/two-factor/disable', data: {'password': password});
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data is Map
            ? e.response?.data['error'] ?? e.message
            : e.message;
        throw Exception(message ?? 'Failed to disable 2FA');
      }
      throw Exception('Failed to disable 2FA: $e');
    }
  }

  Future<List<String>> regenerateRecoveryCodes(String password) async {
    try {
      final response = await _api.post('/two-factor/regenerate-recovery-codes', data: {'password': password});
      final data = response.data;
      if (data['recovery_codes'] != null) {
        return (data['recovery_codes'] as List).map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data is Map
            ? e.response?.data['error'] ?? e.message
            : e.message;
        throw Exception(message ?? 'Failed to regenerate recovery codes');
      }
      throw Exception('Failed to regenerate recovery codes: $e');
    }
  }
}

