import 'dart:io';
import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// PHASE 2: World Feed Repository
class WorldFeedRepository {
  final ApiService _apiService;

  WorldFeedRepository(this._apiService);

  Future<Map<String, dynamic>> getInterests() async {
    final response = await _apiService.getWorldFeedInterests();
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return <String, dynamic>{};
  }

  Future<void> saveInterests({
    List<String>? interests,
    bool skip = false,
  }) async {
    await _apiService.saveWorldFeedInterests(
      interests: interests,
      skip: skip,
    );
  }

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

  /// Trending hashtags for World search discovery.
  Future<List<Map<String, dynamic>>> getTrendingHashtags({
    int limit = 20,
  }) async {
    try {
      final response =
          await _apiService.getWorldFeedTrendingHashtags(limit: limit);
      final data = response.data['data'] as List<dynamic>? ?? [];
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Record opening a creator profile. Pass [sourcePostId] when navigating
  /// from a watched post — used as a strong feed affinity signal.
  Future<void> recordProfileView(int userId, {int? sourcePostId}) async {
    try {
      await _apiService.recordWorldFeedProfileView(
        userId,
        sourcePostId: sourcePostId,
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getActivity({
    int page = 1,
    String? type,
    String? excludeType,
    String? filter,
  }) async {
    final response = await _apiService.getWorldFeedActivity(
      page: page,
      type: type,
      excludeType: excludeType,
      filter: filter,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<int> getActivityUnreadCount() async {
    final response = await _apiService.getWorldFeedActivityUnreadCount();
    return (response.data['unread_count'] as int?) ?? 0;
  }

  Future<void> markActivityRead({
    List<int>? activityIds,
    bool all = false,
    String? type,
  }) async {
    await _apiService.markWorldFeedActivityRead(
      activityIds: activityIds,
      all: all,
      type: type,
    );
  }

  Future<void> followUser(int userId) async {
    try {
      await _apiService.followUser(userId);
    } catch (_) {}
  }

  Future<void> unfollowUser(int userId) async {
    try {
      await _apiService.unfollowUser(userId);
    } catch (_) {}
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

/// Unread count for the World activity bell badge.
final worldFeedActivityUnreadCountProvider = FutureProvider<int>((ref) async {
  try {
    final repo = ref.read(worldFeedRepositoryProvider);
    return repo.getActivityUnreadCount();
  } catch (_) {
    return 0;
  }
});

