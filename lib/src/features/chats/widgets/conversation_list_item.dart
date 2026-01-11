import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/avatar_utils.dart';

class ConversationListItem extends StatelessWidget {
  final ConversationSummary conversation;
  final bool isSelected;
  final VoidCallback onTap;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = conversation.unreadCount > 0;

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
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: conversation.otherUser.avatarUrl == null
                      ? AvatarUtils.getGradientForName(conversation.otherUser.name)
                      : null,
                  color: conversation.otherUser.avatarUrl != null
                      ? (isDark ? AppTheme.darkSurface : AppTheme.lightBorder)
                      : null,
                ),
                child: conversation.otherUser.avatarUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: conversation.otherUser.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AvatarUtils.getGradientForName(conversation.otherUser.name),
                            ),
                            child: Center(
                            child: Text(
                                AvatarUtils.getInitials(conversation.otherUser.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AvatarUtils.getGradientForName(conversation.otherUser.name),
                            ),
                            child: Center(
                            child: Text(
                                AvatarUtils.getInitials(conversation.otherUser.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          AvatarUtils.getInitials(conversation.otherUser.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (conversation.isPinned)
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: AppTheme.primaryGreen,
                          ),
                        if (conversation.isPinned) const SizedBox(width: 4),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  conversation.otherUser.name,
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
                              if (conversation.otherUser.isOnline == true) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(conversation.updatedAt ?? DateTime.now()),
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
                          child: Text(
                            conversation.lastMessage ?? 'No messages yet',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                              fontSize: 14,
                              fontWeight:
                                  hasUnread ? FontWeight.w500 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                conversation.unreadCount > 999
                                    ? '999+'
                                    : conversation.unreadCount.toString(),
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


