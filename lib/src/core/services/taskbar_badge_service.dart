import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import '../../features/chats/chat_repo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'badge_icon_generator.dart';

// Windows-specific taskbar support
import 'package:windows_taskbar/windows_taskbar.dart';

class TaskbarBadgeService {
  final Ref _ref;
  int _lastUnreadCount = 0;

  TaskbarBadgeService(this._ref);

  /// Calculate total unread messages from conversations and groups
  Future<int> _calculateTotalUnreadCount() async {
    try {
      final chatRepo = _ref.read(chatRepositoryProvider);
      
      // Get conversations and groups
      final conversations = await chatRepo.getConversations();
      final groups = await chatRepo.getGroups();
      
      // Sum unread counts
      int totalUnread = 0;
      
      // Count unread conversations (excluding archived)
      for (final conv in conversations) {
        if (conv.archivedAt == null && conv.unreadCount > 0) {
          totalUnread += conv.unreadCount;
        }
      }
      
      // Count unread groups
      for (final group in groups) {
        if (group.unreadCount > 0) {
          totalUnread += group.unreadCount;
        }
      }
      
      return totalUnread;
    } catch (e) {
      debugPrint('Error calculating unread count: $e');
      return 0;
    }
  }

  /// Update the taskbar badge with unread message count
  Future<void> updateBadge() async {
    try {
      final unreadCount = await _calculateTotalUnreadCount();
      
      // Only update if count changed
      if (unreadCount != _lastUnreadCount) {
        _lastUnreadCount = unreadCount;
        
        // Debug platform detection
        debugPrint('🔍 Platform check - isWindows: ${Platform.isWindows}, isMacOS: ${Platform.isMacOS}, isLinux: ${Platform.isLinux}');
        
        if (Platform.isWindows) {
          // Use Windows-specific taskbar badge
          await _updateWindowsBadge(unreadCount);
        } else if (Platform.isMacOS) {
          // Use macOS-specific badge (window_manager)
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
      if (unreadCount > 0) {
        // Generate badge icon
        final iconPath = await BadgeIconGenerator.generateBadgeIcon(unreadCount);
        
        // Verify the file exists
        final iconFile = File(iconPath);
        if (!await iconFile.exists()) {
          debugPrint('⚠️ Badge icon file does not exist: $iconPath');
          return;
        }
        
        // Set overlay icon on Windows taskbar
        // WindowsTaskbar.setOverlayIcon expects a ThumbnailToolbarAssetIcon
        WindowsTaskbar.setOverlayIcon(
          ThumbnailToolbarAssetIcon(iconPath),
        );
        
        final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();
        debugPrint('📊 Windows taskbar badge updated: $badgeText (icon: $iconPath, exists: ${await iconFile.exists()})');
      } else {
        // Clear badge using resetOverlayIcon
        WindowsTaskbar.resetOverlayIcon();
        debugPrint('📊 Windows taskbar badge cleared');
      }
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
    } catch (e) {
      debugPrint('Error clearing taskbar badge: $e');
    }
  }
}

final taskbarBadgeServiceProvider = Provider<TaskbarBadgeService>((ref) {
  return TaskbarBadgeService(ref);
});
