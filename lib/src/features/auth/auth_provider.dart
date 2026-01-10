import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/providers.dart';
import '../../core/api_service.dart';
import '../../core/device_id.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AuthNotifier(apiService);
});

class AuthState {
  final bool isLoading;
  final String? token;
  final String? error;

  AuthState({this.isLoading = false, this.token, this.error});

  AuthState copyWith({bool? isLoading, String? token, String? error}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;

  AuthNotifier(this._apiService) : super(AuthState()) {
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
            return 'Redirect error (${statusCode}). The server redirected to: $location\nCurrent API URL: ${_apiService.baseUrl}/auth/phone\nPlease check API_BASE_URL in .env file.';
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
      await _apiService.post('/auth/phone', data: {'phone': phone});
      state = state.copyWith(isLoading: false);
    } catch (e) {
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
      
      final token = response.data['token'];
      final user = response.data['user'];
      final accountId = response.data['account_id'];
      
      if (token != null) {
        await _apiService.saveToken(token);
        
        if (user != null && user['id'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', user['id']);
          if (accountId != null) {
            await prefs.setInt('current_account_id', accountId);
          }
        }
        
        state = state.copyWith(isLoading: false, token: token);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    state = AuthState();
  }
}

