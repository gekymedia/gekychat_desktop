import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'models.dart';
import 'package:dio/dio.dart';

final broadcastRepositoryProvider = Provider<BroadcastRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return BroadcastRepository(api);
});

class BroadcastRepository {
  final ApiService _api;

  BroadcastRepository(this._api);

  Future<List<BroadcastList>> getBroadcastLists() async {
    try {
      final response = await _api.get('/broadcast-lists');
      final raw = response.data;
      final data = raw is Map && raw['data'] is List
          ? raw['data'] as List<dynamic>
          : (raw is List ? raw : []);
      return data.map((json) => BroadcastList.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data is Map
            ? e.response?.data['message'] ?? e.message
            : e.message;
        throw Exception('Failed to load broadcast lists (HTTP $statusCode): $message');
      }
      throw Exception('Failed to load broadcast lists: $e');
    }
  }

  Future<BroadcastList> getBroadcastList(int id) async {
    try {
      final response = await _api.get('/broadcast-lists/$id');
      final raw = response.data;
      final data = raw is Map && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw as Map<String, dynamic>;
      return BroadcastList.fromJson(data);
    } catch (e) {
      throw Exception('Failed to load broadcast list: $e');
    }
  }

  Future<BroadcastList> createBroadcastList({
    required String name,
    String? description,
    required List<int> recipientIds,
  }) async {
    try {
      final response = await _api.post('/broadcast-lists', data: {
        'name': name,
        if (description != null) 'description': description,
        'recipients': recipientIds,
      });
      final raw = response.data;
      final data = raw is Map && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw as Map<String, dynamic>;
      return BroadcastList.fromJson(data);
    } catch (e) {
      throw Exception('Failed to create broadcast list: $e');
    }
  }

  Future<BroadcastList> updateBroadcastList({
    required int id,
    String? name,
    String? description,
    List<int>? recipientIds,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (recipientIds != null) data['recipients'] = recipientIds;

      final response = await _api.put('/broadcast-lists/$id', data: data);
      final raw = response.data;
      final map = raw is Map && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw as Map<String, dynamic>;
      return BroadcastList.fromJson(map);
    } catch (e) {
      throw Exception('Failed to update broadcast list: $e');
    }
  }

  Future<void> deleteBroadcastList(int id) async {
    try {
      await _api.delete('/broadcast-lists/$id');
    } catch (e) {
      throw Exception('Failed to delete broadcast list: $e');
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required int broadcastListId,
    String? body,
    List<int>? attachmentIds,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (body != null) data['body'] = body;
      if (attachmentIds != null && attachmentIds.isNotEmpty) {
        data['attachments'] = attachmentIds;
      }

      final response = await _api.post('/broadcast-lists/$broadcastListId/send', data: data);
      return response.data is Map
          ? response.data as Map<String, dynamic>
          : {'message': 'Message sent successfully'};
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }
}

