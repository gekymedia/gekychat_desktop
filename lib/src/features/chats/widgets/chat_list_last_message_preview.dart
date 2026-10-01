import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/desktop_typography.dart';

/// WhatsApp/Telegram-style chat list subtitle: tick(s) + media icon before text.
class ChatListLastMessagePreview extends StatelessWidget {
  const ChatListLastMessagePreview({
    super.key,
    required this.text,
    required this.isDark,
    required this.hasUnread,
    required this.fromMe,
    this.outgoingStatus,
  });

  final String text;
  final bool isDark;
  final bool hasUnread;
  final bool fromMe;
  final String? outgoingStatus;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DesktopTypography.listSubtitle(
      isDark: isDark,
      hasUnread: hasUnread,
    );

    final media = _mediaMeta(text);
    final displayText = media?.label ?? text;

    final showTicks = fromMe &&
        outgoingStatus != null &&
        outgoingStatus!.isNotEmpty;

    final secondary = isDark
        ? AppTheme.textSecondaryDark
        : const Color(0xFF707579);

    final children = <Widget>[];

    if (showTicks) {
      final read = outgoingStatus == 'read';
      final tickColor = read ? AppTheme.primaryGreen : secondary;
      final IconData icon;
      switch (outgoingStatus) {
        case 'sending':
        case 'queued':
          icon = Icons.schedule;
          break;
        case 'failed':
          icon = Icons.error_outline;
          break;
        case 'sent':
          icon = Icons.check;
          break;
        default:
          icon = Icons.done_all;
          break;
      }
      final color = outgoingStatus == 'failed' ? Colors.redAccent : tickColor;
      children.add(Icon(icon, size: 13, color: color));
      children.add(const SizedBox(width: 3));
    }

    if (media != null) {
      children.add(
        Icon(
          media.icon,
          size: 14,
          color: hasUnread
              ? (isDark ? Colors.white70 : const Color(0xFF54656F))
              : secondary,
        ),
      );
      children.add(const SizedBox(width: 3));
    }

    final textWidget = Text(
      displayText,
      style: baseStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
    );

    if (children.isEmpty) {
      // Fill width so AnimatedSwitcher/Stack centering cannot mid-align short text.
      return SizedBox(
        width: double.infinity,
        child: textWidget,
      );
    }

    return Row(
      children: [
        ...children,
        Expanded(child: textWidget),
      ],
    );
  }

  /// Detect inbox media prefixes (📷 Photo, 🎬 Video, …) and map to icons.
  static ({IconData icon, String label})? _mediaMeta(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;

    // Strip common emoji prefixes used by sidebar_inbox_bump / API previews.
    final patterns = <(RegExp, IconData)>[
      (RegExp(r'^📷\s*(.+)$'), Icons.photo_camera_outlined),
      (RegExp(r'^🎬\s*(.+)$'), Icons.videocam_outlined),
      (RegExp(r'^🎤\s*(.+)$'), Icons.mic_none_outlined),
      (RegExp(r'^🎧\s*(.+)$'), Icons.headphones_outlined),
      (RegExp(r'^📎\s*(.+)$'), Icons.attach_file),
      (RegExp(r'^📄\s*(.+)$'), Icons.insert_drive_file_outlined),
      (RegExp(r'^📍\s*(.+)$'), Icons.location_on_outlined),
      (RegExp(r'^👤\s*(.+)$'), Icons.person_outline),
      (RegExp(r'^📊\s*(.+)$'), Icons.poll_outlined),
      (RegExp(r'^📇\s*(.+)$'), Icons.contact_page_outlined),
      (RegExp(r'^🎵\s*(.+)$'), Icons.audiotrack),
    ];

    for (final (re, icon) in patterns) {
      final m = re.firstMatch(t);
      if (m != null) {
        final label = (m.group(1) ?? '').trim();
        if (label.isEmpty) continue;
        return (icon: icon, label: label);
      }
    }

    // Plain English fallbacks without emoji.
    final lower = t.toLowerCase();
    if (lower == 'photo' || lower == 'image') {
      return (icon: Icons.photo_camera_outlined, label: 'Photo');
    }
    if (lower == 'video') {
      return (icon: Icons.videocam_outlined, label: 'Video');
    }
    if (lower == 'voice message' || lower == 'audio') {
      return (icon: Icons.mic_none_outlined, label: t);
    }
    if (lower == 'document' || lower == 'file') {
      return (icon: Icons.insert_drive_file_outlined, label: 'Document');
    }
    if (lower == 'location') {
      return (icon: Icons.location_on_outlined, label: 'Location');
    }
    if (lower == 'contact') {
      return (icon: Icons.person_outline, label: 'Contact');
    }
    if (lower == 'poll') {
      return (icon: Icons.poll_outlined, label: 'Poll');
    }
    if (lower == 'sticker') {
      return (icon: Icons.sticky_note_2_outlined, label: 'Sticker');
    }
    if (lower == 'gif') {
      return (icon: Icons.gif_box_outlined, label: 'GIF');
    }

    return null;
  }
}
