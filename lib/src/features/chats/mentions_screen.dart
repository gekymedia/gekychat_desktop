import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../utils/date_formatter.dart';
import 'models.dart';

/// Screen that displays all @mentions for the current user
class MentionsScreen extends ConsumerStatefulWidget {
  const MentionsScreen({super.key});

  @override
  ConsumerState<MentionsScreen> createState() => _MentionsScreenState();
}

class _MentionsScreenState extends ConsumerState<MentionsScreen> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _mentions = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMentions();
  }

  Future<void> _loadMentions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final mentionsResponse = await _apiService.getMentions();
      final statsResponse = await _apiService.getMentionStats();

      setState(() {
        _mentions = List<Map<String, dynamic>>.from(
          mentionsResponse.data['data'] ?? [],
        );
        _stats = statsResponse.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int mentionId, int index) async {
    try {
      await _apiService.markMentionAsRead(mentionId);
      
      setState(() {
        _mentions[index]['is_read'] = true;
        if (_stats != null) {
          final unreadCount = _stats!['unread_mentions'] ?? 0;
          _stats!['unread_mentions'] = (unreadCount - 1).clamp(0, 999);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.markAllMentionsAsRead();
      
      setState(() {
        for (var mention in _mentions) {
          mention['is_read'] = true;
        }
        if (_stats != null) {
          _stats!['unread_mentions'] = 0;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All mentions marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }

  void _navigateToMessage(Map<String, dynamic> mention) {
    final mentionable = mention['mentionable'];
    if (mentionable == null) return;

    // Determine if it's a group or conversation message
    final groupId = mention['group_id'] ?? mentionable['group_id'];
    final conversationId = mention['conversation_id'] ?? mentionable['conversation_id'];

    if (groupId != null) {
      // Navigate to group chat
      Navigator.of(context).pushNamed(
        '/group-chat',
        arguments: {'groupId': groupId},
      );
    } else if (conversationId != null) {
      // Navigate to 1-on-1 chat
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {'conversationId': conversationId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentions'),
        actions: [
          if (_mentions.isNotEmpty && _stats != null && (_stats!['unread_mentions'] ?? 0) > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMentions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_mentions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.alternate_email,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No mentions yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'When someone mentions you with @username,\nthey\'ll appear here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMentions,
      child: Column(
        children: [
          // Stats Card
          if (_stats != null) _buildStatsCard(),
          // Mentions List
          Expanded(
            child: ListView.builder(
              itemCount: _mentions.length,
              itemBuilder: (context, index) {
                final mention = _mentions[index];
                return _buildMentionTile(mention, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalMentions = _stats!['total_mentions'] ?? 0;
    final unreadMentions = _stats!['unread_mentions'] ?? 0;
    final mentionsToday = _stats!['mentions_today'] ?? 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatColumn(
              icon: Icons.alternate_email,
              label: 'Total',
              value: totalMentions.toString(),
              color: Colors.blue,
            ),
            _buildStatColumn(
              icon: Icons.mark_email_unread,
              label: 'Unread',
              value: unreadMentions.toString(),
              color: Colors.orange,
            ),
            _buildStatColumn(
              icon: Icons.today,
              label: 'Today',
              value: mentionsToday.toString(),
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildMentionTile(Map<String, dynamic> mention, int index) {
    final isRead = mention['is_read'] ?? false;
    final mentionedBy = mention['mentioned_by_user'];
    final messagePreview = mention['message_preview'] ?? 'Message';
    final createdAt = DateTime.tryParse(mention['created_at'] ?? '');

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: mentionedBy?['avatar_path'] != null
            ? NetworkImage(mentionedBy['avatar_path'])
            : null,
        child: mentionedBy?['avatar_path'] == null
            ? Text(
                mentionedBy?['name']?.substring(0, 1).toUpperCase() ?? '?',
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              mentionedBy?['name'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messagePreview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isRead ? Colors.grey[600] : Colors.black87,
            ),
          ),
          if (createdAt != null)
            Text(
              DateFormatter.formatChatTimestamp(createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          isRead ? Icons.mark_email_read : Icons.mark_email_unread,
          color: isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
        ),
        onPressed: isRead ? null : () => _markAsRead(mention['id'], index),
        tooltip: isRead ? 'Read' : 'Mark as read',
      ),
      onTap: () {
        _navigateToMessage(mention);
        if (!isRead) {
          _markAsRead(mention['id'], index);
        }
      },
    );
  }
}
