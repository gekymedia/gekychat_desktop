import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chats/chat_providers.dart';
import '../chats/create_group_screen.dart';
import '../chats/models.dart';
import '../../utils/snackbar_helper.dart';

/// Pick a group to add [user] into (or create a new group with them).
class AddToGroupSheet extends ConsumerStatefulWidget {
  const AddToGroupSheet({super.key, required this.user});

  final User user;

  static Future<void> show(BuildContext context, User user) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToGroupSheet(user: user),
    );
  }

  @override
  ConsumerState<AddToGroupSheet> createState() => _AddToGroupSheetState();
}

class _AddToGroupSheetState extends ConsumerState<AddToGroupSheet> {
  bool _loading = true;
  bool _busy = false;
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

  Future<void> _addToGroup(GroupSummary group) async {
    if (_busy) return;
    final phone = widget.user.phone?.trim();
    if (phone == null || phone.isEmpty) {
      context.showErrorToast('This contact has no phone number to add');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(chatRepositoryProvider).addGroupMembersByPhones(
            group.id,
            [phone],
          );
      if (!mounted) return;
      Navigator.pop(context);
      context.showInfoToast('Added ${widget.user.name} to ${group.name}');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showErrorToast('Could not add to group: $e');
      }
    }
  }

  Future<void> _createGroupWith() async {
    if (!mounted) return;
    Navigator.pop(context);
    if (!mounted) return;
    await CreateGroupScreen.showModal(
      context,
      initialMemberIds: widget.user.id > 0 ? [widget.user.id] : const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F2C34) : Colors.white;
    final muted = isDark ? const Color(0xFF8696A0) : Colors.black54;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
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
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF00A884).withValues(alpha: 0.15),
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
                        ? Center(child: Text(_error!))
                        : _groups.isEmpty
                            ? Center(
                                child: Text(
                                  'No groups yet',
                                  style: TextStyle(color: muted),
                                ),
                              )
                            : ListView.builder(
                                controller: controller,
                                itemCount: _groups.length,
                                itemBuilder: (context, index) {
                                  final g = _groups[index];
                                  return ListTile(
                                    leading: CircleAvatar(
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
                                    title: Text(g.name),
                                    subtitle: g.memberCount != null
                                        ? Text('${g.memberCount} members')
                                        : null,
                                    trailing: _busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.chevron_right),
                                    onTap: _busy ? null : () => _addToGroup(g),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
