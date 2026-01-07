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
      return data.map((json) => LinkedDevice.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map
            ? e.response?.data['error'] ?? e.message
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
      throw Exception('Failed to delete other devices: $e');
    }
  }
}

