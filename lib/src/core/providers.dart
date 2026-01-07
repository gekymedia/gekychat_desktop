import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../features/realtime/pusher_service.dart';

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

