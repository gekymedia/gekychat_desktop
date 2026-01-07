import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../chats/chat_repo.dart';
import '../chats/models.dart';
import '../chats/widgets/group_chat_view.dart';
import '../../core/providers.dart';

final channelsProvider = FutureProvider<List<GroupSummary>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  final groups = await repo.getGroups();
  // Filter only channels (type='channel')
  return groups.where((g) => g.type == 'channel').toList();
});

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final channelsAsync = ref.watch(channelsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Channels'),
      ),
      body: channelsAsync.when(
        data: (channels) {
          if (channels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No channels yet',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Channels are broadcast-only groups',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return _ChannelItem(
                channel: channel,
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupChatView(
                        groupId: channel.id,
                        groupName: channel.name,
                        groupAvatarUrl: channel.avatarUrl,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading channels',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(channelsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelItem extends StatelessWidget {
  final GroupSummary channel;
  final bool isDark;
  final VoidCallback onTap;

  const _ChannelItem({
    required this.channel,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF111B21) : Colors.white,
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
              // Channel Avatar with verified badge if applicable
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: channel.avatarUrl != null
                        ? CachedNetworkImageProvider(channel.avatarUrl!)
                        : null,
                    child: channel.avatarUrl == null
                        ? Text(
                            channel.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 20),
                          )
                        : null,
                  ),
                  if (channel.isVerified == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF008069),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF111B21) : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            channel.name,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (channel.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFF008069),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            child: Center(
                              child: Text(
                                channel.unreadCount > 999
                                    ? '999+'
                                    : channel.unreadCount.toString(),
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
                    if (channel.lastMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        channel.lastMessage!,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (channel.updatedAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  _formatTime(channel.updatedAt!),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
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

