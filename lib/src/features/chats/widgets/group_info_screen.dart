import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../chat_repo.dart';
import '../models.dart';
import '../../../core/api_service.dart';
import '../../media/media_gallery_screen.dart';
import 'search_in_chat_screen.dart';
import 'edit_group_screen.dart';
import 'add_participant_screen.dart';

final groupInfoProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, groupId) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/groups/$groupId');
  return response.data['data'] ?? {};
});

class GroupInfoScreen extends ConsumerWidget {
  final int groupId;

  const GroupInfoScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupAsync = ref.watch(groupInfoProvider(groupId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: groupAsync.when(
          data: (group) => Text(group['type'] == 'channel' ? 'Channel Info' : 'Group Info'),
          loading: () => const Text('Group Info'),
          error: (_, __) => const Text('Group Info'),
        ),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: groupAsync.when(
        data: (group) {
          final members = (group['members'] as List?)
                  ?.map((m) => User.fromJson(m))
                  .toList() ??
              [];
          final admins = (group['admins'] as List?)
                  ?.map((m) => User.fromJson(m))
                  .toList() ??
              [];
          final isOwner = group['is_owner'] ?? false;
          final isAdmin = group['is_admin'] ?? false;
          final canManage = isOwner || isAdmin;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Group Header
                Container(
                  padding: const EdgeInsets.all(24),
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: group['avatar_url'] != null
                            ? CachedNetworkImageProvider(group['avatar_url'])
                            : null,
                        child: group['avatar_url'] == null
                            ? const Icon(Icons.group, size: 50)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        group['name'] ?? 'Group',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (group['description'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          group['description'],
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Group Actions
                Card(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.search),
                        title: const Text('Search'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchInChatScreen(
                                groupId: groupId,
                                title: group['name'],
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: const Text('Media, Links, and Docs'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MediaGalleryScreen(
                                groupId: groupId,
                                title: group['name'],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Members Section
                Card(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${members.length} ${members.length == 1 ? 'member' : 'members'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ),
                      if (canManage)
                        ListTile(
                          leading: const Icon(Icons.person_add),
                          title: Text(group['type'] == 'channel' ? 'Add participant' : 'Add participant'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final members = (group['members'] as List<dynamic>?)
                                ?.map((m) => m['id'] as int)
                                .toList() ?? [];
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddParticipantScreen(
                                  groupId: groupId,
                                  existingMemberIds: members,
                                ),
                              ),
                            );
                            if (result == true) {
                              ref.invalidate(groupInfoProvider(groupId));
                            }
                          },
                        ),
                      ...members.map((member) {
                        final isMemberAdmin = admins.any((a) => a.id == member.id);
                        final isMemberOwner = group['owner_id'] == member.id;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: member.avatarUrl != null
                                ? CachedNetworkImageProvider(member.avatarUrl!)
                                : null,
                            child: member.avatarUrl == null
                                ? Text(member.name[0].toUpperCase())
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(member.name)),
                              if (isMemberOwner)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Owner',
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else if (isMemberAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: member.phone != null
                              ? Text(member.phone!)
                              : null,
                          trailing: canManage && !isMemberOwner
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    _handleMemberAction(
                                        context, ref, member.id, value, isMemberAdmin);
                                  },
                                  itemBuilder: (context) => [
                                    if (!isMemberAdmin)
                                      const PopupMenuItem(
                                          value: 'promote', child: Text('Make admin')),
                                    if (isMemberAdmin)
                                      const PopupMenuItem(
                                          value: 'demote', child: Text('Remove admin')),
                                    const PopupMenuItem(
                                        value: 'remove', child: Text('Remove')),
                                  ],
                                )
                              : null,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Group Settings (if admin/owner)
                if (canManage)
                  Card(
                    color: isDark ? const Color(0xFF202C33) : Colors.white,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: Text(group['type'] == 'channel' ? 'Edit channel' : 'Edit group'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditGroupScreen(groupId: groupId),
                              ),
                            ).then((_) {
                              ref.invalidate(groupInfoProvider(groupId));
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.exit_to_app),
                          title: Text(group['type'] == 'channel' ? 'Exit channel' : 'Exit group'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showExitGroupDialog(context, ref, isDark),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading group info: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(groupInfoProvider(groupId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMemberAction(BuildContext context, WidgetRef ref, int userId,
      String action, bool isAdmin) async {
    final chatRepo = ref.read(chatRepositoryProvider);
    try {
      switch (action) {
        case 'promote':
          await chatRepo.promoteGroupAdmin(groupId, userId);
          break;
        case 'demote':
          await chatRepo.demoteGroupAdmin(groupId, userId);
          break;
        case 'remove':
          await chatRepo.removeGroupMember(groupId, userId);
          break;
      }
      ref.invalidate(groupInfoProvider(groupId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Member ${action}d successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  void _showExitGroupDialog(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: const Text('Exit Group'),
        content: const Text('Are you sure you want to exit this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final chatRepo = ref.read(chatRepositoryProvider);
                await chatRepo.leaveGroup(groupId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Left group successfully')),
                  );
                  Navigator.pop(context); // Go back to chat list
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to leave group: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

