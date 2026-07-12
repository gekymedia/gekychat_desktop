import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../chat_providers.dart';
import '../models.dart';
import '../../../utils/snackbar_helper.dart';

/// Pick one or more chats/groups and send [shareText] as a message to each.
class ShareTextToChatsScreen extends ConsumerStatefulWidget {
  final String shareText;
  final String title;
  final String successMessage;

  const ShareTextToChatsScreen({
    super.key,
    required this.shareText,
    this.title = 'Share',
    this.successMessage = 'Shared successfully',
  });

  @override
  ConsumerState<ShareTextToChatsScreen> createState() =>
      _ShareTextToChatsScreenState();
}

class _ShareTextToChatsScreenState extends ConsumerState<ShareTextToChatsScreen> {
  bool _isLoading = false;
  final Set<int> _selectedConversations = {};
  final Set<int> _selectedGroups = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _hasSelection =>
      _selectedConversations.isNotEmpty || _selectedGroups.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (!_hasSelection) return;

    setState(() => _isLoading = true);
    final repo = ref.read(chatRepositoryProvider);

    try {
      final tasks = <Future>[];
      for (final id in _selectedConversations) {
        tasks.add(
          repo.sendMessageToConversation(
            conversationId: id,
            body: widget.shareText,
          ),
        );
      }
      for (final id in _selectedGroups) {
        tasks.add(
          repo.sendMessageToGroup(groupId: id, body: widget.shareText),
        );
      }

      await Future.wait(tasks);

      if (!mounted) return;
      Navigator.pop(context, true);
            context.showSuccessToast(widget.successMessage);    } catch (e) {
      if (!mounted) return;
            context.showErrorToast('Failed to share: $e');    } finally {
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
          title: Text(widget.title),
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search chats and groups...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _searchController.clear,
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF111B21) : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                TabBar(
                  labelColor: isDark ? Colors.white : Colors.black,
                  unselectedLabelColor: isDark ? Colors.white70 : Colors.grey[600],
                  indicatorColor: AppTheme.primaryGreen,
                  tabs: const [
                    Tab(text: 'Chats'),
                    Tab(text: 'Groups'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _ShareConversationTab(
                    selectedConversations: _selectedConversations,
                    searchQuery: _searchQuery,
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
                    searchQuery: _searchQuery,
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
  final String searchQuery;
  final ValueChanged<int> onToggle;

  const _ShareConversationTab({
    required this.selectedConversations,
    required this.searchQuery,
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

        final allConversations = snap.data ?? [];
        final conversations = searchQuery.isEmpty
            ? allConversations
            : allConversations.where((c) {
                final name = c.otherUser.name.toLowerCase();
                return name.contains(searchQuery);
              }).toList();

        if (allConversations.isEmpty) {
          return Center(
            child: Text(
              'No conversations',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
            ),
          );
        }

        if (conversations.isEmpty) {
          return Center(
            child: Text(
              'No chats found',
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
              onChanged: (_) => onToggle(c.id),
              title: Text(
                user.name,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              subtitle: c.lastMessage != null
                  ? Text(
                      c.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    )
                  : null,
              secondary: CircleAvatar(
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')
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
  final String searchQuery;
  final ValueChanged<int> onToggle;

  const _ShareGroupTab({
    required this.selectedGroups,
    required this.searchQuery,
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

        final allGroups = snap.data ?? [];
        final groups = searchQuery.isEmpty
            ? allGroups
            : allGroups.where((g) {
                return g.name.toLowerCase().contains(searchQuery);
              }).toList();

        if (allGroups.isEmpty) {
          return Center(
            child: Text(
              'No groups',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
            ),
          );
        }

        if (groups.isEmpty) {
          return Center(
            child: Text(
              'No groups found',
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
              onChanged: (_) => onToggle(g.id),
              title: Text(
                g.name,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              secondary: CircleAvatar(
                backgroundImage: g.avatarUrl != null
                    ? NetworkImage(g.avatarUrl!)
                    : null,
                child: g.avatarUrl == null
                    ? Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : '?')
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
