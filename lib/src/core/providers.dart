import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../features/realtime/pusher_service.dart';
import 'providers/connectivity_provider.dart';
import 'database/local_storage_service.dart';
import 'database/app_database.dart';
import 'database/message_queue_service.dart';
import 'services/taskbar_badge_service.dart';

// Re-export database providers for convenience
export 'database/local_storage_service.dart' show localStorageServiceProvider, appDatabaseProvider;
export 'database/message_queue_service.dart' show messageQueueServiceProvider;

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final apiProvider = apiServiceProvider;

final sharedPreferencesProvider = Provider<Future<SharedPreferences>>(
  (ref) => SharedPreferences.getInstance(),
);

final pusherServiceProvider = Provider<PusherService>((ref) => PusherService());

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
