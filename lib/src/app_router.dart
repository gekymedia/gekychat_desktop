import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/phone_login.dart';
import 'features/auth/otp_verify.dart';
import 'features/chats/desktop_chat_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/profile/profile_edit_screen.dart';
import 'features/quick_replies/quick_replies_screen.dart';
import 'features/auto_reply/auto_reply_screen.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/search/search_screen.dart';
import 'features/status/create_status_screen.dart';
import 'features/chats/create_group_screen.dart';
import 'features/starred/starred_screen.dart';
import 'features/archive/archived_screen.dart';
import 'features/broadcast/broadcast_lists_screen.dart';
import 'features/two_factor/two_factor_screen.dart';
import 'features/linked_devices/linked_devices_screen.dart';
import 'features/privacy/privacy_settings_screen.dart';
import 'features/storage/storage_usage_screen.dart';
import 'features/media_auto_download/media_auto_download_screen.dart';
import 'features/notifications/notification_settings_screen.dart';

// ChangeNotifier to trigger router refresh when auth state changes
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

final routerRefreshNotifierProvider = Provider((ref) {
  final notifier = _RouterRefreshNotifier();
  
  // Listen to auth state changes and refresh router
  ref.listen<AuthState>(authProvider, (previous, next) {
    // When auth state changes (e.g., token is loaded), refresh router
    notifier.refresh();
  });
  
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state - when it changes, router provider will rebuild
  final authState = ref.watch(authProvider);
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);
  
  // Determine initial location based on auth state
  final initialLocation = (authState.token != null && authState.token!.isNotEmpty) ? '/chats' : '/login';
  
  return GoRouter(
    initialLocation: initialLocation, // Set initial location based on auth state
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpVerifyScreen(phone: phone);
        },
      ),
      // Main app layout - all routes that should have sidebar
      GoRoute(
        path: '/chats',
        builder: (context, state) => const DesktopChatScreen(),
      ),
      // Routes that should use DesktopChatScreen layout with sidebar
      GoRoute(
        path: '/channels',
        builder: (context, state) => const DesktopChatScreen(),
      ),
      GoRoute(
        path: '/world',
        builder: (context, state) => const DesktopChatScreen(),
      ),
      GoRoute(
        path: '/mail',
        builder: (context, state) => const DesktopChatScreen(),
      ),
      GoRoute(
        path: '/ai',
        builder: (context, state) => const DesktopChatScreen(),
      ),
      GoRoute(
        path: '/calls',
        builder: (context, state) => const DesktopChatScreen(),
      ),
      GoRoute(
        path: '/status',
        builder: (context, state) => const DesktopChatScreen(),
      ),
      GoRoute(
        path: '/live-broadcast',
        builder: (context, state) => const DesktopChatScreen(),
      ),
      // Settings and other screens (full screen)
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/quick-replies',
        builder: (context, state) => const QuickRepliesScreen(),
      ),
      GoRoute(
        path: '/auto-replies',
        builder: (context, state) => const AutoReplyScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/status/create',
        builder: (context, state) => const CreateStatusScreen(),
      ),
      GoRoute(
        path: '/create-group',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/starred',
        builder: (context, state) => const StarredMessagesScreen(),
      ),
      GoRoute(
        path: '/archived',
        builder: (context, state) => const ArchivedConversationsScreen(),
      ),
      GoRoute(
        path: '/broadcast-lists',
        builder: (context, state) => const BroadcastListsScreen(),
      ),
      GoRoute(
        path: '/two-factor',
        builder: (context, state) => const TwoFactorScreen(),
      ),
      GoRoute(
        path: '/linked-devices',
        builder: (context, state) => const LinkedDevicesScreen(),
      ),
      GoRoute(
        path: '/privacy-settings',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/storage-usage',
        builder: (context, state) => const StorageUsageScreen(),
      ),
      GoRoute(
        path: '/media-auto-download',
        builder: (context, state) => const MediaAutoDownloadScreen(),
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = authState.token != null && authState.token!.isNotEmpty;
      final currentPath = state.uri.path;
      final isLoggingIn = currentPath == '/login';
      final isVerifying = currentPath == '/verify';
      final isOnAuthPage = isLoggingIn || isVerifying;

      // Allow verify page to be accessed even if not logged in (for OTP flow)
      if (isVerifying) {
        return null;
      }

      // If not logged in and trying to access protected routes, go to login
      if (!isLoggedIn && !isOnAuthPage) {
        return '/login';
      }
      
      // If logged in and on login page, redirect to chats
      if (isLoggedIn && isLoggingIn) {
        return '/chats';
      }
      
      return null;
    },
  );
});
