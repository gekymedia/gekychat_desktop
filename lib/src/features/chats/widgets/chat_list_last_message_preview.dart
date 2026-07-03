import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// WhatsApp-style chat list subtitle: tick(s) before text when the preview is your message.
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
    final secondary = isDark
        ? AppTheme.textSecondaryDark
        : AppTheme.textSecondaryLight;
    final baseStyle = TextStyle(
      color: secondary,
      fontSize: 14,
      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
    );

    final showTicks = fromMe &&
        outgoingStatus != null &&
        outgoingStatus!.isNotEmpty;
    if (!showTicks) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final read = outgoingStatus == 'read';
    final tickColor = read ? AppTheme.primaryGreen : secondary;
    final icon = outgoingStatus == 'sent' ? Icons.check : Icons.done_all;

    return Row(
      children: [
        Icon(icon, size: 14, color: tickColor),
        const SizedBox(width: 4),
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
