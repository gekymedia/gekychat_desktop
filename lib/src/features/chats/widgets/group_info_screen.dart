import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/constrained_slide_route.dart';
import '../chat_repo.dart';
import '../models.dart';
import '../../media/media_gallery_screen.dart';
import 'search_in_chat_screen.dart';
import 'edit_group_screen.dart';
import 'add_participant_screen.dart';
import 'share_group_link_screen.dart';

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
                            ConstrainedSlideRightRoute(
                              page: SearchInChatScreen(
                                groupId: groupId,
                                title: group['name'],
                              ),
                              leftOffset: 400.0, // Sidebar width
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
                            ConstrainedSlideRightRoute(
                              page: MediaGalleryScreen(
                                groupId: groupId,
                                title: group['name'],
                              ),
                              leftOffset: 400.0, // Sidebar width
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.share),
                        title: Text(group['type'] == 'channel' ? 'Share channel link' : 'Share group link'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _shareInviteLink(context, ref, groupId, group),
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
                      // Only show "Add participants" for groups, not channels (channels use link joining)
                      if (canManage && group['type'] != 'channel')
                        ListTile(
                          leading: const Icon(Icons.person_add),
                          title: const Text('Add participant'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final members = (group['members'] as List<dynamic>?)
                                ?.map((m) => m['id'] as int)
                                .toList() ?? [];
                            final result = await Navigator.push<bool>(
                              context,
                              ConstrainedSlideRightRoute(
                                page: AddParticipantScreen(
                                  groupId: groupId,
                                  existingMemberIds: members,
                                ),
                                leftOffset: 400.0, // Sidebar width
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
                              ConstrainedSlideRightRoute(
                                page: EditGroupScreen(groupId: groupId),
                                leftOffset: 400.0, // Sidebar width
                              ),
                            ).then((_) {
                              ref.invalidate(groupInfoProvider(groupId));
                            });
                          },
                        ),
                        // Message Lock Toggle (only for groups, not channels, and only for admins/owners)
                        if (group['type'] != 'channel')
                          SwitchListTile(
                            title: const Text('Message Lock'),
                            subtitle: Text(group['message_lock'] == true
                                ? 'Only admins can send messages'
                                : 'All members can send messages'),
                            value: group['message_lock'] == true,
                            onChanged: (bool value) async {
                              try {
                                final api = ref.read(apiServiceProvider);
                                await api.put('/groups/$groupId/toggle-message-lock');
                                ref.invalidate(groupInfoProvider(groupId));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Message lock ${value ? 'enabled' : 'disabled'}')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to toggle message lock: $e')),
                                  );
                                }
                              }
                            },
                            secondary: Icon(group['message_lock'] == true ? Icons.lock : Icons.lock_open),
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
  
  Future<void> _shareInviteLink(BuildContext context, WidgetRef ref, int groupId, Map<String, dynamic> group) async {
    try {
      final api = ref.read(apiServiceProvider);
      final isDark = Theme.of(context).brightness == Brightness.dark;
      
      // Get or generate invite link
      String? inviteLink;
      try {
        final infoResponse = await api.getGroupInviteInfo(groupId);
        if (infoResponse.data['success'] == true && infoResponse.data['invite_link'] != null) {
          inviteLink = infoResponse.data['invite_link'];
        }
      } catch (e) {
        debugPrint('Failed to get invite info: $e');
      }
      
      // If no invite link, generate one (admin or owner only)
      // Check both is_admin and is_owner flags
      final isAdmin = group['is_admin'] == true;
      final isOwner = group['is_owner'] == true;
      if (inviteLink == null && (isAdmin || isOwner)) {
        try {
          final generateResponse = await api.generateGroupInvite(groupId);
          if (generateResponse.data['success'] == true) {
            inviteLink = generateResponse.data['invite_link'];
          }
        } catch (e) {
          debugPrint('Failed to generate invite: $e');
        }
      }
      
      if (inviteLink == null || inviteLink.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to get invite link. Only admins and owners can generate invite links.')),
          );
        }
        return;
      }
      
      // Show dialog with share options
      final groupName = group['name'] as String? ?? 'Group';
      final groupType = group['type'] == 'channel' ? 'channel' : 'group';
      final shareText = 'Join my $groupType "$groupName" on GekyChat: $inviteLink';
      
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          title: Text(
            group['type'] == 'channel' ? 'Share channel link' : 'Share group link',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat, color: AppTheme.primaryGreen),
                title: const Text('Share on GekyChat'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    ConstrainedSlideRightRoute(
                      page: ShareGroupLinkScreen(
                        shareText: shareText,
                        inviteLink: inviteLink!,
                        groupName: groupName,
                      ),
                      leftOffset: 400.0, // Sidebar width
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: AppTheme.primaryGreen),
                title: const Text('Copy link'),
                onTap: () async {
                  Navigator.pop(context);
                  await Clipboard.setData(ClipboardData(text: inviteLink!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: AppTheme.primaryGreen),
                title: const Text('Share via external app'),
                onTap: () async {
                  Navigator.pop(context);
                  await Share.share(
                    shareText,
                    subject: 'Invitation to $groupName',
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share invite link: $e')),
        );
      }
    }
  }
}

