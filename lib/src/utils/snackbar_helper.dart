import 'dart:async';

import 'package:flutter/material.dart';

import '../core/global_navigator_key.dart';

/// Toast-style feedback at the bottom of the screen (matches mobile GekyChat).
///
/// Compact, centered pill built on [OverlayEntry] instead of [SnackBar], so
/// short messages like "Copied" or "Message deleted" don't stretch full-width.
class SnackbarHelper {
  SnackbarHelper._();

  static _ActiveToast? _current;
  static Timer? _timer;

  static OverlayState? _overlay([BuildContext? context]) {
    if (context != null && context.mounted) {
      final local = Overlay.maybeOf(context, rootOverlay: true);
      if (local != null) return local;
    }
    final rootState = rootNavigatorKey.currentState;
    if (rootState?.overlay != null) return rootState!.overlay;
    final rootCtx = rootNavigatorKey.currentContext;
    if (rootCtx != null) return Overlay.maybeOf(rootCtx, rootOverlay: true);
    return null;
  }

  static Color _toastSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1E2428) : const Color(0xFF32373A);
  }

  static double _bottomInset(BuildContext context) {
    // Desktop: sit a little higher than mobile safe-area padding.
    return 24 + MediaQuery.paddingOf(context).bottom;
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF4CAF50),
      duration: duration,
      action: action,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFEF5350),
      duration: duration,
      action:
          action ??
          SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white70,
            onPressed: () => hide(context),
          ),
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFFFB74D),
      duration: duration,
      action: action,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF64B5F6),
      duration: duration,
      action: action,
    );
  }

  static void showWithUndo(
    BuildContext context,
    String message,
    VoidCallback onUndo, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context: context,
      message: message,
      duration: duration,
      action: SnackBarAction(
        label: 'Undo',
        textColor: const Color(0xFF64B5F6),
        onPressed: onUndo,
      ),
    );
  }

  static void showWithRetry(
    BuildContext context,
    String message,
    VoidCallback onRetry, {
    Duration duration = const Duration(seconds: 5),
  }) {
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

  static void showCustom(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    IconData? icon,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    _present(
      context: context,
      duration: duration,
      builder: (ctx, dismiss) => _ToastPill(
        message: message,
        surface: backgroundColor,
        icon: icon,
        iconColor: Colors.white,
        action: action,
        onDismiss: dismiss,
      ),
    );
  }

  /// Returns a function to dismiss the loading toast.
  static VoidCallback showLoading(BuildContext context, String message) {
    return _present(
      context: context,
      duration: const Duration(days: 1),
      builder: (ctx, _) => _ToastPill(
        message: message,
        surface: _toastSurface(ctx),
        loading: true,
      ),
    );
  }

  static void hide(BuildContext context) => _dismissCurrent();

  static void showSuccessGlobal(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    showSuccess(ctx, message, duration: duration);
  }

  static void showErrorGlobal(String message) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    showError(ctx, message);
  }

  static void showInfoGlobal(String message) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    showInfo(ctx, message);
  }

  static void _show({
    required BuildContext context,
    required String message,
    IconData? icon,
    Color? iconColor,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    _present(
      context: context,
      duration: duration,
      builder: (ctx, dismiss) => _ToastPill(
        message: message,
        icon: icon,
        iconColor: iconColor,
        surface: _toastSurface(ctx),
        action: action,
        onDismiss: dismiss,
      ),
    );
  }

  static VoidCallback _present({
    required BuildContext context,
    required Duration duration,
    required Widget Function(BuildContext context, VoidCallback dismiss)
    builder,
  }) {
    final overlay = _overlay(context);
    if (overlay == null) return () {};

    _dismissCurrent(immediate: true);

    final visible = ValueNotifier<bool>(true);
    late final OverlayEntry entry;
    var removed = false;

    void removeNow() {
      if (removed) return;
      removed = true;
      entry.remove();
      visible.dispose();
    }

    void dismiss() {
      if (removed) return;
      _timer?.cancel();
      _timer = null;
      if (identical(_current?.removeNow, removeNow)) _current = null;
      visible.value = false;
      Future.delayed(const Duration(milliseconds: 180), removeNow);
    }

    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlayEntry(
        visible: visible,
        bottomInset: _bottomInset(ctx),
        child: builder(ctx, dismiss),
      ),
    );

    _current = _ActiveToast(dismiss: dismiss, removeNow: removeNow);
    overlay.insert(entry);

    if (duration < const Duration(days: 1)) {
      _timer = Timer(duration, dismiss);
    }

    return dismiss;
  }

  static void _dismissCurrent({bool immediate = false}) {
    final current = _current;
    if (current == null) return;
    _current = null;
    _timer?.cancel();
    _timer = null;
    if (immediate) {
      current.removeNow();
    } else {
      current.dismiss();
    }
  }
}

class _ActiveToast {
  _ActiveToast({required this.dismiss, required this.removeNow});
  final VoidCallback dismiss;
  final VoidCallback removeNow;
}

class _ToastOverlayEntry extends StatelessWidget {
  const _ToastOverlayEntry({
    required this.visible,
    required this.bottomInset,
    required this.child,
  });

  final ValueNotifier<bool> visible;
  final double bottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset,
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, isVisible, _) {
          return AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
            offset: isVisible ? Offset.zero : const Offset(0, 0.35),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isVisible ? 1 : 0,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({
    required this.message,
    required this.surface,
    this.icon,
    this.iconColor,
    this.action,
    this.onDismiss,
    this.loading = false,
  });

  final String message;
  final Color surface;
  final IconData? icon;
  final Color? iconColor;
  final SnackBarAction? action;
  final VoidCallback? onDismiss;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 32;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else if (icon != null) ...[
                  Icon(icon, color: iconColor ?? Colors.white, size: 20),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      onDismiss?.call();
                      action!.onPressed();
                    },
                    child: Text(
                      action!.label,
                      style: TextStyle(
                        color: action!.textColor ?? const Color(0xFF64B5F6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension SnackbarExtension on BuildContext {
  void showSuccessToast(String message, {SnackBarAction? action}) {
    SnackbarHelper.showSuccess(this, message, action: action);
  }

  void showErrorToast(String message, {SnackBarAction? action}) {
    SnackbarHelper.showError(this, message, action: action);
  }

  void showWarningToast(String message, {SnackBarAction? action}) {
    SnackbarHelper.showWarning(this, message, action: action);
  }

  void showInfoToast(String message, {SnackBarAction? action}) {
    SnackbarHelper.showInfo(this, message, action: action);
  }

  void showUndoToast(String message, VoidCallback onUndo) {
    SnackbarHelper.showWithUndo(this, message, onUndo);
  }

  VoidCallback showLoadingToast(String message) {
    return SnackbarHelper.showLoading(this, message);
  }

  // Legacy desktop names (same overlay toast).
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

  VoidCallback showLoadingSnackbar(String message) {
    return SnackbarHelper.showLoading(this, message);
  }

  void showUndoSnackbar(String message, VoidCallback onUndo) {
    SnackbarHelper.showWithUndo(this, message, onUndo);
  }

  void showRetrySnackbar(String message, VoidCallback onRetry) {
    SnackbarHelper.showWithRetry(this, message, onRetry);
  }
}
