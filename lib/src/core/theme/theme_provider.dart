import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme_mode.dart';
import 'theme_service.dart';

/// Provider for theme service
final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

/// Provider for current theme mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier(ref.read(themeServiceProvider));
});

/// Notifier to manage theme mode state
class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier(this._themeService) : super(AppThemeMode.whiteLight) {
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

  /// Toggle between light and dark for current color scheme
  Future<void> toggleBrightness() async {
    final newMode = switch (state) {
      AppThemeMode.goldenLight => AppThemeMode.goldenDark,
      AppThemeMode.goldenDark => AppThemeMode.goldenLight,
      AppThemeMode.whiteLight => AppThemeMode.whiteDark,
      AppThemeMode.whiteDark => AppThemeMode.whiteLight,
    };
    await setThemeMode(newMode);
  }

  /// Switch between golden and white for current brightness
  Future<void> toggleColorScheme() async {
    final newMode = switch (state) {
      AppThemeMode.goldenLight => AppThemeMode.whiteLight,
      AppThemeMode.goldenDark => AppThemeMode.whiteDark,
      AppThemeMode.whiteLight => AppThemeMode.goldenLight,
      AppThemeMode.whiteDark => AppThemeMode.goldenDark,
    };
    await setThemeMode(newMode);
  }
}
