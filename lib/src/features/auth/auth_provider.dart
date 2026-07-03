import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/providers.dart';
import '../../core/api_service.dart';
import '../../core/device_id.dart';
import '../../features/notifications/notification_manager.dart';
import '../../services/post_auth_bootstrap.dart';

/// Sentinel so `copyWith(token: null)` / `copyWith(error: null)` actually clear fields.
const Object _authFieldUnset = Object();

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AuthNotifier(apiService, ref);
});

class AuthState {
  final bool isLoading;
  final String? token;
  final String? error;

  AuthState({this.isLoading = false, this.token, this.error});

  AuthState copyWith({
    bool? isLoading,
    Object? token = _authFieldUnset,
    Object? error = _authFieldUnset,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      token: identical(token, _authFieldUnset) ? this.token : token as String?,
      error: identical(error, _authFieldUnset) ? this.error : error as String?,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final Ref _ref;

  AuthNotifier(this._apiService, this._ref) : super(AuthState()) {
    // Load token from storage immediately on initialization
    // This ensures auth state is available when router is created
    _loadTokenFromStorage();
    // Then validate it asynchronously
    checkAuthStatus();
  }
  
  Future<void> _loadTokenFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        // Set token immediately so router can use it
        state = state.copyWith(token: token);
      }
    } catch (e) {
      debugPrint('⚠️ Error loading token from storage: $e');
    }
  }

  /// Call after switchAccount to reload token from storage and update auth state.
  Future<void> refreshTokenFromStorage() async {
    await _loadTokenFromStorage();
    await checkAuthStatus();
  }

  String _formatError(dynamic e, String defaultMessage) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timeout. The server at ${_apiService.baseUrl} is not responding.';
        case DioExceptionType.connectionError:
          return 'Cannot connect to server at ${_apiService.baseUrl}';
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          final responseData = e.response?.data;
          
          if (statusCode == 301 || statusCode == 302) {
            final location = e.response?.headers.value('location') ?? 'unknown';
            return 'Redirect error ($statusCode). The server redirected to: $location\nCurrent API URL: ${_apiService.baseUrl}/auth/phone\nPlease check API_BASE_URL in .env file.';
          } else if (statusCode == 404) {
            return 'Endpoint not found at ${_apiService.baseUrl}/auth/phone';
          } else if (statusCode == 429) {
            // Rate limiting - extract message from response if available
            String message = 'Too many OTP requests. Please wait a few minutes before trying again.';
            if (responseData is Map && responseData['message'] != null) {
              message = responseData['message'].toString();
            } else if (responseData is String) {
              message = responseData;
            }
            return message;
          } else if (statusCode == 500) {
            return 'Server error. Please try again later.';
          }
          
          // Try to extract error message from response
          String errorMsg = 'Server returned error ${statusCode ?? "unknown"}';
          if (responseData is Map && responseData['message'] != null) {
            errorMsg = responseData['message'].toString();
          } else if (responseData is String) {
            errorMsg = responseData;
          }
          return errorMsg;
        default:
          return 'Network error: ${e.message ?? "Unknown error"}';
      }
    }
    return e.toString();
  }

  Future<void> loginWithPhone(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    
    // Clear any existing token when starting new login
    // This prevents old tokens from causing auto-login
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    state = state.copyWith(token: null);
    
    try {
      debugPrint('📱 Requesting OTP for phone: $phone');
      final response = await _apiService.post('/auth/phone', data: {'phone': phone});
      debugPrint('✅ OTP request successful: ${response.statusCode}');
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('❌ OTP request failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: _formatError(e, 'Failed to send verification code.'),
      );
    }
  }

  Future<void> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final deviceId = await getOrCreateDeviceId();
      
      final response = await _apiService.post('/auth/verify', data: {
        'phone': phone,
        'code': otp,
        'device_id': deviceId,
        'device_type': 'desktop',
      });
      
      // Support multiple response shapes: token, access_token, or data.token
      final data = response.data is Map ? response.data as Map<String, dynamic> : <String, dynamic>{};
      final nested = data['data'] is Map ? data['data'] as Map<String, dynamic> : null;
      final token = data['token'] as String? ??
          data['access_token'] as String? ??
          nested?['token'] as String?;
      final user = data['user'] ?? nested?['user'];
      final accountId = data['account_id'] ?? nested?['account_id'];
      
      if (token != null && token.isNotEmpty) {
        await _apiService.saveToken(token);
        _apiService.setPendingAuthToken(token);
        
        if (user != null && user is Map && user['id'] != null) {
          final prefs = await SharedPreferences.getInstance();
          final rawId = user['id'];
          final userId = rawId is int ? rawId : (rawId as num).toInt();
          await prefs.setInt('user_id', userId);
          // Store phone number for account-specific database paths
          await prefs.setString('user_phone', phone);
          final accountIdInt = accountId is int ? accountId : (accountId != null ? int.tryParse(accountId.toString()) : null);
          if (accountIdInt != null) {
            await prefs.setInt('current_account_id', accountIdInt);
          }
        }
        
        state = state.copyWith(isLoading: false, token: token);
        await bootstrapAfterAuth(_ref);
      } else {
        state = state.copyWith(isLoading: false, error: 'No token received');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatError(e, 'Verification failed.'),
      );
    }
  }

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null || token.isEmpty) {
      // No token, user is not logged in
      state = AuthState();
      return;
    }
    
    // Token exists, set it first (already done in _loadTokenFromStorage, but ensure it's set)
    if (state.token != token) {
      state = state.copyWith(token: token);
    }
    
    // Validate token by calling /me endpoint to ensure it's still valid
    try {
      final response = await _apiService.getProfile();
      if (response.statusCode == 200 && response.data != null) {
        // Token is valid, update state and user ID
        final userId = response.data['id'];
        if (userId != null) {
          await prefs.setInt('user_id', userId);
        }
        // Token is already set, just ensure state is consistent
        if (state.token != token) {
          state = state.copyWith(token: token);
        }
        await bootstrapAfterAuth(_ref);
      } else {
        // Token is invalid, clear it
        await logout();
      }
    } catch (e) {
      // Only clear token if it's a 401 (Unauthorized) error
      // Network errors should not clear a potentially valid token
      if (e is DioException && e.response?.statusCode == 401) {
        debugPrint('⚠️ Token is invalid (401): $e');
        await logout();
      } else {
        // For network errors, keep the token and try again later
        debugPrint('⚠️ Token validation failed (network error, keeping token): $e');
        // Token stays in state, will be validated on next check
      }
    }
  }

  Future<void> logout() async {
    try {
      await _ref.read(pusherServiceProvider).disconnect();
      NotificationManager.reset();
    } catch (e) {
      debugPrint('⚠️ Logout realtime cleanup: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_phone'); // Clear phone number on logout
    await prefs.remove('current_account_id');
    state = AuthState();
  }
}

