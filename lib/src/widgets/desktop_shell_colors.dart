import 'package:flutter/material.dart';

/// Shared chrome colors for the desktop three-pane shell.
abstract final class DesktopShellColors {
  /// Main chat pane + far-left icon rail (Telegram/WhatsApp-style).
  static Color chatPaneBackground(bool isDark) =>
      isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5);

  /// 1:1 and group chat thread background — same cream as account-switcher modal
  /// ([ThemeData.scaffoldBackgroundColor], classic light `#ECE5DD`).
  static Color chatThreadBackground(BuildContext context, {required bool isDark}) {
    if (isDark) return const Color(0xFF0B141A);
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// Icon rail + window title bar chrome (cream in light, dark shell in dark).
  static Color shellChromeBackground(BuildContext context, {required bool isDark}) =>
      chatThreadBackground(context, isDark: isDark);

  /// Cream for window init before [BuildContext] exists (classic light theme).
  static const Color classicLightCream = Color(0xFFECE5DD);

  static Color shellChromeBackgroundStatic({required bool isDark}) =>
      isDark ? const Color(0xFF0B141A) : classicLightCream;

  /// Conversation list column (white card between rail and chat pane).
  static Color listPanelBackground(bool isDark) =>
      isDark ? const Color(0xFF111B21) : Colors.white;

  static Color listPanelBorder(bool isDark) =>
      isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF);

  /// Divider between icon rail and list column.
  static Color railDivider(bool isDark) =>
      isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF);

  static const double railWidth = 64;

  /// Top-left scoop where the icon rail and title bar meet the chat list panel.
  static const double listPanelTopLeftRadius = 16;

  static BorderRadius get listPanelTopLeftBorderRadius => const BorderRadius.only(
        topLeft: Radius.circular(listPanelTopLeftRadius),
      );

  static const double pillRadius = 999;

  static BorderRadius get pillBorderRadius =>
      BorderRadius.circular(pillRadius);
}
