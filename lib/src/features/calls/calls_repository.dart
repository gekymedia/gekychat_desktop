import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'models.dart';

final callsRepositoryProvider = Provider<CallsRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return CallsRepository(api);
});

class CallsRepository {
  final ApiService _api;

  CallsRepository(this._api);

  Future<List<CallLog>> getCallLogs() async {
    try {
      final response = await _api.get('/calls');
      final data = response.data;
      final callsData = data['data'] is List ? data['data'] as List : [];
      return callsData.map((json) => CallLog.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load call logs: $e');
    }
  }
}

