import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Window show/hide helpers for desktop tray behavior (WhatsApp-style).
class DesktopWindowService {
  DesktopWindowService._();

  /// Match the native title bar (min/max/close) to the in-app light/dark theme.
  static Future<void> syncTitleBarTheme(bool isDark) async {
    try {
      await windowManager.setBrightness(
        isDark ? Brightness.dark : Brightness.light,
      );
    } catch (e) {
      debugPrint('syncTitleBarTheme failed: $e');
    }
  }

  static Future<void> showMainWindow() async {
    await windowManager.setSkipTaskbar(false);
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  /// Close (X): hide from taskbar but keep running — notifications + tray icon stay active.
  static Future<void> hideToTray() async {
    await windowManager.setSkipTaskbar(true);
    await windowManager.hide();
  }
}
