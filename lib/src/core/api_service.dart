import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    // 🔴 MUST come from .env
    final baseUrl = dotenv.env['API_BASE_URL'];

    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('API_BASE_URL is not defined in .env');
    }

    // Ensure baseUrl doesn't end with a slash to avoid redirects
    var cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    
    // Ensure base URL ends with /api/v1 for proper routing
    // Laravel routes in api_user.php use Route::prefix('v1'), 
    // so full path is /api/v1/auth/phone (when included in api.php)
    // Base URL should be: https://chat.gekychat.com/api/v1
    final normalizedBaseUrl = cleanBaseUrl.toLowerCase();
    if (!normalizedBaseUrl.endsWith('/api/v1')) {
      // Handle different cases
      if (normalizedBaseUrl.endsWith('/api')) {
        // Ends with /api, add /v1
        cleanBaseUrl = '$cleanBaseUrl/v1';
      } else if (normalizedBaseUrl.endsWith('/v1')) {
        // Ends with /v1, check if /api/v1 exists earlier in the path
        final segments = cleanBaseUrl.split('/');
        final lastSegment = segments.last;
        if (lastSegment == 'v1') {
          // Check if previous segment is 'api'
          if (segments.length >= 2 && segments[segments.length - 2] == 'api') {
            // Already has /api/v1 at the end, keep it
          } else {
            // Has /v1 but not /api/v1, replace last segment
            segments[segments.length - 1] = 'api';
            segments.add('v1');
            cleanBaseUrl = segments.join('/');
          }
        }
      } else {
        // Doesn't end with /api or /v1, append /api/v1
        cleanBaseUrl = '$cleanBaseUrl/api/v1';
      }
    }
    
    debugPrint('🔗 API Base URL configured: $cleanBaseUrl');
    
    _dio = Dio(
      BaseOptions(
        baseUrl: cleanBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: true,
        maxRedirects: 5,
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            // Don't warn for auth endpoints that don't require tokens
            final path = options.path.toLowerCase();
            final isAuthEndpoint = path.contains('/auth/phone') || path.contains('/auth/verify');
            if (!isAuthEndpoint) {
              debugPrint('⚠️ Warning: No auth token found for request to ${options.path}');
            }
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Suppress expected errors that are handled gracefully
          final path = e.requestOptions.path;
          final statusCode = e.response?.statusCode;
          
          // Don't log 401 for endpoints that are expected to fail when not authenticated
          // Don't log 404 for linked-devices/others as it might mean no other devices exist
          final shouldSuppress = 
              (statusCode == 401 && (path.contains('/linked-devices') || path.contains('/feature-flags') || path == '/me' || path == '/api/v1/me')) ||
              (statusCode == 404 && path.contains('/linked-devices/others'));
          
          if (!shouldSuppress) {
            // Log detailed error information for debugging
            if (e.response != null) {
              debugPrint('❌ API Error ${e.response?.statusCode}: ${e.requestOptions.path}');
              debugPrint('   Response: ${e.response?.data}');
            } else {
              debugPrint('❌ API Error: ${e.type} - ${e.message}');
              debugPrint('   Path: ${e.requestOptions.path}');
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _normalize(String path) =>
      path.startsWith('/') ? path : '/$path';

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get(_normalize(path), queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(_normalize(path), data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(_normalize(path), data: data);

  Future<Response> delete(String path, {dynamic data}) =>
      _dio.delete(_normalize(path), data: data);

  /// Download a file from the server
  Future<void> downloadFile(
    String url,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    void Function(int, int)? onReceiveProgress,
  }) async {
    await _dio.download(
      url.startsWith('http') ? url : _normalize(url),
      savePath,
      queryParameters: queryParameters,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response> uploadFiles(
    String path,
    List<File> files, {
    Map<String, dynamic>? data,
    String? compressionLevel, // MEDIA COMPRESSION: Optional compression level
  }) async {
    final formData = FormData.fromMap({...?data});
    
    // MEDIA COMPRESSION: Add compression level if provided
    if (compressionLevel != null) {
      formData.fields.add(MapEntry('compression_level', compressionLevel));
    }

    for (final file in files) {
      formData.files.add(
        MapEntry(
          'attachments[]',
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split(Platform.pathSeparator).last,
          ),
        ),
      );
    }

    return _dio.post(_normalize(path), data: formData);
  }

  // ---------------------------------------------------------------------------
  // Server Health / Ping
  // ---------------------------------------------------------------------------

  Future<Response> pingServer({Duration? timeout}) async {
    final pingTimeout = timeout ?? const Duration(seconds: 5);
    
    final pingDio = Dio(
      BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: pingTimeout,
        receiveTimeout: pingTimeout,
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    final endpoints = ['/health', '/ping', '/api/health', '/api/ping', '/'];
    
    DioException? lastError;
    
    for (final endpoint in endpoints) {
      try {
        final response = await pingDio.get(_normalize(endpoint));
        return response;
      } on DioException catch (e) {
        lastError = e;
        if (e.response?.statusCode == 404 || 
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          continue;
        }
        rethrow;
      }
    }
    
    throw lastError ?? DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.connectionTimeout,
      error: 'All ping endpoints failed',
    );
  }

  String get baseUrl => _dio.options.baseUrl;

  // ---------------------------------------------------------------------------
  // Auth / User
  // ---------------------------------------------------------------------------

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Get upload limits for current user
  Future<Response> getUploadLimits() => get('/upload-limits');

  Future<Response> requestOtp(String phone) =>
      post('/auth/phone', data: {'phone': phone});

  Future<Response> verifyOtp(String phone, String code) =>
      post('/auth/verify', data: {'phone': phone, 'code': code});

  Future<Response> logout() => post('/auth/logout');

  // ---------------------------------------------------------------------------
  // Contacts
  // ---------------------------------------------------------------------------

  Future<Response> fetchContacts() => get('/contacts');

  Future<Response> syncContacts(List<Map<String, String>> contacts) =>
      post('/contacts/sync', data: {'contacts': contacts});

  Future<Response> resolveContacts(List<String> phones) =>
      post('/contacts/resolve', data: {'phones': phones});

  Future<Response> createContact({
    required String displayName,
    required String phone,
    int? contactUserId,
    String? note,
    bool? isFavorite,
  }) =>
      post('/contacts', data: {
        'display_name': displayName,
        'phone': phone,
        if (contactUserId != null) 'contact_user_id': contactUserId,
        if (note != null) 'note': note,
        if (isFavorite != null) 'is_favorite': isFavorite,
      });

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  Future<Response> conversationMessages({
    required int conversationId,
    String? before,
    String? after,
    int? limit,
  }) {
    final params = <String, dynamic>{};
    if (before != null) params['before'] = before;
    if (after != null) params['after'] = after;
    if (limit != null) params['limit'] = limit;

    return get(
      '/conversations/$conversationId/messages',
      queryParameters: params,
    );
  }

  Future<Response> updateDob({int? month, int? day}) =>
      put('/me', data: {
        if (month != null) 'month': month,
        if (day != null) 'day': day,
      });

  // PHASE 1: Delete message with optional "delete for everyone" option
  Future<Response> deleteMessage(int messageId, {bool deleteForEveryone = false}) =>
      delete('/messages/$messageId?delete_for=${deleteForEveryone ? 'everyone' : 'me'}');

  Future<Response> editMessage(int messageId, String body) =>
      put('/messages/$messageId', data: {'body': body});

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Future<Response> search({
    String? query,
    List<String>? filters,
    int? limit,
  }) {
    final params = <String, dynamic>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (filters != null && filters.isNotEmpty) params['filters'] = filters;
    if (limit != null) params['limit'] = limit;
    return get('/search', queryParameters: params.isEmpty ? null : params);
  }

  Future<Response> getSearchFilters() => get('/search/filters');

  // ---------------------------------------------------------------------------
  // Attachments
  // ---------------------------------------------------------------------------

  Future<Response> uploadAttachment(File file, {String? compressionLevel}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
      // MEDIA COMPRESSION: Include compression level preference
      if (compressionLevel != null) 'compression_level': compressionLevel,
    });
    return _dio.post(_normalize('/attachments'), data: formData);
  }

  // MEDIA COMPRESSION: Get attachment details (to check compression status)
  Future<Response> getAttachment(int attachmentId) =>
    get('/attachments/$attachmentId');

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Future<Response> getProfile() => get('/me');

  Future<Response> updateProfile({
    String? name,
    String? about,
    String? email,
    String? phone,
    String? username,
    String? bio,
    int? dobMonth,
    int? dobDay,
    File? avatar,
  }) async {
    if (avatar != null) {
      final formData = FormData.fromMap({
        if (name != null) 'name': name,
        if (about != null) 'about': about,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
        if (dobMonth != null) 'dob_month': dobMonth,
        if (dobDay != null) 'dob_day': dobDay,
        'avatar': await MultipartFile.fromFile(
          avatar.path,
          filename: avatar.path.split(Platform.pathSeparator).last,
        ),
      });
      return _dio.put(_normalize('/me'), data: formData);
    } else {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (about != null) data['about'] = about;
      if (email != null) data['email'] = email;
      if (phone != null) data['phone'] = phone;
      if (username != null) data['username'] = username;
      if (bio != null) data['bio'] = bio;
      if (dobMonth != null) data['dob_month'] = dobMonth;
      if (dobDay != null) data['dob_day'] = dobDay;
      return put('/me', data: data.isEmpty ? null : data);
    }
  }

  // ---------------------------------------------------------------------------
  // Quick Replies
  // ---------------------------------------------------------------------------

  Future<Response> getQuickReplies() => get('/quick-replies');

  Future<Response> createQuickReply(String title, String message) =>
      post('/quick-replies', data: {'title': title, 'message': message});

  Future<Response> updateQuickReply(int id, String title, String message) =>
      put('/quick-replies/$id', data: {'title': title, 'message': message});

  Future<Response> deleteQuickReply(int id) => delete('/quick-replies/$id');

  Future<Response> recordQuickReplyUsage(int id) =>
      post('/quick-replies/$id/usage');

  // ---------------------------------------------------------------------------
  // Blocks
  // ---------------------------------------------------------------------------

  Future<Response> getBlockedUsers() => get('/blocks');

  Future<Response> blockUser(int userId, {String? reason}) {
    final data = reason != null ? {'reason': reason} : null;
    return post('/blocks/$userId', data: data);
  }

  Future<Response> unblockUser(int userId) => delete('/blocks/$userId');

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------

  Future<Response> reportUser(int userId, String reason, {String? details, bool? block}) {
    final data = <String, dynamic>{
      'reason': reason,
      if (details != null) 'details': details,
      if (block != null) 'block': block,
    };
    return post('/reports/$userId', data: data);
  }

  // ---------------------------------------------------------------------------
  // Conversation Actions
  // ---------------------------------------------------------------------------

  Future<Response> pinConversation(int conversationId) =>
      post('/conversations/$conversationId/pin');

  Future<Response> unpinConversation(int conversationId) =>
      delete('/conversations/$conversationId/pin');

  Future<Response> markConversationUnread(int conversationId) =>
      post('/conversations/$conversationId/mark-unread');

  Future<Response> archiveConversation(int conversationId) =>
      post('/conversations/$conversationId/archive');

  Future<Response> unarchiveConversation(int conversationId) =>
      delete('/conversations/$conversationId/archive');

  Future<Response> getArchivedConversations() =>
      get('/conversations/archived');

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  Future<Response> getLabels() => get('/labels');
  
  Future<Response> createLabel(String name) =>
      post('/labels', data: {'name': name});
  
  Future<Response> updateLabel(int id, String name) =>
      put('/labels/$id', data: {'name': name});
  
  Future<Response> deleteLabel(int labelId) =>
      delete('/labels/$labelId');
  
  Future<Response> attachLabelToConversation(int labelId, int conversationId) =>
      post('/labels/$labelId/attach/$conversationId');
  
  Future<Response> detachLabelFromConversation(int labelId, int conversationId) =>
      delete('/labels/$labelId/detach/$conversationId');

  // ---------------------------------------------------------------------------
  // Two-Factor Authentication
  // ---------------------------------------------------------------------------

  Future<Response> getTwoFactorStatus() => get('/two-factor/status');
  Future<Response> setupTwoFactor() => get('/two-factor/setup');
  Future<Response> enableTwoFactor(Map<String, dynamic> data) =>
      post('/two-factor/enable', data: data);
  Future<Response> disableTwoFactor(Map<String, dynamic> data) =>
      post('/two-factor/disable', data: data);
  Future<Response> regenerateRecoveryCodes(Map<String, dynamic> data) =>
      post('/two-factor/regenerate-recovery-codes', data: data);

  // ---------------------------------------------------------------------------
  // Linked Devices
  // ---------------------------------------------------------------------------

  Future<Response> getLinkedDevices() => get('/linked-devices');
  Future<Response> deleteLinkedDevice(dynamic id) => delete('/linked-devices/$id');
  Future<Response> deleteOtherLinkedDevices() => delete('/linked-devices/others');

  // ---------------------------------------------------------------------------
  // Media Gallery
  // ---------------------------------------------------------------------------

  Future<Response> getConversationMedia(int conversationId) =>
      get('/conversations/$conversationId/media');
  Future<Response> getGroupMedia(int groupId) => get('/groups/$groupId/media');

  // ---------------------------------------------------------------------------
  // Search in Chat
  // ---------------------------------------------------------------------------

  Future<Response> searchInConversation(int conversationId, String query) =>
      get('/conversations/$conversationId/search', queryParameters: {'q': query});
  Future<Response> searchInGroup(int groupId, String query) =>
      get('/groups/$groupId/search', queryParameters: {'q': query});

  // ---------------------------------------------------------------------------
  // Chat Actions
  // ---------------------------------------------------------------------------

  Future<Response> clearConversation(int conversationId) =>
      post('/conversations/$conversationId/clear');
  Future<Response> deleteConversation(int conversationId) =>
      delete('/conversations/$conversationId');
  Future<Response> exportConversation(int conversationId) =>
      get('/conversations/$conversationId/export');

  // ---------------------------------------------------------------------------
  // Group Management
  // ---------------------------------------------------------------------------

  Future<Response> updateGroup(int groupId, Map<String, dynamic> data) =>
      put('/groups/$groupId', data: data);
  Future<Response> addGroupMember(int groupId, Map<String, dynamic> data) =>
      post('/groups/$groupId/members', data: data);
  Future<Response> removeGroupMember(int groupId, int userId) =>
      delete('/groups/$groupId/members/$userId');
  Future<Response> promoteGroupAdmin(int groupId, int userId) =>
      post('/groups/$groupId/members/$userId/promote');
  Future<Response> demoteGroupAdmin(int groupId, int userId) =>
      post('/groups/$groupId/members/$userId/demote');

  // Group Actions
  Future<Response> pinGroup(int groupId) => post('/groups/$groupId/pin');
  Future<Response> unpinGroup(int groupId) => delete('/groups/$groupId/pin');
  Future<Response> leaveGroup(int groupId) => delete('/groups/$groupId/leave');
  
  Future<Response> muteGroup(int groupId, {int? minutes, DateTime? until}) {
    final data = <String, dynamic>{};
    if (minutes != null) data['minutes'] = minutes;
    if (until != null) data['until'] = until.toIso8601String();
    return post('/groups/$groupId/mute', data: data);
  }
  Future<Response> unmuteGroup(int groupId) => delete('/groups/$groupId/mute');

  // ---------------------------------------------------------------------------
  // Privacy Settings
  // ---------------------------------------------------------------------------

  Future<Response> getPrivacySettings() => get('/privacy-settings');
  Future<Response> updatePrivacySettings(Map<String, dynamic> data) =>
      put('/privacy-settings', data: data);

  // ---------------------------------------------------------------------------
  // Notification Settings
  // ---------------------------------------------------------------------------

  Future<Response> getNotificationSettings() => get('/notification-settings');
  Future<Response> updateNotificationSettings(Map<String, dynamic> data) =>
      put('/notification-settings', data: data);
  Future<Response> updateConversationNotificationSettings(
          int conversationId, Map<String, dynamic> data) =>
      put('/conversations/$conversationId/notification-settings', data: data);
  Future<Response> updateGroupNotificationSettings(
          int groupId, Map<String, dynamic> data) =>
      put('/groups/$groupId/notification-settings', data: data);
  Future<Response> generateGroupInvite(int groupId) =>
      post('/groups/$groupId/generate-invite');
  Future<Response> getGroupInviteInfo(int groupId) =>
      get('/groups/$groupId/invite-info');

  // ---------------------------------------------------------------------------
  // Media Auto-Download
  // ---------------------------------------------------------------------------

  Future<Response> getMediaAutoDownloadSettings() =>
      get('/media-auto-download');
  Future<Response> updateMediaAutoDownloadSettings(Map<String, dynamic> data) =>
      put('/media-auto-download', data: data);

  // ---------------------------------------------------------------------------
  // Storage Usage
  // ---------------------------------------------------------------------------

  Future<Response> getStorageUsage() => get('/storage-usage');

  // ---------------------------------------------------------------------------
  // Starred Messages
  // ---------------------------------------------------------------------------

  Future<Response> getStarredMessages() => get('/starred-messages');
  Future<Response> starMessage(int messageId) => post('/messages/$messageId/star');
  Future<Response> unstarMessage(int messageId) => delete('/messages/$messageId/star');
  Future<Response> starGroupMessage(int groupId, int messageId) => post('/groups/$groupId/messages/$messageId/star');
  Future<Response> unstarGroupMessage(int groupId, int messageId) => delete('/groups/$groupId/messages/$messageId/star');

  // ---------------------------------------------------------------------------
  // Account
  // ---------------------------------------------------------------------------

  Future<Response> deleteAccount(Map<String, dynamic> data) =>
      delete('/account', data: data);

  // ---------------------------------------------------------------------------
  // Location Sharing
  // ---------------------------------------------------------------------------

  Future<Response> shareLocationInConversation(
    int conversationId, {
    required double latitude,
    required double longitude,
    String? address,
    String? placeName,
  }) {
    return post('/conversations/$conversationId/share-location', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      if (placeName != null) 'place_name': placeName,
    });
  }

  Future<Response> shareLocationInGroup(
    int groupId, {
    required double latitude,
    required double longitude,
    String? address,
    String? placeName,
  }) {
    return post('/groups/$groupId/share-location', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      if (placeName != null) 'place_name': placeName,
    });
  }

  // ---------------------------------------------------------------------------
  // Contact Sharing
  // ---------------------------------------------------------------------------

  Future<Response> shareContactInConversation(
    int conversationId, {
    int? contactId,
    String? name,
    String? phone,
    String? email,
  }) {
    if (contactId != null) {
      return post('/conversations/$conversationId/share-contact', data: {'contact_id': contactId});
    } else {
      return post('/conversations/$conversationId/share-contact', data: {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
      });
    }
  }

  Future<Response> shareContactInGroup(
    int groupId, {
    int? contactId,
    String? name,
    String? phone,
    String? email,
  }) {
    if (contactId != null) {
      return post('/groups/$groupId/share-contact', data: {'contact_id': contactId});
    } else {
      return post('/groups/$groupId/share-contact', data: {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // PHASE 2: Feature Flags
  // ---------------------------------------------------------------------------

  Future<Response> getFeatureFlags({String? platform}) => 
    get('/feature-flags', queryParameters: platform != null ? {'platform': platform} : null);

  // ---------------------------------------------------------------------------
  // PHASE 2: World Feed
  // ---------------------------------------------------------------------------

  Future<Response> getWorldFeed({int? page}) => 
    get('/world-feed', queryParameters: page != null ? {'page': page} : null);
  Future<Response> getWorldFeedPosts({int? page, int? creatorId, String? query}) =>
    get('/world-feed/posts', queryParameters: {
      if (page != null) 'page': page,
      if (creatorId != null) 'creator_id': creatorId,
      if (query != null && query.isNotEmpty) 'q': query,
    });
  Future<Response> createWorldFeedPost({
    required File media,
    String? caption,
    List<String>? tags,
    int? audioId,
    int? audioVolume,
    bool? audioLoop,
  }) async {
    final formData = FormData.fromMap({
      'media': await MultipartFile.fromFile(media.path),
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
      if (audioId != null) 'audio_id': audioId,
      if (audioVolume != null) 'audio_volume': audioVolume,
      if (audioLoop != null) 'audio_loop': audioLoop,
    });
    return post('/world-feed/posts', data: formData);
  }
  Future<Response> likeWorldFeedPost(int postId) => post('/world-feed/posts/$postId/like');
  Future<Response> getWorldFeedPostComments(int postId, {int? page}) =>
    get('/world-feed/posts/$postId/comments', queryParameters: page != null ? {'page': page} : null);
  Future<Response> addWorldFeedComment(int postId, {required String body, int? parentCommentId}) =>
    post('/world-feed/posts/$postId/comments', data: {
      'comment': body, // Backend expects 'comment' field
      if (parentCommentId != null) 'parent_id': parentCommentId, // Backend expects 'parent_id'
    });
  Future<Response> followWorldFeedCreator(int creatorId) =>
    post('/world-feed/creators/$creatorId/follow');
  Future<Response> getWorldFeedPostShareUrl(int postId) =>
    get('/world-feed/posts/$postId/share-url');

  // ---------------------------------------------------------------------------
  // PHASE 2: Email Chat (Mail)
  // ---------------------------------------------------------------------------

  Future<Response> getMailConversations() => get('/mail');
  Future<Response> checkUsername() => get('/mail/check-username');
  Future<Response> getMailConversationMessages(int conversationId, {int? perPage}) =>
    get('/mail/conversations/$conversationId/messages', queryParameters: perPage != null ? {'per_page': perPage} : null);
  Future<Response> replyToMailMessage(int messageId, {required String body}) =>
    post('/mail/messages/$messageId/reply', data: {'body': body});

  // ---------------------------------------------------------------------------
  // PHASE 2: Live Broadcast
  // ---------------------------------------------------------------------------

  Future<Response> startLiveBroadcast({String? title}) =>
    post('/live/start', data: title != null && title.isNotEmpty ? {'title': title} : {});
  Future<Response> joinLiveBroadcast(int broadcastId) =>
    post('/live/$broadcastId/join');
  Future<Response> endLiveBroadcast(int broadcastId) =>
    post('/live/$broadcastId/end');
  Future<Response> getActiveLiveBroadcasts() => get('/live/active');
  Future<Response> sendLiveBroadcastChat(int broadcastId, {required String message}) =>
    post('/live/$broadcastId/chat', data: {'message': message});
  Future<Response> getLiveKitToken({required String roomName, required String role}) =>
    post('/live/kit/token', data: {'room_name': roomName, 'role': role});

  // ---------------------------------------------------------------------------
  // PHASE 2: Multi-Account Support
  // ---------------------------------------------------------------------------

  Future<Response> getAccounts({required String deviceId, required String deviceType}) =>
    get('/auth/accounts', queryParameters: {'device_id': deviceId, 'device_type': deviceType});
  Future<Response> switchAccount({
    required String deviceId,
    required String deviceType,
    required int accountId,
  }) =>
    post('/auth/switch-account', data: {
      'device_id': deviceId,
      'device_type': deviceType,
      'account_id': accountId,
    });
  Future<Response> removeAccount({
    required String deviceId,
    required String deviceType,
    required int accountId,
  }) =>
    delete('/auth/accounts/$accountId?device_id=$deviceId&device_type=$deviceType');
}
