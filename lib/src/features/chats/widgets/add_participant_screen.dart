import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat_repo.dart';
import '../models.dart';
import '../../../theme/app_theme.dart';

class AddParticipantScreen extends ConsumerStatefulWidget {
  final int groupId;
  final List<int> existingMemberIds;

  const AddParticipantScreen({
    super.key,
    required this.groupId,
    required this.existingMemberIds,
  });

  @override
  ConsumerState<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends ConsumerState<AddParticipantScreen> {
  final _searchController = TextEditingController();
  final Set<int> _selectedMemberIds = {};
  String _searchQuery = '';
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _addParticipants() async {
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one person to add')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.addGroupMembers(widget.groupId, _selectedMemberIds.toList());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Participants added successfully')),
      );
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add participants: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Add Participants'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _addParticipants,
              child: Text(
                'Add (${_selectedMemberIds.length})',
                style: TextStyle(
                  color: _selectedMemberIds.isEmpty
                      ? (isDark ? Colors.grey : Colors.grey[400])
                      : AppTheme.primaryGreen,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search people',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _PeoplePicker(
              searchQuery: _searchQuery,
              selectedIds: _selectedMemberIds,
              existingMemberIds: widget.existingMemberIds,
              onToggle: (id, selected) {
                setState(() {
                  selected ? _selectedMemberIds.add(id) : _selectedMemberIds.remove(id);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeoplePicker extends ConsumerWidget {
  final String searchQuery;
  final Set<int> selectedIds;
  final List<int> existingMemberIds;
  final void Function(int, bool) onToggle;

  const _PeoplePicker({
    required this.searchQuery,
    required this.selectedIds,
    required this.existingMemberIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(chatRepositoryProvider);

    return FutureBuilder<List<ConversationSummary>>(
      future: repo.getConversations(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text('Failed to load people: ${snap.error}'),
          );
        }

        final conversations = snap.data ?? [];
        final Map<int, User> users = {};

        for (final c in conversations) {
          // Skip existing members
          if (!existingMemberIds.contains(c.otherUser.id)) {
            users[c.otherUser.id] = c.otherUser;
          }
        }

        var people = users.values.toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (searchQuery.isNotEmpty) {
          people = people
              .where((u) =>
                  u.name.toLowerCase().contains(searchQuery) ||
                  (u.phone ?? '').toLowerCase().contains(searchQuery))
              .toList();
        }

        if (people.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No people found'),
            ),
          );
        }

        return ListView.separated(
          itemCount: people.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final u = people[i];
            final checked = selectedIds.contains(u.id);

            return CheckboxListTile(
              value: checked,
              onChanged: (v) => onToggle(u.id, v == true),
              title: Text(u.name),
              subtitle: u.phone != null ? Text(u.phone!) : null,
              secondary: CircleAvatar(
                child: Text(u.name[0].toUpperCase()),
              ),
            );
          },
        );
      },
    );
  }
}

