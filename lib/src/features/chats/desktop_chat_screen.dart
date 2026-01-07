import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../profile/settings_screen.dart';
import '../profile/profile_edit_screen.dart';
import '../contacts/contacts_screen.dart';
import '../search/search_screen.dart';
import '../status/status_list_screen.dart';
import '../status/create_status_screen.dart';
import 'create_group_screen.dart';
import 'models.dart';
import 'chat_repo.dart';
import 'widgets/conversation_list_item.dart';
import 'widgets/group_list_item.dart';
import 'widgets/chat_view.dart';
import 'widgets/group_chat_view.dart';
import '../calls/calls_screen.dart';
import '../channels/channels_screen.dart';
import '../starred/starred_screen.dart';
import '../archive/archived_screen.dart';
import '../broadcast/broadcast_lists_screen.dart';
import '../two_factor/two_factor_screen.dart';
import '../linked_devices/linked_devices_screen.dart';
import '../privacy/privacy_settings_screen.dart';
import '../notifications/notification_settings_screen.dart';
import '../media_auto_download/media_auto_download_screen.dart';
import '../storage/storage_usage_screen.dart';
import '../world/world_feed_screen.dart';
import '../mail/mail_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/feature_flags.dart';
import '../multi_account/account_switcher.dart';
import '../../widgets/side_nav.dart';
import '../../theme/app_theme.dart';

class DesktopChatScreen extends ConsumerStatefulWidget {
  const DesktopChatScreen({super.key});

  @override
  ConsumerState<DesktopChatScreen> createState() => _DesktopChatScreenState();
}

class _DesktopChatScreenState extends ConsumerState<DesktopChatScreen> with WidgetsBindingObserver {
  ConversationSummary? _selectedConversation;
  GroupSummary? _selectedGroup;
  int? _selectedConversationId;
  int? _selectedGroupId;

