import 'package:flutter/material.dart';

/// Standardized snackbar helper for consistent UX across the app
/// Provides consistent colors, durations, and action buttons
class SnackbarHelper {
  /// Show a success snackbar (green background)
  /// Duration: 2 seconds (quick positive feedback)
  static void showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50), // Material Green
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show an error snackbar (red background)
  /// Duration: 4 seconds (users need more time to read errors)
  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F), // Material Red
        duration: duration,
        action: action ?? SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show a warning snackbar (orange background)
  /// Duration: 3 seconds
  static void showWarning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF9800), // Material Orange
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show an info snackbar (blue background)
  /// Duration: 3 seconds
  static void showInfo(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3), // Material Blue
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show a loading snackbar (gray background, no auto-dismiss)
  /// Returns a function to dismiss it when done
  static void Function() showLoading(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return () {};
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF616161), // Material Gray
        duration: const Duration(days: 1), // Effectively infinite
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    
    // Return dismiss function
    return () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    };
  }

  /// Show a custom snackbar with full control
  static void showCustom(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    IconData? icon,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show a snackbar with an undo action
  static void showWithUndo(
    BuildContext context,
    String message,
    VoidCallback onUndo, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF616161), // Material Gray
        duration: duration,
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF64B5F6), // Light Blue
          onPressed: onUndo,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show a snackbar with a retry action (for errors)
  static void showWithRetry(
    BuildContext context,
    String message,
    VoidCallback onRetry, {
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!context.mounted) return;
    
    showError(
      context,
      message,
      duration: duration,
      action: SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: onRetry,
      ),
    );
  }
}

/// Extension on BuildContext for convenient snackbar access
extension SnackbarExtension on BuildContext {
  void showSuccessSnackbar(String message, {SnackBarAction? action}) {
    SnackbarHelper.showSuccess(this, message, action: action);
  }

  void showErrorSnackbar(String message, {SnackBarAction? action}) {
    SnackbarHelper.showError(this, message, action: action);
  }

  void showWarningSnackbar(String message, {SnackBarAction? action}) {
    SnackbarHelper.showWarning(this, message, action: action);
  }

  void showInfoSnackbar(String message, {SnackBarAction? action}) {
    SnackbarHelper.showInfo(this, message, action: action);
  }

  void Function() showLoadingSnackbar(String message) {
    return SnackbarHelper.showLoading(this, message);
  }

  void showUndoSnackbar(String message, VoidCallback onUndo) {
    SnackbarHelper.showWithUndo(this, message, onUndo);
  }

  void showRetrySnackbar(String message, VoidCallback onRetry) {
    SnackbarHelper.showWithRetry(this, message, onRetry);
  }
}
