import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/text_sanitize.dart';
import '../models.dart';
import '../providers/group_typing_status_provider.dart';
import '../../../theme/app_theme.dart';
import 'chat_list_last_message_preview.dart';

class GroupListItem extends ConsumerWidget {
  final GroupSummary group;
  final bool isSelected;
  final VoidCallback onTap;
  final bool forceUnreadBadge;

  const GroupListItem({
    super.key,
    required this.group,
    required this.isSelected,
    required this.onTap,
    this.forceUnreadBadge = false,
  });

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

    return Material(
      color: isSelected
          ? (isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF))
          : (isDark ? const Color(0xFF111B21) : Colors.white),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightBorder,
                ),
                child: group.avatarUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: group.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Icon(Icons.group, size: 28),
                          errorWidget: (context, url, error) => const Icon(Icons.group, size: 28),
                        ),
                      )
                    : const Icon(Icons.group, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (group.isPinned)
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: AppTheme.primaryGreen,
                          ),
                        if (group.isPinned) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textPrimaryDark
                                  : AppTheme.textPrimaryLight,
                              fontSize: 16,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (group.updatedAt != null)
                          Text(
                            _formatTime(group.updatedAt!),
                            style: TextStyle(
                              color: hasUnread
                                  ? AppTheme.primaryGreen
                                  : (isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight),
                              fontSize: 12,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: isRecording
                              ? Text(
                                  'recording audio...',
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : isTyping
                                  ? Text(
                                      'typing...',
                                      style: TextStyle(
                                        color: AppTheme.primaryGreen,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : ChatListLastMessagePreview(
                                      text: group.lastMessage ?? 'No messages yet',
                                      isDark: isDark,
                                      hasUnread: hasUnread,
                                      fromMe: group.lastMessageFromMe,
                                      outgoingStatus: group.lastMessageOutgoingStatus,
                                    ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: const BoxDecoration(
                              color: AppTheme.secondaryGreen,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            child: Center(
                              child: Text(
                                group.unreadCount > 999
                                    ? '999+'
                                    : group.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
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
        ),
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
