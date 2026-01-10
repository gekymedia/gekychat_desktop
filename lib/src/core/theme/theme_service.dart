import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_mode.dart';

/// Service to manage app theme preferences
class ThemeService {
  static const String _themeKey = 'app_theme_mode';
  
  /// Get saved theme mode
  Future<AppThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_themeKey) ?? AppThemeMode.whiteLight.key;
    return AppThemeMode.fromKey(key);
  }

  /// Save theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.key);
  }

  /// Get theme data for a specific mode
  ThemeData getThemeData(AppThemeMode mode) {
    final primaryColor = Color(mode.primaryColorValue);
    final isDark = mode.isDark;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? (mode.isGolden ? const Color(0xFF1A1410) : const Color(0xFF202C33))
            : (mode.isGolden ? const Color(0xFFFFF8DC) : Colors.white),
        foregroundColor: isDark
            ? (mode.isGolden ? const Color(0xFFD4AF37) : Colors.white)
            : (mode.isGolden ? const Color(0xFF8B7500) : const Color(0xFF008069)),
        elevation: 1,
      ),

      // Scaffold background
      scaffoldBackgroundColor: isDark
          ? (mode.isGolden ? const Color(0xFF0F0D0A) : const Color(0xFF111B21))
          : (mode.isGolden ? const Color(0xFFFFFAF0) : const Color(0xFFF0F2F5)),

      // Card theme
      cardTheme: CardThemeData(
        color: isDark
            ? (mode.isGolden ? const Color(0xFF1A1410) : const Color(0xFF202C33))
            : (mode.isGolden ? const Color(0xFFFFF8DC) : Colors.white),
        elevation: 2,
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark
            ? (mode.isGolden ? const Color(0xFF1A1410) : const Color(0xFF202C33))
            : (mode.isGolden ? const Color(0xFFFFF8DC) : Colors.white),
        selectedItemColor: primaryColor,
        unselectedItemColor: isDark
            ? Colors.white54
            : Colors.black54,
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? (mode.isGolden ? const Color(0xFF2A2410) : const Color(0xFF3B4A54))
            : (mode.isGolden ? const Color(0xFFFFFAF0) : const Color(0xFFF0F2F5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),

      // Divider
      dividerColor: isDark
          ? (mode.isGolden ? const Color(0xFF3A3410) : const Color(0xFF3B4A54))
          : (mode.isGolden ? const Color(0xFFE6D8B5) : const Color(0xFFE5E7EB)),

      // Icon theme
      iconTheme: IconThemeData(
        color: isDark
            ? (mode.isGolden ? const Color(0xFFD4AF37) : Colors.white)
            : (mode.isGolden ? const Color(0xFF8B7500) : const Color(0xFF008069)),
      ),
    );
  }
}
