import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'display_text.dart';

/// WhatsApp-style text formatting parser
/// Supports:
/// - *bold* or **bold** for bold text
/// - _italic_ or __italic__ for italic text
/// - ~strikethrough~ or ~~strikethrough~~ for strikethrough text
/// - `monospace` or ``monospace`` for monospace/code text
class TextFormatting {
  /// Parse formatted text and return a TextSpan with formatting
  static TextSpan parseFormattedText(
    String text, {
    TextStyle? baseStyle,
    Color? defaultColor,
  }) {
    final safeText = sanitizeDisplayText(text);
    if (safeText.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final defaultTextStyle = baseStyle ??
        TextStyle(
          color: defaultColor ?? Colors.black,
          fontSize: 15,
        );

    final segments = _parseText(safeText);
    final spans = <TextSpan>[];

    for (final segment in segments) {
      TextStyle style = defaultTextStyle;

      // Apply formatting styles. Open Sans on Windows needs an explicit
      // GoogleFonts face for weight/style — copyWith(fontWeight) alone often
      // stays on the regular face and bold looks invisible.
      if (segment['bold'] == true) {
        style = _openSansFace(
          style,
          fontWeight: FontWeight.w700,
        );
      }
      if (segment['italic'] == true) {
        style = _openSansFace(
          style,
          fontWeight: style.fontWeight ?? FontWeight.w400,
          fontStyle: FontStyle.italic,
        );
      }
      if (segment['strikethrough'] == true) {
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      }
      if (segment['monospace'] == true) {
        style = style.copyWith(fontFamily: 'monospace', fontFeatures: []);
      }

      spans.add(TextSpan(
        text: segment['text'] as String,
        style: style,
      ));
    }

    return TextSpan(children: spans);
  }

  /// Resolve an Open Sans face that actually carries [fontWeight]/[fontStyle].
  static TextStyle _openSansFace(
    TextStyle base, {
    required FontWeight fontWeight,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return GoogleFonts.openSans(
      textStyle: base,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
    );
  }

  /// Parse text into segments with formatting information
  static List<Map<String, dynamic>> _parseText(String text) {
    final segments = <Map<String, dynamic>>[];
    final formatStack = <String>[]; // Track nested formatting
    final buffer = StringBuffer();
    int i = 0;

    while (i < text.length) {
      // Check for double markers first (e.g., **bold**)
      if (i + 1 < text.length) {
        final twoChars = text.substring(i, i + 2);
        final formatType = _getDoubleMarkerFormat(twoChars);

        if (formatType != null) {
          final isClosing = formatStack.contains(formatType);
          // Treat marker as formatting only when there is a matching pair.
          // This avoids leaking style to the rest of the message.
          if (!isClosing) {
            final hasMatchingClose = text.indexOf(twoChars, i + 2) != -1;
            if (!hasMatchingClose) {
              buffer.write(twoChars);
              i += 2;
              continue;
            }
          }
          if (isClosing) {
            segments.add({
              'text': buffer.toString(),
              ...Map.fromEntries(formatStack.map((f) => MapEntry(f, true))),
            });
            buffer.clear();
            formatStack.remove(formatType);
          } else {
            if (buffer.isNotEmpty) {
              segments.add({
                'text': buffer.toString(),
                ...Map.fromEntries(formatStack.map((f) => MapEntry(f, true))),
              });
              buffer.clear();
            }
            formatStack.add(formatType);
          }
          i += 2;
          continue;
        }
      }

      // Check for single markers (e.g., *bold*)
      final char = text[i];
      final formatType = _getSingleMarkerFormat(char);

      final isClosing = formatType != null && formatStack.contains(formatType);
      if (formatType != null &&
          _isValidMarkerPosition(text, i, marker: char, isClosing: isClosing)) {
        if (isClosing) {
          if (buffer.isNotEmpty) {
            segments.add({
              'text': buffer.toString(),
              ...Map.fromEntries(formatStack.map((f) => MapEntry(f, true))),
            });
          }
          buffer.clear();
          formatStack.remove(formatType);
        } else {
          final hasMatchingClose = text.indexOf(char, i + 1) != -1;
          if (!hasMatchingClose) {
            buffer.write(char);
            i++;
            continue;
          }
          if (buffer.isNotEmpty) {
            segments.add({
              'text': buffer.toString(),
              ...Map.fromEntries(formatStack.map((f) => MapEntry(f, true))),
            });
            buffer.clear();
          }
          formatStack.add(formatType);
        }
        i++;
        continue;
      }

      // Regular character
      buffer.write(char);
      i++;
    }

    // Add remaining buffer
    if (buffer.isNotEmpty) {
      segments.add({
        'text': buffer.toString(),
        ...Map.fromEntries(formatStack.map((f) => MapEntry(f, true))),
      });
    }

    return segments;
  }

  /// Check if a marker is at a valid position (WhatsApp-like open/close rules).
  static bool _isValidMarkerPosition(
    String text,
    int pos, {
    required String marker,
    required bool isClosing,
  }) {
    final prevChar = pos > 0 ? text[pos - 1] : null;
    final nextChar = pos + 1 < text.length ? text[pos + 1] : null;
    final isDoubleMarker = nextChar == marker;
    if (isDoubleMarker) return false;

    if (!isClosing) {
      // Opening marker: start-of-text or boundary before, and content after.
      final leftBoundary = prevChar == null || _isWhitespace(prevChar);
      final hasContentAfter = nextChar != null && !_isWhitespace(nextChar);
      return leftBoundary && hasContentAfter;
    }

    // Closing marker: content before, and boundary/end after.
    final hasContentBefore = prevChar != null && !_isWhitespace(prevChar);
    final rightBoundary = nextChar == null || _isWhitespace(nextChar);
    return hasContentBefore && rightBoundary;
  }

  static bool _isWhitespace(String ch) {
    return ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r';
  }

  /// Get format type from double marker (e.g., **, __, ~~, ``)
  static String? _getDoubleMarkerFormat(String marker) {
    switch (marker) {
      case '**':
        return 'bold';
      case '__':
        return 'italic';
      case '~~':
        return 'strikethrough';
      case '``':
        return 'monospace';
      default:
        return null;
    }
  }

  /// Get format type from single marker (e.g., *, _, ~, `)
  static String? _getSingleMarkerFormat(String marker) {
    switch (marker) {
      case '*':
        return 'bold';
      case '_':
        return 'italic';
      case '~':
        return 'strikethrough';
      case '`':
        return 'monospace';
      default:
        return null;
    }
  }

  /// Wrap selected text with formatting markers
  static String wrapTextWithFormatting(
    String text,
    int start,
    int end,
    String formatType,
  ) {
    if (start < 0 || end > text.length || start >= end) {
      return text;
    }

    final marker = _getMarkerForFormat(formatType);
    final selectedText = text.substring(start, end);
    final before = text.substring(0, start);
    final after = text.substring(end);

    return '$before$marker$selectedText$marker$after';
  }

  /// Get marker string for format type
  static String _getMarkerForFormat(String formatType) {
    switch (formatType) {
      case 'bold':
        return '*';
      case 'italic':
        return '_';
      case 'strikethrough':
        return '~';
      case 'monospace':
        return '`';
      default:
        return '';
    }
  }
}