  late Future<List<ConversationSummary>> _conversationsFuture;
  late Future<List<GroupSummary>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _loadGroups();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes to foreground
      _loadConversations();
      _loadGroups();
    }
  }

  void _loadConversations() {
    final chatRepo = ref.read(chatRepositoryProvider);
    setState(() {
      _conversationsFuture = chatRepo.getConversations();
    });
  }

  void _loadGroups() {
    final chatRepo = ref.read(chatRepositoryProvider);
    setState(() {
      _groupsFuture = chatRepo.getGroups();
    });
  }

  void _showConversationMenuAtPosition(BuildContext context, ConversationSummary conversation, Offset position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatRepo = ref.read(chatRepositoryProvider);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx,
        MediaQuery.of(context).size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              const SizedBox(width: 8),
              Text(conversation.isPinned ? 'Unpin' : 'Pin'),
            ],
          ),
          onTap: () async {
            try {
              if (conversation.isPinned) {
                await chatRepo.unpinConversation(conversation.id);
              } else {
                await chatRepo.pinConversation(conversation.id);
              }
              _loadConversations();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            }
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(conversation.archivedAt != null ? Icons.unarchive : Icons.archive),
              const SizedBox(width: 8),
              Text(conversation.archivedAt != null ? 'Unarchive' : 'Archive'),
            ],
          ),
          onTap: () async {
            try {
              if (conversation.archivedAt != null) {
                await chatRepo.unarchiveConversation(conversation.id);
              } else {
                await chatRepo.archiveConversation(conversation.id);
              }
              _loadConversations();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            }
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.mark_chat_unread),
              SizedBox(width: 8),
              Text('Mark as unread'),
            ],
          ),
          onTap: () async {
            try {
              await chatRepo.markConversationUnread(conversation.id);
              _loadConversations();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  void _showConversationMenu(BuildContext context, ConversationSummary conversation) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero) ?? Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
    _showConversationMenuAtPosition(context, conversation, position);
  }

  void _showGroupMenuAtPosition(BuildContext context, GroupSummary group, Offset position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatRepo = ref.read(chatRepositoryProvider);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx,
        MediaQuery.of(context).size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(group.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              const SizedBox(width: 8),
              Text(group.isPinned ? 'Unpin' : 'Pin'),
            ],
          ),
          onTap: () async {
            try {
              if (group.isPinned) {
                await chatRepo.unpinGroup(group.id);
              } else {
                await chatRepo.pinGroup(group.id);
              }
              _loadGroups();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            }
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(group.isMuted ? Icons.notifications : Icons.notifications_off),
              const SizedBox(width: 8),
              Text(group.isMuted ? 'Unmute' : 'Mute'),
            ],
          ),
          onTap: () async {
            try {
              if (group.isMuted) {
                await chatRepo.unmuteGroup(group.id);
              } else {
                await chatRepo.muteGroup(group.id, minutes: 1440); // 24 hours
              }
              _loadGroups();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  void _showGroupMenu(BuildContext context, GroupSummary group) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero) ?? Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
    _showGroupMenuAtPosition(context, group, position);
  }

  void _showNewChatMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Get the position of the button to show menu nearby
    final RenderBox? buttonBox = context.findRenderObject() as RenderBox?;
    final Offset buttonPosition = buttonBox?.localToGlobal(Offset.zero) ?? const Offset(0, 0);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + 40,
        MediaQuery.of(context).size.width - buttonPosition.dx,
        MediaQuery.of(context).size.height - buttonPosition.dy - 40,
      ),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.group_add, size: 20),
              SizedBox(width: 12),
              Text('New group'),
            ],
          ),
          onTap: () {
            Future.microtask(() {
              context.go('/create-group');
            });
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.campaign, size: 20),
              SizedBox(width: 12),
              Text('New channel'),
            ],
          ),
          onTap: () {
            Future.microtask(() {
              context.go('/create-group?type=channel');
            });
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.person_add, size: 20),
              SizedBox(width: 12),
              Text('New contact'),
            ],
          ),
          onTap: () {
            Future.microtask(() {
              context.go('/contacts');
            });
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.qr_code_scanner, size: 20),
              SizedBox(width: 12),
              Text('Scan QR code'),
            ],
          ),
          onTap: () {
            // TODO: Implement QR code scanner for desktop
            Future.microtask(() {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR code scanner coming soon')),
              );
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProfileAsync = ref.watch(currentUserProvider);

    // Get current route for side nav
    final currentRoute = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      body: Row(
        children: [
          // Side Nav (like web version)
          SideNav(currentRoute: currentRoute),
          
          // Sidebar
          Container(
            width: 400,
            color: isDark ? const Color(0xFF111B21) : Colors.white,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF202C33) : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      userProfileAsync.when(
                        data: (userProfile) => CircleAvatar(
                          radius: 24,
                          backgroundImage: userProfile.avatarUrl != null
                              ? CachedNetworkImageProvider(userProfile.avatarUrl!)
                              : null,
                          child: userProfile.avatarUrl == null
                              ? Text(userProfile.name[0].toUpperCase(), style: const TextStyle(fontSize: 20))
                              : null,
                        ),
                        loading: () => const CircleAvatar(radius: 24, child: CircularProgressIndicator()),
                        error: (_, __) => const CircleAvatar(radius: 24, child: Icon(Icons.person)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userProfileAsync.value?.name ?? 'User',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // New chat/group button
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        tooltip: 'New chat',
                        onPressed: () => _showNewChatMenu(context),
                      ),
                      // Account Switcher (if multi-account enabled)
                      const AccountSwitcher(),
                      Consumer(
                        builder: (context, ref, child) {
                          final worldFeedEnabled = featureEnabled(ref, 'world_feed');
                          final emailChatEnabled = featureEnabled(ref, 'email_chat');
                          final advancedAiEnabled = featureEnabled(ref, 'advanced_ai');
                          
                          final userProfileAsync = ref.watch(currentUserProvider);
                          final hasUsername = userProfileAsync.when(
                            data: (profile) => profile.hasUsername,
                            loading: () => false,
                            error: (_, __) => false,
                          );

                          return PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.grey[600]),
                            onSelected: (value) {
                              switch (value) {
                                case 'calls':
                                  context.go('/calls');
                                  break;
                                case 'world':
                                  context.go('/world');
                                  break;
                                case 'mail':
                                  context.go('/mail');
                                  break;
                                case 'ai':
                                  context.go('/ai');
                                  break;
                                case 'settings':
                                  context.go('/settings');
                                  break;
                                case 'profile':
                                  context.go('/profile');
                                  break;
                                case 'contacts':
                                  context.go('/contacts');
                                  break;
                                case 'search':
                                  context.go('/search');
                                  break;
                                case 'starred':
                                  context.go('/starred');
                                  break;
                                case 'archived':
                                  context.go('/archived');
                                  break;
                                case 'broadcast_lists':
                                  context.go('/broadcast-lists');
                                  break;
                                case 'two_factor':
                                  context.go('/two-factor');
                                  break;
                                case 'linked_devices':
                                  context.go('/linked-devices');
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'calls', child: Row(
                                children: [
                                  Icon(Icons.phone, size: 20),
                                  SizedBox(width: 12),
                                  Text('Calls'),
                                ],
                              )),
                              if (worldFeedEnabled && hasUsername)
                                const PopupMenuItem(value: 'world', child: Row(
                                  children: [
                                    Icon(Icons.explore, size: 20),
                                    SizedBox(width: 12),
                                    Text('World'),
                                  ],
                                )),
                              if (emailChatEnabled && hasUsername)
                                const PopupMenuItem(value: 'mail', child: Row(
                                  children: [
                                    Icon(Icons.mail, size: 20),
                                    SizedBox(width: 12),
                                    Text('Mail'),
                                  ],
                                )),
                              if (advancedAiEnabled)
                                const PopupMenuItem(value: 'ai', child: Row(
                                  children: [
                                    Icon(Icons.smart_toy, size: 20),
                                    SizedBox(width: 12),
                                    Text('AI Assistant'),
                                  ],
                                )),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value: 'settings', child: Text('Settings')),
                              const PopupMenuItem(value: 'profile', child: Text('Profile')),
                              const PopupMenuItem(value: 'contacts', child: Text('Contacts')),
                              const PopupMenuItem(value: 'search', child: Text('Search')),
                              const PopupMenuItem(value: 'starred', child: Text('Starred Messages')),
                              const PopupMenuItem(value: 'archived', child: Text('Archived')),
                              const PopupMenuItem(value: 'broadcast_lists', child: Text('Broadcast Lists')),
                              const PopupMenuItem(value: 'two_factor', child: Text('Two-Step Verification')),
                              const PopupMenuItem(value: 'linked_devices', child: Text('Linked Devices')),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Conversations/Groups List (Unified list - no tabs)
                Expanded(
                  child: FutureBuilder<List<ConversationSummary>>(
                    future: _conversationsFuture,
                    builder: (context, conversationsSnapshot) {
                      return FutureBuilder<List<GroupSummary>>(
                        future: _groupsFuture,
                        builder: (context, groupsSnapshot) {
                          if (conversationsSnapshot.connectionState == ConnectionState.waiting ||
                              groupsSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final conversations = conversationsSnapshot.data ?? [];
                          final groups = groupsSnapshot.data ?? [];
                          final allItems = <Widget>[];
                          
                          // Add conversations
                          for (final conversation in conversations) {
                            final isSelected = _selectedConversationId == conversation.id;
                            allItems.add(
                              GestureDetector(
                                onLongPress: () => _showConversationMenu(context, conversation),
                                onSecondaryTapDown: (details) {
                                  _showConversationMenuAtPosition(context, conversation, details.globalPosition);
                                },
                                child: ConversationListItem(
                                  conversation: conversation,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedConversation = conversation;
                                      _selectedConversationId = conversation.id;
                                      _selectedGroup = null;
                                      _selectedGroupId = null;
                                    });
                                  },
                                ),
                              ),
                            );
                          }
                          
                          // Add groups
                          for (final group in groups) {
                            final isSelected = _selectedGroupId == group.id;
                            allItems.add(
                              GestureDetector(
                                onLongPress: () => _showGroupMenu(context, group),
                                onSecondaryTapDown: (details) {
                                  _showGroupMenuAtPosition(context, group, details.globalPosition);
                                },
                                child: GroupListItem(
                                  group: group,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedGroup = group;
                                      _selectedGroupId = group.id;
                                      _selectedConversation = null;
                                      _selectedConversationId = null;
                                    });
                                  },
                                ),
                              ),
                            );
                          }
                          
                          if (allItems.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: isDark ? Colors.white38 : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No conversations or groups yet',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          return ListView(
                            children: allItems,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: _selectedConversation != null
                ? ChatView(
                    conversationId: _selectedConversation!.id,
                    contactName: _selectedConversation!.otherUser.name,
                    contactAvatar: _selectedConversation!.otherUser.avatarUrl,
                    otherUser: _selectedConversation!.otherUser,
                  )
                : _selectedGroup != null
                    ? GroupChatView(
                        groupId: _selectedGroup!.id,
                        groupName: _selectedGroup!.name,
                        groupAvatarUrl: _selectedGroup!.avatarUrl,
                        memberCount: _selectedGroup!.memberCount,
                      )
                    : Container(
                        color: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: isDark ? Colors.white38 : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Select a conversation to start chatting',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
