import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/text_sanitize.dart';
import '../models.dart';
import '../providers/group_typing_status_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/desktop_typography.dart';
import '../../../widgets/desktop_chat_list_item_shell.dart';
import '../../../widgets/desktop_whatsapp_hover_chevron.dart';
import 'chat_list_last_message_preview.dart';

class GroupListItem extends ConsumerWidget {
  final GroupSummary group;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails details)? onSecondaryTapDown;
  final void Function(Offset globalPosition)? onMenuTap;
  final bool forceUnreadBadge;

  const GroupListItem({
    super.key,
    required this.group,
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
    final hasUnread = group.unreadCount > 0 || forceUnreadBadge;
    final displayName = sanitizeDisplayText(group.name, fallback: 'Group');

    final groupTypingStatus = ref.watch(groupTypingStatusProvider);
    final groupRecordingStatus = ref.watch(groupRecordingStatusProvider);
    final groupTypingNotifier = ref.read(groupTypingStatusProvider.notifier);
    final groupRecordingNotifier =
        ref.read(groupRecordingStatusProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      groupTypingNotifier.subscribeToGroup(group.id);
      groupRecordingNotifier.subscribeToGroup(group.id);
    });

    final isTyping = groupTypingStatus[group.id] ?? false;
    final isRecording = groupRecordingStatus[group.id] ?? false;

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
                color: isDark ? AppTheme.darkSurface : AppTheme.lightBorder,
              ),
              child: group.avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: group.avatarUrl!,
                      fit: BoxFit.cover,
                      width: _avatarSize,
                      height: _avatarSize,
                      placeholder: (context, url) =>
                          const Icon(Icons.group, size: 24),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.group, size: 24),
                    )
                  : const Icon(Icons.group, size: 24),
            ),
          ),
          const SizedBox(width: DesktopTypography.listAvatarGap + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (group.isPinned) ...[
                      const Icon(
                        Icons.push_pin,
                        size: 12,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
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
                    const SizedBox(width: 6),
                    if (group.updatedAt != null)
                      DesktopChatListTimeMenuColumn(
                        time: _formatTime(group.updatedAt!),
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
                          ? SizedBox(
                              width: double.infinity,
                              child: Text(
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
                                textAlign: TextAlign.start,
                              ),
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
                                      '${group.lastMessage}_'
                                      '${group.lastMessageOutgoingStatus}',
                                    ),
                                    text: group.lastMessage ?? 'No messages yet',
                                    isDark: isDark,
                                    hasUnread: hasUnread,
                                    fromMe: group.lastMessageFromMe,
                                    outgoingStatus:
                                        group.lastMessageOutgoingStatus,
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
                            group.unreadCount > 999
                                ? '999+'
                                : group.unreadCount.toString(),
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
