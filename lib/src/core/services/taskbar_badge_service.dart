import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import '../../features/chats/sidebar_inbox_bump.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'badge_icon_generator.dart';
import 'system_tray_service.dart';

// Windows-specific taskbar support
import 'package:windows_taskbar/windows_taskbar.dart';

class TaskbarBadgeService {
  final Ref _ref;
  int _lastUnreadCount = 0;

  TaskbarBadgeService(this._ref);

  /// Matches sidebar list badges (merged providers, no channels/archived).
  int _calculateTotalUnreadCount() {
    try {
      return _ref.read(sidebarUnreadTotalProvider);
    } catch (e) {
      debugPrint('Error calculating unread count: $e');
      return 0;
    }
  }

  /// Update the taskbar badge with unread message count
  /// For testing: Always show badge even when app is open
  Future<void> updateBadge() async {
    try {
      final unreadCount = _calculateTotalUnreadCount();
      await SystemTrayService.updateUnreadIndicator(unreadCount);

      if (unreadCount != _lastUnreadCount) {
        _lastUnreadCount = unreadCount;
        
        debugPrint('🔍 Platform check - isWindows: ${Platform.isWindows}, isMacOS: ${Platform.isMacOS}, isLinux: ${Platform.isLinux}');
        debugPrint('📊 Updating badge with unread count: $unreadCount');
        
        if (Platform.isWindows) {
          await _updateWindowsBadge(unreadCount);
        } else if (Platform.isMacOS) {
          await _updateMacOSBadge(unreadCount);
        } else {
          debugPrint('⚠️ Taskbar badge not supported on this platform (unread: $unreadCount)');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error updating taskbar badge: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Update badge on Windows using windows_taskbar package
  Future<void> _updateWindowsBadge(int unreadCount) async {
    try {
      if (unreadCount == 0) {
        WindowsTaskbar.resetOverlayIcon();
        debugPrint('📊 Windows taskbar badge cleared');
        return;
      }

      // Overlay only applies when the window is on the taskbar (not hide-to-tray).
      final skipTaskbar = await windowManager.isSkipTaskbar();
      if (skipTaskbar) {
        debugPrint(
          '📊 Windows taskbar badge skipped (app hidden from taskbar — see tray icon)',
        );
        return;
      }

      final iconPath = await BadgeIconGenerator.generateBadgeIcon(unreadCount);

      final iconFile = File(iconPath);
      if (!await iconFile.exists()) {
        debugPrint('⚠️ Badge icon file does not exist: $iconPath');
        return;
      }
      if (!iconPath.toLowerCase().endsWith('.ico')) {
        debugPrint('⚠️ Badge icon must be .ico for Windows taskbar: $iconPath');
        return;
      }

      WindowsTaskbar.setOverlayIcon(
        ThumbnailToolbarAssetIcon(iconPath),
      );
      
      final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();
      debugPrint('📊 Windows taskbar badge updated: $badgeText (icon: $iconPath, exists: ${await iconFile.exists()})');
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating Windows taskbar badge: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Update badge on macOS using window_manager
  Future<void> _updateMacOSBadge(int unreadCount) async {
    try {
      if (unreadCount > 0) {
        // Show badge with count (max 99+)
        final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();
        await windowManager.setBadgeLabel(badgeText);
        debugPrint('📊 macOS taskbar badge updated: $badgeText');
      } else {
        // Clear badge
        await windowManager.setBadgeLabel('');
        debugPrint('📊 macOS taskbar badge cleared');
      }
    } catch (e) {
      debugPrint('Error updating macOS taskbar badge: $e');
    }
  }

  /// Clear the badge
  Future<void> clearBadge() async {
    try {
      if (Platform.isWindows) {
        WindowsTaskbar.resetOverlayIcon();
      } else if (Platform.isMacOS) {
        await windowManager.setBadgeLabel('');
      }
      _lastUnreadCount = 0;
      debugPrint('📊 Taskbar badge cleared');
      await SystemTrayService.updateUnreadIndicator(0);
    } catch (e) {
      debugPrint('Error clearing taskbar badge: $e');
    }
  }
}

final taskbarBadgeServiceProvider = Provider<TaskbarBadgeService>((ref) {
  return TaskbarBadgeService(ref);
});
