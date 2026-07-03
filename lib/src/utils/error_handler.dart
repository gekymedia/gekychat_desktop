import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'snackbar_helper.dart';

/// Enhanced error handler with user-friendly messages and recovery actions
class ErrorHandler {
  /// Convert technical errors to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }
    
    final errorStr = error.toString().toLowerCase();
    
    // Network errors
    if (errorStr.contains('socket') || errorStr.contains('network')) {
      return 'Network connection failed. Please check your internet connection.';
    }
    
    // Timeout errors
    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    
    // Authentication errors
    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Session expired. Please log in again.';
    }
    
    // Permission errors
    if (errorStr.contains('forbidden') || errorStr.contains('403')) {
      return 'You don\'t have permission to perform this action.';
    }
    
    // Not found errors
    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'The requested resource was not found.';
    }
    
    // Server errors
    if (errorStr.contains('500') || errorStr.contains('server error')) {
      return 'Server error. Please try again later.';
    }
    
    // Generic fallback
    return 'Something went wrong. Please try again.';
  }

  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet and try again.';
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 400:
            return 'Invalid request. Please check your input.';
          case 401:
            return 'Session expired. Please log in again.';
          case 403:
            return 'Access denied. You don\'t have permission.';
          case 404:
            return 'Resource not found.';
          case 429:
            return 'Too many requests. Please wait a moment.';
          case 500:
          case 502:
          case 503:
            return 'Server is temporarily unavailable. Please try again.';
          default:
            return 'Server error (${statusCode ?? 'unknown'}). Please try again.';
        }
      
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      default:
        return 'Network error. Please check your connection.';
    }
  }

  /// Show error with automatic retry option
  static void showError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    bool showRetry = true,
  }) {
    final message = getUserFriendlyMessage(error);
    
    if (showRetry && onRetry != null) {
      SnackbarHelper.showWithRetry(context, message, onRetry);
    } else {
      SnackbarHelper.showError(context, message);
    }
  }

  /// Show error with error code for support
  static void showErrorWithCode(
    BuildContext context,
    dynamic error, {
    String? errorCode,
  }) {
    final message = getUserFriendlyMessage(error);
    final codeStr = errorCode ?? _extractErrorCode(error);
    
    SnackbarHelper.showError(
      context,
      codeStr != null ? '$message\nError code: $codeStr' : message,
    );
  }

  static String? _extractErrorCode(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return 'HTTP_$statusCode';
      }
    }
    return null;
  }

  /// Handle errors in async operations with automatic UI feedback
  static Future<T?> handleAsync<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    VoidCallback? onRetry,
    bool showLoading = true,
  }) async {
    void Function()? dismissLoading;
    
    if (showLoading && loadingMessage != null) {
      dismissLoading = SnackbarHelper.showLoading(context, loadingMessage);
    }
    
    try {
      final result = await operation();
      
      dismissLoading?.call();
      
      if (successMessage != null && context.mounted) {
        SnackbarHelper.showSuccess(context, successMessage);
      }
      
      return result;
    } catch (error) {
      dismissLoading?.call();
      
      if (context.mounted) {
        showError(context, error, onRetry: onRetry);
      }
      
      return null;
    }
  }

  /// Check if error is recoverable
  static bool isRecoverable(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true; // Network issues are usually temporary
        
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          // Server errors and rate limits are usually temporary
          return statusCode == 429 || 
                 statusCode == 500 || 
                 statusCode == 502 || 
                 statusCode == 503;
        
        default:
          return false;
      }
    }
    
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socket') || 
           errorStr.contains('network') || 
           errorStr.contains('timeout');
  }

  /// Get suggested action for error
  static String getSuggestedAction(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Check your internet connection and try again.';
        
        case DioExceptionType.connectionError:
          return 'Make sure you\'re connected to the internet.';
        
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          switch (statusCode) {
            case 401:
              return 'Please log in again.';
            case 403:
              return 'Contact support if you believe this is an error.';
            case 429:
              return 'Wait a moment before trying again.';
            case 500:
            case 502:
            case 503:
              return 'Try again in a few moments.';
            default:
              return 'Please try again.';
          }
        
        default:
          return 'Please try again.';
      }
    }
    
    return 'Please try again or contact support if the issue persists.';
  }
}

/// Extension to make error handling more convenient
extension ErrorHandlerExtension on BuildContext {
  void showErrorMessage(dynamic error, {VoidCallback? onRetry}) {
    ErrorHandler.showError(this, error, onRetry: onRetry);
  }

  Future<T?> handleAsyncOperation<T>(
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    VoidCallback? onRetry,
  }) {
    return ErrorHandler.handleAsync(
      this,
      operation,
      loadingMessage: loadingMessage,
      successMessage: successMessage,
      onRetry: onRetry,
    );
  }
}
