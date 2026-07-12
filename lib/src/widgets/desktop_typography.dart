import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Telegram Desktop–aligned typography using bundled [Open Sans] via Google Fonts.
///
/// Open Sans is Telegram's official UI typeface (same family across Windows,
/// macOS, and Linux). We preload common weights at startup so every
/// `fontFamily: DesktopTypography.fontFamily` reference resolves correctly.
abstract final class DesktopTypography {
  static const String _familyName = 'Open Sans';

  /// Registered Open Sans family name (after [preload] in main).
  static String get fontFamily =>
      GoogleFonts.openSans().fontFamily ?? _familyName;

  /// Preload UI weights so text renders with Open Sans on first frame.
  static Future<void> preload() => GoogleFonts.pendingFonts([
        GoogleFonts.openSans(fontWeight: FontWeight.w400),
        GoogleFonts.openSans(fontWeight: FontWeight.w500),
        GoogleFonts.openSans(fontWeight: FontWeight.w600),
        GoogleFonts.openSans(fontWeight: FontWeight.w700),
      ]);

  static TextStyle _sans({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double letterSpacing = 0,
    double? height,
  }) =>
      GoogleFonts.openSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );

  static const double sectionTitleSize = 20;
  static const double searchHintSize = 14;
  static const double filterChipSize = 13;
  static const double listTitleSize = 15;
  static const double listSubtitleSize = 13;
  static const double listTimeSize = 11;
  static const double messageBodySize = 14.5;
  static const double listBadgeSize = 11;
  static const double emptyStateSize = 15;
  static const double railLabelSize = 10;

  static const double listAvatarSize = 48;
  static const double listAvatarInitialsSize = 17;
  static const EdgeInsets listRowPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const double listAvatarGap = 12;

  static TextStyle sectionTitle({required bool isDark, Color? color}) =>
      _sans(
        fontSize: sectionTitleSize,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.1,
        color: color ??
            (isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21)),
      );

  static TextStyle listTitle({
    required bool isDark,
    required bool hasUnread,
    Color? color,
  }) =>
      _sans(
        fontSize: listTitleSize,
        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
        height: 1.2,
        color: color ??
            (isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21)),
      );

  static TextStyle listSubtitle({
    required bool isDark,
    bool hasUnread = false,
    Color? color,
  }) =>
      _sans(
        fontSize: listSubtitleSize,
        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
        height: 1.2,
        color: color ??
            (isDark ? const Color(0xFF8696A0) : const Color(0xFF707579)),
      );

  static TextStyle listTime({
    required bool isDark,
    required bool hasUnread,
    Color? accent,
  }) =>
      _sans(
        fontSize: listTimeSize,
        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
        color: hasUnread
            ? (accent ?? const Color(0xFF008069))
            : (isDark ? const Color(0xFF8696A0) : const Color(0xFF707579)),
      );

  static TextTheme shellTextTheme(bool isDark) {
    final primary =
        isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
    final secondary =
        isDark ? const Color(0xFF8696A0) : const Color(0xFF707579);

    final base = TextTheme(
      titleLarge: _sans(
        fontSize: sectionTitleSize,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: _sans(
        fontSize: listTitleSize,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyMedium: _sans(
        fontSize: listSubtitleSize,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: _sans(
        fontSize: listTimeSize,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelMedium: _sans(
        fontSize: filterChipSize,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );

    return GoogleFonts.openSansTextTheme(base);
  }
}
