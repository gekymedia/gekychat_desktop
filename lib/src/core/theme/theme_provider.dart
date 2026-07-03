import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme_mode.dart';
import 'theme_service.dart';

final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier(ref.read(themeServiceProvider));
});

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier(this._themeService) : super(AppThemeMode.classicLight) {
    _loadTheme();
  }

  final ThemeService _themeService;

  Future<void> _loadTheme() async {
    final mode = await _themeService.getThemeMode();
    state = mode;
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _themeService.setThemeMode(mode);
    state = mode;
  }

  Future<void> setColorScheme(ThemeColor themeColor, BuildContext? context) async {
    final isDark = state.isDark;
    final newMode = switch ((themeColor, isDark)) {
      (ThemeColor.classic, false) => AppThemeMode.classicLight,
      (ThemeColor.classic, true) => AppThemeMode.classicDark,
      (ThemeColor.golden, false) => AppThemeMode.goldenLight,
      (ThemeColor.golden, true) => AppThemeMode.goldenDark,
      (ThemeColor.telegram, false) => AppThemeMode.telegramLight,
      (ThemeColor.telegram, true) => AppThemeMode.telegramDark,
      (ThemeColor.blue, false) => AppThemeMode.blueLight,
      (ThemeColor.blue, true) => AppThemeMode.blueDark,
      (ThemeColor.pink, false) => AppThemeMode.pinkLight,
      (ThemeColor.pink, true) => AppThemeMode.pinkDark,
      (ThemeColor.amoled, _) => AppThemeMode.amoledDark,
      (ThemeColor.ios, false) => AppThemeMode.iosLight,
      (ThemeColor.ios, true) => AppThemeMode.iosDark,
    };
    await setThemeMode(newMode);
  }

  Future<void> setBrightness(bool isDark) async {
    final themeColor = state.themeColor;
    final newMode = switch ((themeColor, isDark)) {
      (ThemeColor.classic, false) => AppThemeMode.classicLight,
      (ThemeColor.classic, true) => AppThemeMode.classicDark,
      (ThemeColor.golden, false) => AppThemeMode.goldenLight,
      (ThemeColor.golden, true) => AppThemeMode.goldenDark,
      (ThemeColor.telegram, false) => AppThemeMode.telegramLight,
      (ThemeColor.telegram, true) => AppThemeMode.telegramDark,
      (ThemeColor.blue, false) => AppThemeMode.blueLight,
      (ThemeColor.blue, true) => AppThemeMode.blueDark,
      (ThemeColor.pink, false) => AppThemeMode.pinkLight,
      (ThemeColor.pink, true) => AppThemeMode.pinkDark,
      (ThemeColor.amoled, _) => AppThemeMode.amoledDark,
      (ThemeColor.ios, false) => AppThemeMode.iosLight,
      (ThemeColor.ios, true) => AppThemeMode.iosDark,
    };
    await setThemeMode(newMode);
  }

  Future<void> toggleBrightness() async {
    final newMode = switch (state) {
      AppThemeMode.classicLight => AppThemeMode.classicDark,
      AppThemeMode.classicDark => AppThemeMode.classicLight,
      AppThemeMode.goldenLight => AppThemeMode.goldenDark,
      AppThemeMode.goldenDark => AppThemeMode.goldenLight,
      AppThemeMode.telegramLight => AppThemeMode.telegramDark,
      AppThemeMode.telegramDark => AppThemeMode.telegramLight,
      AppThemeMode.blueLight => AppThemeMode.blueDark,
      AppThemeMode.blueDark => AppThemeMode.blueLight,
      AppThemeMode.pinkLight => AppThemeMode.pinkDark,
      AppThemeMode.pinkDark => AppThemeMode.pinkLight,
      AppThemeMode.amoledDark => AppThemeMode.amoledDark,
      AppThemeMode.iosLight => AppThemeMode.iosDark,
      AppThemeMode.iosDark => AppThemeMode.iosLight,
    };
    await setThemeMode(newMode);
  }

  Future<void> toggleColorScheme() async {
    final newColor =
        state.themeColor == ThemeColor.golden ? ThemeColor.classic : ThemeColor.golden;
    await setColorScheme(newColor, null);
  }
}
