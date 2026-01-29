import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../utils/mention_utils.dart';

/// Widget that displays text with clickable @mentions
class MentionText extends StatelessWidget {
  final String text;
  final List<dynamic>? mentions;
  final TextStyle style;
  final TextStyle? mentionStyle;
  final Function(int userId, String username)? onMentionTap;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const MentionText({
    super.key,
    required this.text,
    this.mentions,
    required this.style,
    this.mentionStyle,
    this.onMentionTap,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    // If no mentions, just show plain text
    if (mentions == null || mentions!.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    // Parse mentions
    final mentionSpans = MentionUtils.parseMentions(mentions);

    // Build rich text with clickable mentions
    return RichText(
      text: _buildTextSpan(context, mentionSpans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      textAlign: textAlign ?? TextAlign.start,
    );
  }

  TextSpan _buildTextSpan(BuildContext context, List<MentionSpan> mentionSpans) {
    if (mentionSpans.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    // Sort mentions by position
    final sortedMentions = List<MentionSpan>.from(mentionSpans)
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final mention in sortedMentions) {
      // Add text before mention
      if (mention.start > currentIndex && mention.start <= text.length) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, mention.start),
          style: style,
        ));
      }

      // Add mention span
      if (mention.end <= text.length && mention.start < mention.end) {
        final mentionText = text.substring(mention.start, mention.end);
        spans.add(TextSpan(
          text: mentionText,
          style: mentionStyle ??
              style.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
          recognizer: onMentionTap != null
              ? (TapGestureRecognizer()
                ..onTap = () => onMentionTap!(mention.userId, mention.username))
              : null,
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

    return TextSpan(children: spans);
  }
}

/// Selectable version of MentionText (for long-press to copy)
class SelectableMentionText extends StatelessWidget {
  final String text;
  final List<dynamic>? mentions;
  final TextStyle style;
  final TextStyle? mentionStyle;
  final Function(int userId, String username)? onMentionTap;
  final int? maxLines;

  const SelectableMentionText({
    super.key,
    required this.text,
    this.mentions,
    required this.style,
    this.mentionStyle,
    this.onMentionTap,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    // If no mentions, just show plain selectable text
    if (mentions == null || mentions!.isEmpty) {
      return SelectableText(
        text,
        style: style,
        maxLines: maxLines,
      );
    }

    // Parse mentions
    final mentionSpans = MentionUtils.parseMentions(mentions);

    // Build rich text with clickable mentions
    return SelectableText.rich(
      _buildTextSpan(context, mentionSpans),
      maxLines: maxLines,
    );
  }

  TextSpan _buildTextSpan(BuildContext context, List<MentionSpan> mentionSpans) {
    if (mentionSpans.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    // Sort mentions by position
    final sortedMentions = List<MentionSpan>.from(mentionSpans)
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final mention in sortedMentions) {
      // Add text before mention
      if (mention.start > currentIndex && mention.start <= text.length) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, mention.start),
          style: style,
        ));
      }

      // Add mention span
      if (mention.end <= text.length && mention.start < mention.end) {
        final mentionText = text.substring(mention.start, mention.end);
        spans.add(TextSpan(
          text: mentionText,
          style: mentionStyle ??
              style.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
          recognizer: onMentionTap != null
              ? (TapGestureRecognizer()
                ..onTap = () => onMentionTap!(mention.userId, mention.username))
              : null,
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

    return TextSpan(children: spans);
  }
}
