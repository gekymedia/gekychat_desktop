import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/providers.dart';
import '../../widgets/colored_avatar.dart';
import 'chat_providers.dart';
import 'models.dart';
import 'sidebar_inbox_bump.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/desktop_center_modal.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  final String? initialGroupType;
  final bool forModal;

  const CreateGroupScreen({
    super.key,
    this.initialGroupType,
    this.forModal = false,
  });

  static Future<bool?> showModal(
    BuildContext context, {
    String groupType = 'group',
  }) {
    final title = groupType == 'channel' ? 'Create Channel' : 'Create Group';
    return showDesktopCenterModal<bool>(
      context: context,
      title: title,
      maxWidth: 640,
      maxHeightFraction: 0.88,
      child: CreateGroupScreen(
        initialGroupType: groupType,
        forModal: true,
      ),
    );
  }

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
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
    if (widget.initialGroupType != null) {
      final type = widget.initialGroupType!;
      if (_groupType != type) {
        setState(() => _groupType = type);
      }
      return;
    }
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
    _descriptionController.dispose();
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
            context.showInfoToast('Select at least one member');      return;
    }

    setState(() => _isLoading = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final group = await chatRepo.createGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty 
                ? null 
                : _descriptionController.text.trim(),
            memberIds: _selectedMemberIds.toList(),
            avatar: _selectedAvatar,
            type: _groupType,
          );

      if (!mounted) return;

      await chatRepo.cacheGroupToDatabase(group);
      if (!mounted) return;

      ref.read(sidebarPendingGroupsProvider.notifier).update((items) {
        if (items.any((g) => g.id == group.id)) return items;
        return [...items, group];
      });
      unawaited(ref.read(optimizedGroupsProvider.notifier).refreshSilently());
      ref.read(pendingDesktopGroupOpenProvider.notifier).state = group;
      ref.read(currentSectionProvider.notifier).setSection('/chats');

            context.showSuccessToast(
            _groupType == 'channel'
                ? 'Channel "${group.name}" created successfully'
                : 'Group "${group.name}" created successfully',
          );
      if (widget.forModal && context.mounted) {
        Navigator.of(context).pop(true);
      } else if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/chats');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
                context.showErrorToast('Failed to create group: ${e.toString()}');      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _close() {
    if (widget.forModal) {
      Navigator.of(context).pop();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/chats');
    }
  }

  Widget _buildFormContent(bool isDark) {
    final lockType = widget.initialGroupType != null;

    return Form(
      key: _formKey,
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
                // Type selector (hidden when opened as New group / New channel)
                if (!lockType)
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
                if (!lockType) const SizedBox(height: 16),
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
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: _groupType == 'channel' ? 'Channel description (optional)' : 'Group description (optional)',
                    hintText: 'Describe what this ${_groupType == 'channel' ? 'channel' : 'group'} is about',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  maxLength: 500,
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
                if (widget.forModal) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isLoading ? null : _createGroup,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF008069),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _groupType == 'channel'
                                ? 'Create channel'
                                : 'Create group',
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final form = _buildFormContent(isDark);

    if (widget.forModal) {
      return form;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _close,
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
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: form,
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
          if (c.isSavedMessages) continue;
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
              secondary: ColoredAvatar(
                imageUrl: u.avatarUrl,
                name: u.name,
                radius: 20,
              ),
            );
          },
        );
      },
    );
  }
}


