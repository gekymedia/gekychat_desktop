import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'chat_repo.dart';
import 'models.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  final Set<int> _selectedMemberIds = {};
  String _searchQuery = '';
  bool _isLoading = false;
  Timer? _debounce;
  File? _selectedAvatar;
  String _groupType = 'group'; // 'group' or 'channel'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for type parameter in route
    final uri = GoRouterState.of(context).uri;
    final typeParam = uri.queryParameters['type'];
    if (typeParam == 'channel' && _groupType != 'channel') {
      setState(() {
        _groupType = 'channel';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedAvatar = File(result.files.single.path!);
      });
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final group = await ref.read(chatRepositoryProvider).createGroup(
            name: _nameController.text.trim(),
            memberIds: _selectedMemberIds.toList(),
            avatar: _selectedAvatar,
            type: _groupType,
          );

      if (!mounted) return;
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _groupType == 'channel'
                  ? 'Channel "${group.name}" created successfully'
                  : 'Group "${group.name}" created successfully',
            ),
          ),
        );
      }
      
      // Navigate back using GoRouter
      if (mounted) {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/chats');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && _isLoading) {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/chats');
            }
          },
        ),
        title: Text(_groupType == 'channel' ? 'Create Channel' : 'Create Group'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isLoading ? null : _createGroup,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar selection
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _selectedAvatar != null
                              ? FileImage(_selectedAvatar!)
                              : null,
                          child: _selectedAvatar == null
                              ? const Icon(Icons.group, size: 50, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF008069),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _pickAvatar,
                    child: const Text('Add group icon (optional)'),
                  ),
                ),
                const SizedBox(height: 16),
                // Type selector
                Card(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Group'),
                                subtitle: const Text('Private group chat'),
                                value: 'group',
                                groupValue: _groupType,
                                onChanged: (value) {
                                  setState(() {
                                    _groupType = value!;
                                  });
                                },
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Channel'),
                                subtitle: const Text('Public broadcast'),
                                value: 'channel',
                                groupValue: _groupType,
                                onChanged: (value) {
                                  setState(() {
                                    _groupType = value!;
                                  });
                                },
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _groupType == 'channel' ? 'Channel name' : 'Group name',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Enter ${_groupType == 'channel' ? 'channel' : 'group'} name' : null,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search people',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                _PeoplePicker(
                  searchQuery: _searchQuery,
                  selectedIds: _selectedMemberIds,
                  onToggle: (id, selected) {
                    setState(() {
                      selected ? _selectedMemberIds.add(id) : _selectedMemberIds.remove(id);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeoplePicker extends ConsumerWidget {
  final String searchQuery;
  final Set<int> selectedIds;
  final void Function(int, bool) onToggle;

  const _PeoplePicker({
    required this.searchQuery,
    required this.selectedIds,
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
          return Text('Failed to load people: ${snap.error}');
        }

        final conversations = snap.data ?? [];
        final Map<int, User> users = {};

        for (final c in conversations) {
          users[c.otherUser.id] = c.otherUser;
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No people found'),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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


