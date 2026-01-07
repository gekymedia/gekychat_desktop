import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'models.dart';
import 'package:dio/dio.dart';

final linkedDevicesRepositoryProvider =
    Provider<LinkedDevicesRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return LinkedDevicesRepository(api);
});

class LinkedDevicesRepository {
  final ApiService _api;

  LinkedDevicesRepository(this._api);

  Future<List<LinkedDevice>> getLinkedDevices() async {
    try {
      final response = await _api.getLinkedDevices();
      final raw = response.data;
      final data = raw is Map && raw['data'] is List
          ? raw['data'] as List<dynamic>
          : (raw is List ? raw : []);
      
      // Backend now includes is_current_device flag, so we can use it directly
      return data.map((json) => LinkedDevice.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        // Don't throw for 401 if user is not authenticated - just return empty list
        if (statusCode == 401) {
          return [];
        }
        final message = e.response?.data is Map
            ? e.response?.data['error'] ?? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to load linked devices (HTTP $statusCode): $message');
      }
      throw Exception('Failed to load linked devices: $e');
    }
  }

  Future<void> deleteDevice(int deviceId) async {
    try {
      await _api.deleteLinkedDevice(deviceId);
    } catch (e) {
      throw Exception('Failed to delete device: $e');
    }
  }

  Future<void> deleteOtherDevices() async {
    try {
      await _api.deleteOtherLinkedDevices();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        // Handle 404 gracefully - might mean no other devices exist
        if (statusCode == 404) {
          return; // No other devices to delete, which is fine
        }
        final message = e.response?.data is Map
            ? e.response?.data['error'] ?? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to delete other devices (HTTP $statusCode): $message');
      }
      throw Exception('Failed to delete other devices: $e');
    }
  }
}

