import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'starred_repository.dart';
import 'models.dart';

final starredMessagesProvider = FutureProvider<List<StarredMessage>>((ref) async {
  final repo = ref.read(starredRepositoryProvider);
  return await repo.getStarredMessages();
});

class StarredMessagesScreen extends ConsumerWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final starredAsync = ref.watch(starredMessagesProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Starred Messages'),
      ),
      body: starredAsync.when(
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_border,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No starred messages',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap and hold a message to star it',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group messages by date
          final groupedMessages = _groupMessagesByDate(messages);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(starredMessagesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: groupedMessages.keys.length,
              itemBuilder: (context, index) {
                final date = groupedMessages.keys.elementAt(index);
                final dateMessages = groupedMessages[date]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        date,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...dateMessages.map((msg) => _StarredMessageItem(
                      message: msg,
                      isDark: isDark,
                    )),
                  ],
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading starred messages',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(starredMessagesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<StarredMessage>> _groupMessagesByDate(List<StarredMessage> messages) {
    final grouped = <String, List<StarredMessage>>{};
    
    for (final msg in messages) {
      final date = _formatDate(msg.createdAt);
      grouped.putIfAbsent(date, () => []).add(msg);
    }
    
    return grouped;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMMM d').format(date);
    }
  }
}

class _StarredMessageItem extends StatelessWidget {
  final StarredMessage message;
  final bool isDark;

  const _StarredMessageItem({
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: message.senderAvatar != null
              ? CachedNetworkImageProvider(message.senderAvatar!)
              : null,
          child: message.senderAvatar == null
              ? Text(
                  message.senderName?[0].toUpperCase() ?? '?',
                  style: const TextStyle(fontSize: 20),
                )
              : null,
        ),
        title: Text(
          message.senderName ?? 'Unknown',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (message.attachmentUrls != null && message.attachmentUrls!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: message.attachmentUrls!.take(3).map((url) {
                  return Icon(
                    Icons.attachment,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        trailing: Text(
          DateFormat('h:mm a').format(message.createdAt),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        onTap: () {
          // TODO: Navigate to the conversation/group where this message is located
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => ChatView(...),
          //   ),
          // );
        },
      ),
    );
  }
}

