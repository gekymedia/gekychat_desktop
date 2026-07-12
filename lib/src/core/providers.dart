import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../features/realtime/pusher_service.dart';
import '../features/chats/models.dart';
import '../services/delivery_confirmation_service.dart';

// Re-export database providers for convenience
export 'database/local_storage_service.dart' show localStorageServiceProvider, appDatabaseProvider;
export 'database/message_queue_service.dart' show messageQueueServiceProvider;

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final apiProvider = apiServiceProvider;

final sharedPreferencesProvider = Provider<Future<SharedPreferences>>(
  (ref) => SharedPreferences.getInstance(),
);

final pusherServiceProvider = Provider<PusherService>((ref) => PusherService());

final deliveryConfirmationServiceProvider = Provider<DeliveryConfirmationService>((ref) {
  return DeliveryConfirmationService(ref.read(apiServiceProvider));
});

// Theme Provider
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode') ?? 'system';
    state = ThemeMode.values.firstWhere(
      (mode) => mode.toString() == 'ThemeMode.$themeString',
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString().split('.').last);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());

// Current section provider for desktop navigation
class CurrentSectionNotifier extends StateNotifier<String> {
  CurrentSectionNotifier() : super('/chats');
  
  void setSection(String section) {
    state = section;
  }
}

final currentSectionProvider = StateNotifierProvider<CurrentSectionNotifier, String>((ref) => CurrentSectionNotifier());

// Conversation selection provider for programmatic selection
class SelectedConversationNotifier extends StateNotifier<int?> {
  SelectedConversationNotifier() : super(null);
  
  void selectConversation(int conversationId) {
    state = conversationId;
  }
  
  void clearSelection() {
    state = null;
  }
}

final selectedConversationProvider = StateNotifierProvider<SelectedConversationNotifier, int?>((ref) => SelectedConversationNotifier());

/// Currently open group in the desktop chat pane (for mark-read + notification suppression).
final selectedGroupIdProvider = StateProvider<int?>((ref) => null);

// Provider for sounds preference
final soundsEnabledProvider = StateNotifierProvider<SoundsNotifier, bool>((ref) {
  return SoundsNotifier();
});

final showForwardedMarkProvider =
    StateNotifierProvider<ShowForwardedMarkNotifier, bool>((ref) {
  return ShowForwardedMarkNotifier();
});

class ShowForwardedMarkNotifier extends StateNotifier<bool> {
  ShowForwardedMarkNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('show_forwarded_mark') ?? true;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_forwarded_mark', value);
  }
}

class SoundsNotifier extends StateNotifier<bool> {
  SoundsNotifier() : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('sounds_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sounds_enabled', enabled);
  }
}

// World feed: open a specific post from chat links or deep links (same URLs as mobile).
final worldFeedNavigateToPostProvider = StateProvider<int?>((ref) => null);
final worldFeedNavigateToPostSlugProvider = StateProvider<String?>((ref) => null);
final worldFeedInitialPostProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Open a DM from status viewer with a pending status reference on the next send.
final pendingDesktopStatusChatOpenProvider =
    StateProvider<DesktopPendingStatusChatOpen?>((ref) => null);

/// Open a DM from group "Reply privately" with a pending group message reference.
final pendingDesktopGroupPrivateOpenProvider =
    StateProvider<DesktopPendingGroupPrivateOpen?>((ref) => null);

/// Tap on a group-referenced strip in a DM: jump to this group and message.
typedef DesktopGroupDeepLink = ({int groupId, int messageId});
final pendingDesktopGroupDeepLinkProvider =
    StateProvider<DesktopGroupDeepLink?>((ref) => null);

/// Select a group chat from imperative navigation (e.g. minimized call overlay).
final pendingDesktopGroupSelectProvider = StateProvider<int?>((ref) => null);

/// Open a group chat immediately after creation (before `/groups` sync completes).
final pendingDesktopGroupOpenProvider = StateProvider<GroupSummary?>((ref) => null);

/// Prefill DM composer (e.g. birthday wish).
final pendingDesktopComposerDraftProvider =
    StateProvider<DesktopPendingComposerDraft?>((ref) => null);
