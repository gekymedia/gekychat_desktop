import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const primaryGreen = Color(0xFF00A884);
  static const secondaryGreen = Color(0xFF25D366);
  static const tealDark = Color(0xFF005C4B);
  
  static const darkBackground = Color(0xFF0B141A);
  static const darkSurface = Color(0xFF202C33);
  static const darkCard = Color(0xFF111B21);
  static const darkBorder = Color(0xFF2A3942);
  
  static const lightBackground = Color(0xFFE9EDEF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFD1D7DB);
  
  static const outgoingBubbleDark = Color(0xFF005C4B);
  static const outgoingBubbleLight = Color(0xFFD9FDD3);
  static const incomingBubbleDark = Color(0xFF202C33);
  static const incomingBubbleLight = Color(0xFFFFFFFF);
  
  static const onlineGreen = Color(0xFF25D366);
  static const typingOrange = Color(0xFFFF9800);
  static const errorRed = Color(0xFFEF5350);
  
  static const textPrimaryDark = Color(0xFFE9EDEF);
  static const textSecondaryDark = Color(0xFF8696A0);
  static const textPrimaryLight = Color(0xFF111B21);
  static const textSecondaryLight = Color(0xFF667781);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: lightBackground,
      
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: secondaryGreen,
        surface: lightSurface,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: textPrimaryLight,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: textSecondaryLight,
          size: 24,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.zero,
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: CircleBorder(),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(
          color: textSecondaryLight,
          fontSize: 16,
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 0.5,
        space: 0,
      ),
      
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: lightSurface,
        textColor: textPrimaryLight,
        iconColor: textSecondaryLight,
      ),
      
      iconTheme: const IconThemeData(
        color: textSecondaryLight,
        size: 24,
      ),
      
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimaryLight,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimaryLight,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimaryLight,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondaryLight,
          letterSpacing: 0,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryLight,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: darkBackground,
      
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: secondaryGreen,
        surface: darkSurface,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryDark,
        onError: Colors.white,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: textSecondaryDark,
          size: 24,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.zero,
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: CircleBorder(),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(
          color: textSecondaryDark,
          fontSize: 16,
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 0.5,
        space: 0,
      ),
      
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: darkCard,
        textColor: textPrimaryDark,
        iconColor: textSecondaryDark,
      ),
      
      iconTheme: const IconThemeData(
        color: textSecondaryDark,
        size: 24,
      ),
      
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimaryDark,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimaryDark,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimaryDark,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondaryDark,
          letterSpacing: 0,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryDark,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

