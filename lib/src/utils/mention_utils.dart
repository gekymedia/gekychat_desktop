import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Represents a mention in a message
class MentionSpan {
  final int start;
  final int end;
  final String username;
  final int userId;
  final String? displayName;

  MentionSpan({
    required this.start,
    required this.end,
    required this.username,
    required this.userId,
    this.displayName,
  });

  factory MentionSpan.fromJson(Map<String, dynamic> json) {
    return MentionSpan(
      start: json['position_start'] ?? 0,
      end: json['position_end'] ?? 0,
      username: json['mentioned_user']?['username'] ?? '',
      userId: json['mentioned_user']?['id'] ?? 0,
      displayName: json['mentioned_user']?['name'],
    );
  }

  String get text => '@$username';
}

/// Utility class for parsing and rendering mentions in messages
class MentionUtils {
  /// Parse mentions from API response
  static List<MentionSpan> parseMentions(List<dynamic>? mentionsJson) {
    if (mentionsJson == null || mentionsJson.isEmpty) return [];
    
    return mentionsJson
        .map((json) => MentionSpan.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Parse @username patterns from text for input autocomplete
  static List<String> extractMentionPatterns(String text) {
    final regex = RegExp(r'@(\w{1,30})');
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(1)!).toList();
  }

  /// Get the current mention being typed (for autocomplete)
  /// Returns null if not typing a mention
  static String? getCurrentMention(String text, int cursorPosition) {
    if (cursorPosition <= 0 || cursorPosition > text.length) return null;
    
    // Find the last @ before cursor
    int atIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        atIndex = i;
        break;
      }
      // Stop if we hit a space or newline
      if (text[i] == ' ' || text[i] == '\n') {
        break;
      }
    }
    
    if (atIndex == -1) return null;
    
    // Check if there's a space or newline right before the @
    // (or if it's at the start)
    if (atIndex > 0 && text[atIndex - 1] != ' ' && text[atIndex - 1] != '\n') {
      return null;
    }
    
    // Extract the partial username
    final partial = text.substring(atIndex + 1, cursorPosition);
    
    // Validate it's a valid username pattern (alphanumeric + underscore)
    if (!RegExp(r'^\w*$').hasMatch(partial)) return null;
    
    return partial;
  }

  /// Insert a mention into text at cursor position
  static String insertMention({
    required String text,
    required int cursorPosition,
    required String username,
  }) {
    // Find the @ position
    int atIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        atIndex = i;
        break;
      }
      if (text[i] == ' ' || text[i] == '\n') {
        break;
      }
    }
    
    if (atIndex == -1) {
      // Just append the mention
      return text + ' @$username ';
    }
    
    // Replace from @ to cursor with the full mention
    final before = text.substring(0, atIndex);
    final after = text.substring(cursorPosition);
    return '$before@$username $after';
  }

  /// Build a rich text widget with clickable mentions
  static Widget buildMentionText({
    required String text,
    required List<MentionSpan> mentions,
    required TextStyle style,
    TextStyle? mentionStyle,
    required Function(int userId, String username) onMentionTap,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    if (mentions.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Sort mentions by position
    final sortedMentions = List<MentionSpan>.from(mentions)
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final mention in sortedMentions) {
      // Add text before mention
      if (mention.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, mention.start),
          style: style,
        ));
      }

      // Add mention span
      if (mention.end <= text.length) {
        spans.add(TextSpan(
          text: text.substring(mention.start, mention.end),
          style: mentionStyle ??
              style.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onMentionTap(mention.userId, mention.username),
        ));
        currentIndex = mention.end;
      }
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  /// Highlight mentions in a TextField (for input preview)
  static TextSpan buildInputTextSpan({
    required String text,
    required TextStyle style,
    TextStyle? mentionStyle,
  }) {
    final regex = RegExp(r'@(\w{1,30})');
    final matches = regex.allMatches(text);
    
    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      // Add text before mention
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: style,
        ));
      }

      // Add highlighted mention
      spans.add(TextSpan(
        text: match.group(0)!,
        style: mentionStyle ??
            style.copyWith(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
      ));
      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: style,
      ));
    }

    return TextSpan(children: spans);
  }

  /// Count mentions in text
  static int countMentions(String text) {
    return RegExp(r'@(\w{1,30})').allMatches(text).length;
  }

  /// Validate username format
  static bool isValidUsername(String username) {
    return RegExp(r'^\w{3,30}$').hasMatch(username);
  }
}
