import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chats/chat_providers.dart';
import '../chats/create_group_screen.dart';
import '../chats/models.dart';
import '../../utils/snackbar_helper.dart';

/// Pick a group to add [user] into (or create a new group with them).
///
/// On desktop this opens as a centered dialog sized like the Switch Account
/// modal (not a bottom sheet).
class AddToGroupSheet extends ConsumerStatefulWidget {
  const AddToGroupSheet({super.key, required this.user});

  final User user;

  /// Same footprint as the rail Switch Account dialog.
  static const BoxConstraints dialogConstraints = BoxConstraints(
    maxWidth: 420,
    maxHeight: 560,
  );

  static Future<void> show(BuildContext context, User user) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: dialogConstraints,
          child: AddToGroupSheet(user: user),
        ),
      ),
    );
  }

  @override
  ConsumerState<AddToGroupSheet> createState() => _AddToGroupSheetState();
}

class _AddToGroupSheetState extends ConsumerState<AddToGroupSheet> {
  bool _loading = true;
  bool _busy = false;
  int? _selectedGroupId;
  int? _addingGroupId;
  List<GroupSummary> _groups = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await ref.read(chatRepositoryProvider).getGroups();
      final filtered = groups
          .where((g) => (g.type ?? 'group') != 'channel')
          .toList();
      if (mounted) {
        setState(() {
          _groups = filtered;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _onGroupTapped(GroupSummary group) async {
    if (_busy) return;
    setState(() => _selectedGroupId = group.id);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Add to group'),
          content: Text(
            'Do you want to add ${widget.user.name} to “${group.name}”?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'No',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _selectedGroupId = null);
      return;
    }
    await _addToGroup(group);
  }

  Future<void> _addToGroup(GroupSummary group) async {
    if (_busy) return;
    final phone = widget.user.phone?.trim();
    if (phone == null || phone.isEmpty) {
      context.showErrorToast('This contact has no phone number to add');
      setState(() => _selectedGroupId = null);
      return;
    }
    setState(() {
      _busy = true;
      _addingGroupId = group.id;
      _selectedGroupId = group.id;
    });
    try {
      await ref.read(chatRepositoryProvider).addGroupMembersByPhones(
            group.id,
            [phone],
          );
      if (!mounted) return;
      Navigator.pop(context);
      context.showSuccessToast('Added ${widget.user.name} to ${group.name}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _addingGroupId = null;
          _selectedGroupId = null;
        });
        context.showErrorToast('Could not add to group: $e');
      }
    }
  }

  Future<void> _createGroupWith() async {
    if (_busy || !mounted) return;
    Navigator.pop(context);
    if (!mounted) return;
    await CreateGroupScreen.showModal(
      context,
      initialMemberIds: widget.user.id > 0 ? [widget.user.id] : const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F2C34) : Colors.white;
    final muted = isDark ? const Color(0xFF8696A0) : Colors.black54;

    return Material(
      color: bg,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add ${widget.user.name} to group',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              ListTile(
                enabled: !_busy,
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF00A884).withValues(alpha: 0.15),
                  child: const Icon(Icons.group_add, color: Color(0xFF00A884)),
                ),
                title: Text('Create group with ${widget.user.name}'),
                onTap: _busy ? null : _createGroupWith,
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_error!, textAlign: TextAlign.center),
                            ),
                          )
                        : _groups.isEmpty
                            ? Center(
                                child: Text(
                                  'No groups yet',
                                  style: TextStyle(color: muted),
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                itemCount: _groups.length,
                                itemBuilder: (context, index) {
                                  final g = _groups[index];
                                  final selected = _selectedGroupId == g.id;
                                  final adding = _addingGroupId == g.id;
                                  return ListTile(
                                    enabled: !_busy,
                                    leading: adding
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Checkbox(
                                            value: selected,
                                            activeColor:
                                                const Color(0xFF00A884),
                                            onChanged: _busy
                                                ? null
                                                : (_) => _onGroupTapped(g),
                                          ),
                                    title: Text(g.name),
                                    subtitle: g.memberCount != null
                                        ? Text('${g.memberCount} members')
                                        : null,
                                    trailing: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isDark
                                          ? const Color(0xFF2A3942)
                                          : Colors.grey.shade200,
                                      backgroundImage: g.avatarUrl != null
                                          ? NetworkImage(g.avatarUrl!)
                                          : null,
                                      child: g.avatarUrl == null
                                          ? Text(
                                              g.name.isNotEmpty
                                                  ? g.name[0].toUpperCase()
                                                  : 'G',
                                            )
                                          : null,
                                    ),
                                    onTap:
                                        _busy ? null : () => _onGroupTapped(g),
                                  );
                                },
                              ),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: Center(
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 22,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Adding ${widget.user.name}…',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
