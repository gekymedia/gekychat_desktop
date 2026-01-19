import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../chat_repo.dart';
import '../models.dart';

class ShareGroupLinkScreen extends ConsumerStatefulWidget {
  final String shareText;
  final String inviteLink;
  final String groupName;

  const ShareGroupLinkScreen({
    super.key,
    required this.shareText,
    required this.inviteLink,
    required this.groupName,
  });

  @override
  ConsumerState<ShareGroupLinkScreen> createState() => _ShareGroupLinkScreenState();
}

class _ShareGroupLinkScreenState extends ConsumerState<ShareGroupLinkScreen> {
  bool _isLoading = false;
  final Set<int> _selectedConversations = {};
  final Set<int> _selectedGroups = {};

  bool get _hasSelection => _selectedConversations.isNotEmpty || _selectedGroups.isNotEmpty;

  Future<void> _share() async {
    if (!_hasSelection) return;

    setState(() => _isLoading = true);
    final repo = ref.read(chatRepositoryProvider);

    try {
      final tasks = <Future>[];

      // Send to conversations
      for (final id in _selectedConversations) {
        tasks.add(
          repo.sendMessageToConversation(
            conversationId: id,
            body: widget.shareText,
          ),
        );
      }

      // Send to groups
      for (final id in _selectedGroups) {
        tasks.add(
          repo.sendMessageToGroup(
            groupId: id,
            body: widget.shareText,
          ),
        );
      }

      await Future.wait(tasks);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link shared successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: const Text('Share Group Link'),
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
          actions: [
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: (!_hasSelection || _isLoading) ? null : _share,
            ),
          ],
          bottom: TabBar(
            labelColor: isDark ? Colors.white : Colors.black,
            unselectedLabelColor: isDark ? Colors.white70 : Colors.grey[600],
            indicatorColor: AppTheme.primaryGreen,
            tabs: const [
              Tab(text: 'Chats'),
              Tab(text: 'Groups'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _ShareConversationTab(
                    selectedConversations: _selectedConversations,
                    onToggle: (id) {
                      setState(() {
                        if (_selectedConversations.contains(id)) {
                          _selectedConversations.remove(id);
                        } else {
                          _selectedConversations.add(id);
                        }
                      });
                    },
                  ),
                  _ShareGroupTab(
                    selectedGroups: _selectedGroups,
                    onToggle: (id) {
                      setState(() {
                        if (_selectedGroups.contains(id)) {
                          _selectedGroups.remove(id);
                        } else {
                          _selectedGroups.add(id);
                        }
                      });
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _ShareConversationTab extends ConsumerWidget {
  final Set<int> selectedConversations;
  final Function(int) onToggle;

  const _ShareConversationTab({
    required this.selectedConversations,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.read(chatRepositoryProvider);

    return FutureBuilder<List<ConversationSummary>>(
      future: repo.getConversations(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          );
        }

        final conversations = snap.data ?? [];
        if (conversations.isEmpty) {
          return Center(
            child: Text(
              'No conversations',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
            ),
          );
        }

        return ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[300],
          ),
          itemBuilder: (context, i) {
            final c = conversations[i];
            final user = c.otherUser;
            final checked = selectedConversations.contains(c.id);

            return CheckboxListTile(
              value: checked,
              onChanged: (v) => onToggle(c.id),
              title: Text(
                user.name,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              subtitle: c.lastMessage != null
                  ? Text(
                      c.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
                    )
                  : null,
              secondary: CircleAvatar(
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(user.name[0].toUpperCase())
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _ShareGroupTab extends ConsumerWidget {
  final Set<int> selectedGroups;
  final Function(int) onToggle;

  const _ShareGroupTab({
    required this.selectedGroups,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.read(chatRepositoryProvider);

    return FutureBuilder<List<GroupSummary>>(
      future: repo.getGroups(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          );
        }

        final groups = snap.data ?? [];
        if (groups.isEmpty) {
          return Center(
            child: Text(
              'No groups',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
            ),
          );
        }

        return ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[300],
          ),
          itemBuilder: (context, i) {
            final g = groups[i];
            final checked = selectedGroups.contains(g.id);

            return CheckboxListTile(
              value: checked,
              onChanged: (v) => onToggle(g.id),
              title: Text(
                g.name,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              secondary: CircleAvatar(
                child: Text(g.name[0].toUpperCase()),
              ),
            );
          },
        );
      },
    );
  }
}
