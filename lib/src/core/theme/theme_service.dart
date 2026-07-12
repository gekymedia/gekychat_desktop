import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/desktop_typography.dart';
import 'app_theme_mode.dart';

/// Service to manage app theme preferences (palettes aligned with mobile).
class ThemeService {
  static const String _themeKey = 'app_theme_mode_desktop';

  Future<AppThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_themeKey) ?? AppThemeMode.classicLight.key;
    return AppThemeMode.fromKey(key);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.key);
  }

  ThemeData getThemeData(AppThemeMode mode) {
    final primaryColor = Color(mode.primaryColorValue);
    final isDark = mode.isDark;
    final colors = _getThemeColors(mode.themeColor, isDark);

    final textTheme = DesktopTypography.shellTextTheme(isDark);
    final openSansFamily = DesktopTypography.fontFamily;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      fontFamily: openSansFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.appBarBackground,
        foregroundColor: colors.appBarForeground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.openSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: colors.appBarForeground,
        ),
      ),
      scaffoldBackgroundColor: colors.scaffoldBackground,
      cardTheme: CardThemeData(
        color: colors.cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.bottomNavBackground,
        selectedItemColor: primaryColor,
        unselectedItemColor: colors.unselectedIcon,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputBackground,
        hintStyle: GoogleFonts.openSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colors.unselectedIcon,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      dividerColor: colors.divider,
      iconTheme: IconThemeData(color: colors.icon),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  _ThemeColors _getThemeColors(ThemeColor themeColor, bool isDark) {
    switch (themeColor) {
      case ThemeColor.classic:
        return _ThemeColors(
          scaffoldBackground: isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
          appBarBackground: isDark ? const Color(0xFF202C33) : Colors.white,
          appBarForeground: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF008069),
          cardBackground: isDark ? const Color(0xFF202C33) : Colors.white,
          bottomNavBackground: isDark ? const Color(0xFF202C33) : Colors.white,
          inputBackground: isDark ? const Color(0xFF3B4A54) : const Color(0xFFF0F2F5),
          border: isDark ? const Color(0xFF3B4A54) : const Color(0xFFE5E7EB),
          divider: isDark ? const Color(0xFF3B4A54) : const Color(0xFFE5E7EB),
          icon: isDark ? const Color(0xFF25D366) : const Color(0xFF008069),
          unselectedIcon: isDark ? Colors.white54 : Colors.black54,
        );
      case ThemeColor.golden:
        return _ThemeColors(
          scaffoldBackground: isDark ? const Color(0xFF0A0805) : const Color(0xFFFFFBF5),
          appBarBackground: isDark ? const Color(0xFF1A1410) : const Color(0xFFFFD700),
          appBarForeground: isDark ? const Color(0xFFFFD700) : const Color(0xFF654321),
          cardBackground: isDark ? const Color(0xFF1F1A15) : const Color(0xFFFFF8DC),
          bottomNavBackground: isDark ? const Color(0xFF1A1410) : const Color(0xFFFFF8DC),
          inputBackground: isDark ? const Color(0xFF2A231A) : const Color(0xFFFFFAF0),
          border: isDark ? const Color(0xFF3D3428) : const Color(0xFFE6D8B5),
          divider: isDark ? const Color(0xFF3D3428) : const Color(0xFFE6D8B5),
          icon: isDark ? const Color(0xFFFFD700) : const Color(0xFFB8860B),
          unselectedIcon: isDark ? const Color(0xFFFFB700) : const Color(0xFF997000),
        );
      case ThemeColor.telegram:
        return _ThemeColors(
          scaffoldBackground: isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5),
          appBarBackground: isDark ? const Color(0xFF1C2E3E) : const Color(0xFF3390EC),
          appBarForeground: Colors.white,
          cardBackground: isDark ? const Color(0xFF212A34) : Colors.white,
          bottomNavBackground: isDark ? const Color(0xFF17212B) : Colors.white,
          inputBackground: isDark ? const Color(0xFF2C3E50) : const Color(0xFFE8EDEF),
          border: isDark ? const Color(0xFF3A4A5C) : const Color(0xFFD1D5DB),
          divider: isDark ? const Color(0xFF3A4A5C) : const Color(0xFFE5E7EB),
          icon: isDark ? const Color(0xFF5DADE2) : const Color(0xFF3390EC),
          unselectedIcon: isDark ? Colors.white54 : Colors.black54,
        );
      case ThemeColor.blue:
        return _ThemeColors(
          scaffoldBackground: isDark ? const Color(0xFF0A0E27) : const Color(0xFFE3F2FD),
          appBarBackground: isDark ? const Color(0xFF1565C0) : const Color(0xFF1976D2),
          appBarForeground: Colors.white,
          cardBackground: isDark ? const Color(0xFF1E3A5F) : Colors.white,
          bottomNavBackground: isDark ? const Color(0xFF1565C0) : Colors.white,
          inputBackground: isDark ? const Color(0xFF2C3E4F) : const Color(0xFFBBDEFB),
          border: isDark ? const Color(0xFF3A5A7F) : const Color(0xFF64B5F6),
          divider: isDark ? const Color(0xFF3A5A7F) : const Color(0xFF90CAF9),
          icon: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2),
          unselectedIcon: isDark ? Colors.white54 : Colors.black54,
        );
      case ThemeColor.pink:
        return _ThemeColors(
          scaffoldBackground: isDark ? const Color(0xFF1A0A1A) : const Color(0xFFFFF0F5),
          appBarBackground: isDark ? const Color(0xFFAD1457) : const Color(0xFFF50057),
          appBarForeground: Colors.white,
          cardBackground: isDark ? const Color(0xFF2D1B2D) : Colors.white,
          bottomNavBackground: isDark ? const Color(0xFF2D1B2D) : Colors.white,
          inputBackground: isDark ? const Color(0xFF3D2B3D) : const Color(0xFFFFCCE0),
          border: isDark ? const Color(0xFF5A3E5A) : const Color(0xFFFF80AB),
          divider: isDark ? const Color(0xFF5A3E5A) : const Color(0xFFFF80AB),
          icon: isDark ? const Color(0xFFFF4081) : const Color(0xFFC2185B),
          unselectedIcon: isDark ? const Color(0xFFFF80AB) : Colors.black54,
        );
      case ThemeColor.amoled:
        return const _ThemeColors(
          scaffoldBackground: Colors.black,
          appBarBackground: Colors.black,
          appBarForeground: Colors.white,
          cardBackground: Color(0xFF0F0F0F),
          bottomNavBackground: Colors.black,
          inputBackground: Color(0xFF1A1A1A),
          border: Color(0xFF2A2A2A),
          divider: Color(0xFF2A2A2A),
          icon: Colors.white,
          unselectedIcon: Colors.white38,
        );
      case ThemeColor.ios:
        return _ThemeColors(
          scaffoldBackground: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
          appBarBackground: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          appBarForeground: isDark ? Colors.white : const Color(0xFF007AFF),
          cardBackground: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          bottomNavBackground: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          inputBackground: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
          border: isDark ? const Color(0xFF3C3C3E) : const Color(0xFFC7C7CC),
          divider: isDark ? const Color(0xFF3C3C3E) : const Color(0xFFE5E5EA),
          icon: isDark ? Colors.white : const Color(0xFF007AFF),
          unselectedIcon: isDark ? Colors.white54 : Colors.black54,
        );
    }
  }
}

class _ThemeColors {
  final Color scaffoldBackground;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color cardBackground;
  final Color bottomNavBackground;
  final Color inputBackground;
  final Color border;
  final Color divider;
  final Color icon;
  final Color unselectedIcon;

  const _ThemeColors({
    required this.scaffoldBackground,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.cardBackground,
    required this.bottomNavBackground,
    required this.inputBackground,
    required this.border,
    required this.divider,
    required this.icon,
    required this.unselectedIcon,
  });
}
