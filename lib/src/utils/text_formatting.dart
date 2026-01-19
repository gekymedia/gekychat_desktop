import 'package:flutter/material.dart';

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
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final defaultTextStyle = baseStyle ??
        TextStyle(
          color: defaultColor ?? Colors.black,
          fontSize: 15,
        );

    final segments = _parseText(text);
    final spans = <TextSpan>[];

    for (final segment in segments) {
      TextStyle style = defaultTextStyle;

      // Apply formatting styles
      if (segment['bold'] == true) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      }
      if (segment['italic'] == true) {
        style = style.copyWith(fontStyle: FontStyle.italic);
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
          // Double marker found
          if (formatStack.contains(formatType)) {
            // Closing marker
            segments.add({
              'text': buffer.toString(),
              ...Map.fromEntries(formatStack.map((f) => MapEntry(f, true))),
            });
            buffer.clear();
            formatStack.remove(formatType);
          } else {
            // Opening marker
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

      if (formatType != null && _isValidMarkerPosition(text, i)) {
        // Check if this is a closing or opening marker
        if (formatStack.contains(formatType)) {
          // Closing marker - ensure there's content before it
          if (buffer.isNotEmpty) {
            segments.add({
              'text': buffer.toString(),
              ...Map.fromEntries(formatStack.map((f) => MapEntry(f, true))),
            });
            buffer.clear();
            formatStack.remove(formatType);
          }
        } else {
          // Opening marker - save current buffer first
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

  /// Check if a marker is at a valid position (not part of a word)
  static bool _isValidMarkerPosition(String text, int pos) {
    if (pos == 0 || pos >= text.length - 1) {
      return true;
    }

    final prevChar = text[pos - 1];
    final nextChar = text[pos + 1];

    // Marker is valid if:
    // - Previous char is whitespace/punctuation or start of string
    // - Next char is not the same marker (to avoid matching double markers)
    final isWordBoundary = prevChar == ' ' || 
                          prevChar == '\n' || 
                          prevChar == '\t' ||
                          pos == 0;
    
    final isNotDoubleMarker = nextChar != text[pos];

    return isWordBoundary && isNotDoubleMarker;
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
  static String wrapTextWithFormatting(String text, int start, int end, String formatType) {
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
