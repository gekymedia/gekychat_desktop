import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/phone_login.dart';
import 'features/auth/otp_verify.dart';
import 'features/chats/desktop_chat_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/profile/profile_edit_screen.dart';
import 'features/quick_replies/quick_replies_screen.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/search/search_screen.dart';
import 'features/status/create_status_screen.dart';
import 'features/chats/create_group_screen.dart';
import 'features/calls/calls_screen.dart';
import 'features/channels/channels_screen.dart';
import 'features/starred/starred_screen.dart';
import 'features/archive/archived_screen.dart';
import 'features/broadcast/broadcast_lists_screen.dart';
import 'features/two_factor/two_factor_screen.dart';
import 'features/linked_devices/linked_devices_screen.dart';
import 'features/privacy/privacy_settings_screen.dart';
import 'features/storage/storage_usage_screen.dart';
import 'features/media_auto_download/media_auto_download_screen.dart';
import 'features/notifications/notification_settings_screen.dart';
import 'features/world/world_feed_screen.dart';
import 'features/mail/mail_screen.dart';
import 'features/ai/ai_chat_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
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
      GoRoute(
        path: '/chats',
        builder: (context, state) => const DesktopChatScreen(),
      ),
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
        path: '/calls',
        builder: (context, state) => const CallsScreen(),
      ),
      GoRoute(
        path: '/channels',
        builder: (context, state) => const ChannelsScreen(),
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
      // PHASE 2: New Features
      GoRoute(
        path: '/world',
        builder: (context, state) => const WorldFeedScreen(),
      ),
      GoRoute(
        path: '/mail',
        builder: (context, state) => const MailScreen(),
      ),
      GoRoute(
        path: '/ai',
        builder: (context, state) => const AiChatScreen(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.token != null;
      final isLoggingIn = state.uri.path == '/login';
      final isVerifying = state.uri.path == '/verify';

      if (!isLoggedIn && !isLoggingIn && !isVerifying) return '/login';
      if (isLoggedIn && (isLoggingIn || isVerifying)) return '/chats';
      return null;
    },
  );
});

