import 'dart:io';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// PHASE 2: World Feed Repository
class WorldFeedRepository {
  final ApiService _apiService;

  WorldFeedRepository(this._apiService);

  /// Get world feed posts
  Future<Map<String, dynamic>> getFeed({int? page, String? query}) async {
    // Use getWorldFeedPosts which supports query parameter
    final response = await _apiService.getWorldFeedPosts(page: page, query: query);
    return Map<String, dynamic>.from(response.data);
  }

  /// Create a world feed post
  Future<Map<String, dynamic>> createPost({
    required File media,
    String? caption,
    List<String>? tags,
  }) async {
    final response = await _apiService.createWorldFeedPost(
      media: media,
      caption: caption,
      tags: tags,
    );
    return Map<String, dynamic>.from(response.data['data'] ?? response.data);
  }

  /// Like/unlike a post
  Future<void> likePost(int postId) async {
    await _apiService.likeWorldFeedPost(postId);
  }

  /// Get post comments
  Future<Map<String, dynamic>> getComments(int postId, {int? page}) async {
    final response = await _apiService.getWorldFeedPostComments(postId, page: page);
    return Map<String, dynamic>.from(response.data);
  }

  /// Add a comment
  Future<Map<String, dynamic>> addComment(
    int postId, {
    required String body,
    int? parentCommentId,
  }) async {
    final response = await _apiService.addWorldFeedComment(
      postId,
      body: body,
      parentCommentId: parentCommentId,
    );
    return Map<String, dynamic>.from(response.data['data'] ?? response.data);
  }

  /// Follow a creator
  Future<void> followCreator(int creatorId) async {
    await _apiService.followWorldFeedCreator(creatorId);
  }

  /// Share a post (returns shareable URL)
  Future<String> getShareUrl(int postId) async {
    final response = await _apiService.getWorldFeedPostShareUrl(postId);
    return response.data['share_url'] ?? 'https://chat.gekychat.com/wf/unknown';
  }

  /// Notify server of a completed share.
  Future<void> recordShare(int postId) async {
    try {
      await _apiService.recordWorldFeedPostShare(postId);
    } catch (_) {}
  }

  /// Load a single post by public [share_code] (deep link /wf/{code}).
  Future<Map<String, dynamic>> getPostByShareCode(String code) async {
    final response = await _apiService.getWorldFeedPostByShareCode(code);
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception('Post not found');
  }

  /// Load a single post by numeric id (activity / notification links).
  Future<Map<String, dynamic>> getPostById(int postId) async {
    final response = await _apiService.getWorldFeedPost(postId);
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Post not found');
  }
}

final worldFeedRepositoryProvider = Provider<WorldFeedRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return WorldFeedRepository(apiService);
});

/// True while a World Feed post is compressing or uploading after the composer closed.
final worldPostPendingProvider = StateProvider<bool>((ref) => false);

/// Bumped after a successful background World Feed publish so the feed reloads.
final worldFeedRefreshNonceProvider = StateProvider<int>((ref) => 0);

