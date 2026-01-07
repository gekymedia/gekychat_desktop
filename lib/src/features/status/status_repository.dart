import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'models.dart';

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return StatusRepository(api);
});

class StatusRepository {
  final ApiService _api;

  StatusRepository(this._api);

  Future<List<StatusSummary>> getStatuses() async {
    try {
      final response = await _api.get('/statuses');
      final data = response.data;
      
      if (data['statuses'] != null) {
        return (data['statuses'] as List)
            .map((json) => StatusSummary.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load statuses: $e');
    }
  }

  Future<MyStatus> getMyStatus() async {
    try {
      final response = await _api.get('/statuses/mine');
      final data = response.data;
      return MyStatus.fromJson(data);
    } catch (e) {
      throw Exception('Failed to load my status: $e');
    }
  }

  Future<StatusSummary> getUserStatus(int userId) async {
    try {
      final response = await _api.get('/statuses/user/$userId');
      final data = response.data;
      return StatusSummary.fromJson(data);
    } catch (e) {
      throw Exception('Failed to load user status: $e');
    }
  }

  Future<StatusUpdate> createTextStatus({
    required String text,
    String? backgroundColor,
    String? fontFamily,
  }) async {
    try {
      final response = await _api.post('/statuses', data: {
        'type': 'text',
        'text': text,
        'background_color': backgroundColor,
        'font_family': fontFamily,
      });
      
      final raw = response.data;
      Map<String, dynamic> statusData;
      if (raw is Map) {
        final rawMap = Map<String, dynamic>.from(raw);
        if (rawMap['status'] != null) {
          statusData = Map<String, dynamic>.from(rawMap['status'] as Map);
        } else if (rawMap['data'] != null && rawMap['data'] is Map) {
          statusData = Map<String, dynamic>.from(rawMap['data'] as Map);
        } else {
          statusData = rawMap;
        }
      } else {
        throw Exception('Unexpected response format: ${raw.runtimeType}');
      }
      
      return StatusUpdate.fromJson(statusData);
    } catch (e) {
      throw Exception('Failed to create text status: $e');
    }
  }

  Future<StatusUpdate> createImageStatus({
    required File imageFile,
    String? caption,
  }) async {
    try {
      final formData = FormData.fromMap({
        'type': 'image',
        'media': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split(Platform.pathSeparator).last,
        ),
        if (caption != null) 'caption': caption,
      });

      final response = await _api.post('/statuses', data: formData);
      final raw = response.data;
      
      Map<String, dynamic> statusData;
      if (raw is Map) {
        final rawMap = Map<String, dynamic>.from(raw);
        if (rawMap['status'] != null) {
          statusData = Map<String, dynamic>.from(rawMap['status'] as Map);
        } else if (rawMap['data'] != null && rawMap['data'] is Map) {
          statusData = Map<String, dynamic>.from(rawMap['data'] as Map);
        } else {
          statusData = rawMap;
        }
      } else {
        throw Exception('Unexpected response format: ${raw.runtimeType}');
      }
      
      return StatusUpdate.fromJson(statusData);
    } catch (e) {
      throw Exception('Failed to create image status: $e');
    }
  }

  Future<StatusUpdate> createVideoStatus({
    required File videoFile,
    String? caption,
  }) async {
    try {
      final formData = FormData.fromMap({
        'type': 'video',
        'media': await MultipartFile.fromFile(
          videoFile.path,
          filename: videoFile.path.split(Platform.pathSeparator).last,
        ),
        if (caption != null) 'caption': caption,
      });

      final response = await _api.post('/statuses', data: formData);
      final raw = response.data;
      
      Map<String, dynamic> statusData;
      if (raw is Map) {
        final rawMap = Map<String, dynamic>.from(raw);
        if (rawMap['status'] != null) {
          statusData = Map<String, dynamic>.from(rawMap['status'] as Map);
        } else if (rawMap['data'] != null && rawMap['data'] is Map) {
          statusData = Map<String, dynamic>.from(rawMap['data'] as Map);
        } else {
          statusData = rawMap;
        }
      } else {
        throw Exception('Unexpected response format: ${raw.runtimeType}');
      }
      
      return StatusUpdate.fromJson(statusData);
    } catch (e) {
      throw Exception('Failed to create video status: $e');
    }
  }

  /// Mark a status as viewed
  /// 
  /// PHASE 0: TODO (PHASE 1) - Add stealth viewing support (same as mobile)
  /// TODO (PHASE 1): Add 'stealth' boolean parameter to mark view as stealth
  /// TODO (PHASE 1): Pass stealth parameter to backend API
  Future<void> markStatusAsViewed(int statusId) async {
    try {
      await _api.post('/statuses/$statusId/view');
    } catch (e) {
      // Silently fail
    }
  }

  /// Get comments for a status
  Future<List<StatusComment>> getStatusComments(int statusId) async {
    try {
      final response = await _api.get('/statuses/$statusId/comments');
      final data = response.data;
      
      if (data['data'] != null) {
        return (data['data'] as List)
            .map((json) => StatusComment.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load comments: $e');
    }
  }

  /// Add a comment to a status
  Future<StatusComment> addStatusComment(int statusId, String comment) async {
    try {
      final response = await _api.post('/statuses/$statusId/comments', data: {
        'comment': comment,
      });
      final data = response.data;
      return StatusComment.fromJson(data['data']);
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  /// Delete a status comment
  Future<void> deleteStatusComment(int statusId, int commentId) async {
    try {
      await _api.delete('/statuses/$statusId/comments/$commentId');
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  Future<List<StatusViewer>> getStatusViewers(int statusId) async {
    try {
      final response = await _api.get('/statuses/$statusId/viewers');
      final data = response.data;
      
      if (data['viewers'] != null) {
        return (data['viewers'] as List)
            .map((json) => StatusViewer.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load status viewers: $e');
    }
  }

  Future<void> deleteStatus(int statusId) async {
    try {
      await _api.delete('/statuses/$statusId');
    } catch (e) {
      throw Exception('Failed to delete status: $e');
    }
  }
}


