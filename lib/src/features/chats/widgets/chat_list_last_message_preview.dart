import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/desktop_typography.dart';

/// WhatsApp/Telegram-style chat list subtitle: tick(s) before text when the preview is your message.
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

    final showTicks = fromMe &&
        outgoingStatus != null &&
        outgoingStatus!.isNotEmpty;
    if (!showTicks) {
      // Fill width so AnimatedSwitcher/Stack centering cannot mid-align short text.
      return SizedBox(
        width: double.infinity,
        child: Text(
          text,
          style: baseStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
        ),
      );
    }

    final secondary = isDark
        ? AppTheme.textSecondaryDark
        : const Color(0xFF707579);
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
        // delivered / read
        icon = Icons.done_all;
        break;
    }
    final color = outgoingStatus == 'failed' ? Colors.redAccent : tickColor;

    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            text,
            style: baseStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
