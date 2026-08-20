import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_window_service.dart';

/// System tray icon + menu (WhatsApp-style: close/minimize keeps app running in tray).
class SystemTrayService {
  SystemTrayService._();

  static final SystemTray _systemTray = SystemTray();
  static bool _initialized = false;

  /// Windows needs an absolute path to a bundled `.ico` beside the executable.
  static String _trayIconPath() {
    const assetRelative = 'assets/icons/tray_icon.ico';

    if (Platform.isWindows) {
      final releasePath = p.normalize(
        p.join(
          p.dirname(Platform.resolvedExecutable),
          'data',
          'flutter_assets',
          assetRelative,
        ),
      );
      if (File(releasePath).existsSync()) {
        return releasePath;
      }
    }

    if (Platform.isMacOS) {
      return 'AppIcon';
    }

    // Linux / dev fallback — relative asset path (works with `flutter run`).
    return p.join('assets', 'icons', 'gold_no_text', '32x32.png');
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final iconPath = _trayIconPath();
      debugPrint('🖥️ System tray icon path: $iconPath');

      final ok = await _systemTray.initSystemTray(
        title: 'GekyChat',
        iconPath: iconPath,
        toolTip: 'GekyChat',
      );
      if (!ok) {
        debugPrint('⚠️ System tray initSystemTray returned false');
        return;
      }

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Open GekyChat',
          onClicked: (_) => unawaited(DesktopWindowService.showMainWindow()),
        ),
        MenuItemLabel(
          label: 'Hide to tray',
          onClicked: (_) => unawaited(DesktopWindowService.hideToTray()),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Quit GekyChat',
          onClicked: (_) => unawaited(_quitApp()),
        ),
      ]);
      await _systemTray.setContextMenu(menu);

      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          if (Platform.isWindows) {
            unawaited(DesktopWindowService.showMainWindow());
          } else {
            unawaited(_systemTray.popUpContextMenu());
          }
        } else if (eventName == kSystemTrayEventRightClick) {
          if (Platform.isWindows) {
            unawaited(_systemTray.popUpContextMenu());
          } else {
            unawaited(DesktopWindowService.showMainWindow());
          }
        } else if (eventName == kSystemTrayEventDoubleClick) {
          unawaited(DesktopWindowService.showMainWindow());
        }
      });

      _initialized = true;
      debugPrint(
        '✅ System tray ready — close (X) hides to tray; click tray icon to reopen',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to initialize system tray: $e');
    }
  }

  static Future<void> _quitApp() async {
    await windowManager.setPreventClose(false);
    if (_initialized) {
      await _systemTray.destroy();
    }
    await windowManager.destroy();
  }

  /// Overlay count on the tray icon (Windows) + tooltip — used when the taskbar
  /// button is hidden via [DesktopWindowService.hideToTray].
  static Future<void> updateUnreadIndicator(int unreadCount) async {
    if (!_initialized) return;
    try {
      if (unreadCount > 0) {
        final label = unreadCount > 99 ? '99+' : unreadCount.toString();
        await _systemTray.setTitle(label);
        await _systemTray.setToolTip(
          'GekyChat — $label unread message${unreadCount == 1 ? '' : 's'}',
        );
      } else {
        await _systemTray.setTitle('');
        await _systemTray.setToolTip('GekyChat');
      }
    } catch (e) {
      debugPrint('⚠️ System tray unread indicator: $e');
    }
  }
}
