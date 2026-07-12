import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/text_sanitize.dart';
import '../models.dart';
import '../providers/typing_status_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/desktop_typography.dart';
import '../../../widgets/desktop_chat_list_item_shell.dart';
import '../../../widgets/desktop_whatsapp_hover_chevron.dart';
import 'chat_list_last_message_preview.dart';
import '../../../utils/avatar_utils.dart';

class ConversationListItem extends ConsumerWidget {
  final ConversationSummary conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails details)? onSecondaryTapDown;
  final void Function(Offset globalPosition)? onMenuTap;
  final bool forceUnreadBadge;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.onMenuTap,
    this.forceUnreadBadge = false,
  });

  static const double _avatarSize = DesktopTypography.listAvatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = conversation.unreadCount > 0 || forceUnreadBadge;
    final displayName =
        sanitizeDisplayText(conversation.otherUser.name, fallback: 'Unknown');

    final typingStatus = ref.watch(typingStatusProvider);
    final recordingStatus = ref.watch(recordingStatusProvider);
    final typingNotifier = ref.read(typingStatusProvider.notifier);
    final recordingNotifier = ref.read(recordingStatusProvider.notifier);

    // Idempotent subscribe only — do not resubscribe every rebuild (leaks listeners).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      typingNotifier.subscribeToConversation(conversation.id);
      recordingNotifier.subscribeToConversation(conversation.id);
    });

    final isTyping = typingStatus[conversation.id] ?? false;
    final isRecording = recordingStatus[conversation.id] ?? false;

    return DesktopChatListItemShell(
      isSelected: isSelected,
      hasUnread: hasUnread,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTapDown,
      builder: (isHovered) => Row(
        children: [
          DesktopListAvatar(
            isSelected: isSelected,
            size: _avatarSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: conversation.otherUser.avatarUrl == null
                    ? AvatarUtils.getGradientForName(displayName)
                    : null,
                color: conversation.otherUser.avatarUrl != null
                    ? (isDark ? AppTheme.darkSurface : AppTheme.lightBorder)
                    : null,
              ),
              child: conversation.otherUser.avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: conversation.otherUser.avatarUrl!,
                      fit: BoxFit.cover,
                      width: _avatarSize,
                      height: _avatarSize,
                      placeholder: (context, url) => Center(
                        child: Text(
                          AvatarUtils.getInitials(displayName),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: DesktopTypography.listAvatarInitialsSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Text(
                          AvatarUtils.getInitials(displayName),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: DesktopTypography.listAvatarInitialsSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        AvatarUtils.getInitials(displayName),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: DesktopTypography.listAvatarInitialsSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: DesktopTypography.listAvatarGap + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (conversation.isPinned) ...[
                      const Icon(
                        Icons.push_pin,
                        size: 12,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: DesktopTypography.listTitle(
                                isDark: isDark,
                                hasUnread: hasUnread,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.otherUser.isOnline == true) ...[
                            const SizedBox(width: 5),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    DesktopChatListTimeMenuColumn(
                      time: _formatTime(
                        conversation.updatedAt ?? DateTime.now(),
                      ),
                      timeStyle: DesktopTypography.listTime(
                        isDark: isDark,
                        hasUnread: hasUnread,
                      ),
                      isHovered: isHovered,
                      isDark: isDark,
                      onMenuTap: onMenuTap,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: isRecording
                          ? Row(
                              children: [
                                const Icon(
                                  Icons.mic,
                                  size: 13,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'recording audio...',
                                  style: DesktopTypography.listSubtitle(
                                    isDark: isDark,
                                    hasUnread: true,
                                  ).copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            )
                          : isTyping
                              ? SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    'typing...',
                                    style: DesktopTypography.listSubtitle(
                                      isDark: isDark,
                                      hasUnread: true,
                                    ).copyWith(
                                      color: AppTheme.primaryGreen,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.start,
                                  ),
                                )
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  switchInCurve: Curves.easeOut,
                                  layoutBuilder: (currentChild, previousChildren) {
                                    return Stack(
                                      alignment: Alignment.centerLeft,
                                      children: <Widget>[
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    );
                                  },
                                  child: ChatListLastMessagePreview(
                                    key: ValueKey(
                                      '${conversation.lastMessage}_'
                                      '${conversation.lastMessageOutgoingStatus}',
                                    ),
                                    text: conversation.lastMessage ??
                                        'No messages yet',
                                    isDark: isDark,
                                    hasUnread: hasUnread,
                                    fromMe: conversation.lastMessageFromMe,
                                    outgoingStatus:
                                        conversation.lastMessageOutgoingStatus,
                                  ),
                                ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: AppTheme.secondaryGreen,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            conversation.unreadCount > 999
                                ? '999+'
                                : conversation.unreadCount.toString(),
                            style: TextStyle(
                              fontFamily: DesktopTypography.fontFamily,
                              color: Colors.white,
                              fontSize: DesktopTypography.listBadgeSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat.jm().format(time);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      return DateFormat.E().format(time);
    } else {
      return DateFormat('M/d/yy').format(time);
    }
  }
}
