import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_repo.dart';
import 'models.dart';

class ForwardMessageScreen extends ConsumerStatefulWidget {
  final Message message;

  const ForwardMessageScreen({
    super.key,
    required this.message,
  });

  @override
  ConsumerState<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends ConsumerState<ForwardMessageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _selectedConversationIds = {};
  final Set<int> _selectedGroupIds = {};
  bool _isLoading = false;

  bool get _hasSelection =>
      _selectedConversationIds.isNotEmpty || _selectedGroupIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _forward() async {
    setState(() => _isLoading = true);
    final repo = ref.read(chatRepositoryProvider);

    try {
      final tasks = <Future>[];

      for (final id in _selectedConversationIds) {
        tasks.add(
          repo.sendMessageToConversation(
            conversationId: id,
            forwardFrom: widget.message.id,
          ),
        );
      }

      for (final id in _selectedGroupIds) {
        tasks.add(
          repo.sendMessageToGroup(
            groupId: id,
            body: null,
            forwardFrom: widget.message.id,
          ),
        );
      }

      await Future.wait(tasks);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message forwarded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to forward: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Forward Message'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Groups'),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: (!_hasSelection || _isLoading) ? null : _forward,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConversationTab(
            selectedIds: _selectedConversationIds,
            onToggle: (id, selected) {
              setState(() {
                selected ? _selectedConversationIds.add(id) : _selectedConversationIds.remove(id);
              });
            },
          ),
          _GroupTab(
            selectedIds: _selectedGroupIds,
            onToggle: (id, selected) {
              setState(() {
                selected ? _selectedGroupIds.add(id) : _selectedGroupIds.remove(id);
              });
            },
          ),
        ],
      ),
    );
  }
}

class _ConversationTab extends ConsumerWidget {
  final Set<int> selectedIds;
  final void Function(int, bool) onToggle;

  const _ConversationTab({
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(chatRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<ConversationSummary>>(
      future: repo.getConversations(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final conversations = snap.data ?? [];
        if (conversations.isEmpty) {
          return const Center(child: Text('No conversations'));
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, i) {
            final conv = conversations[i];
            final checked = selectedIds.contains(conv.id);

            return CheckboxListTile(
              value: checked,
              onChanged: (v) => onToggle(conv.id, v == true),
              title: Text(conv.otherUser.name),
              subtitle: Text(conv.lastMessage ?? ''),
            );
          },
        );
      },
    );
  }
}

class _GroupTab extends ConsumerWidget {
  final Set<int> selectedIds;
  final void Function(int, bool) onToggle;

  const _GroupTab({
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(chatRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<GroupSummary>>(
      future: repo.getGroups(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final groups = snap.data ?? [];
        if (groups.isEmpty) {
          return const Center(child: Text('No groups'));
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, i) {
            final group = groups[i];
            final checked = selectedIds.contains(group.id);

            return CheckboxListTile(
              value: checked,
              onChanged: (v) => onToggle(group.id, v == true),
              title: Text(group.name),
            );
          },
        );
      },
    );
  }
}


