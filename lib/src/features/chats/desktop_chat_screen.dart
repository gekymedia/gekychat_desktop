import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
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
import '../broadcast/broadcast_repository.dart';
import '../two_factor/two_factor_screen.dart';
import '../linked_devices/linked_devices_screen.dart';
import '../privacy/privacy_settings_screen.dart';
import '../notifications/notification_settings_screen.dart';
import '../media_auto_download/media_auto_download_screen.dart';
import '../storage/storage_usage_screen.dart';
import '../world/world_feed_screen.dart';
import '../world/world_feed_repository.dart';
import '../mail/mail_screen.dart';
import '../qr/qr_scanner_screen.dart';
import '../../core/services/deep_link_service.dart';
import '../ai/ai_chat_screen.dart';
import '../live/live_broadcast_screen.dart';
import '../labels/labels_repository.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/feature_flags.dart';
import '../multi_account/account_switcher.dart';
import '../../widgets/side_nav.dart';
import '../../theme/app_theme.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/services/taskbar_badge_service.dart';
import '../../features/auth/auth_provider.dart';

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
  late Future<List<ConversationSummary>> _archivedConversationsFuture;
  late Future<List<GroupSummary>> _groupsFuture;
  
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _searchQuery = ''; // Store search query for filtering conversations
  Timer? _searchDebounceTimer;
  List<Label> _labels = []; // Store labels for filter chips

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _loadArchivedConversations();
    _loadGroups();
    _loadLabels();
  }
  
  void _selectConversationById(int conversationId) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conversation = await chatRepo.getConversation(conversationId);
      setState(() {
        _selectedConversation = conversation;
        _selectedConversationId = conversationId;
        _selectedGroup = null;
        _selectedGroupId = null;
      });
      // Switch to chats section
      ref.read(currentSectionProvider.notifier).setSection('/chats');
    } catch (e) {
      debugPrint('Failed to select conversation: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
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
    // Update badge after loading conversations
    _updateTaskbarBadge();
  }

  void _loadArchivedConversations() {
    final chatRepo = ref.read(chatRepositoryProvider);
    setState(() {
      _archivedConversationsFuture = chatRepo.getArchivedConversations();
    });
  }

  void _loadGroups() {
    final chatRepo = ref.read(chatRepositoryProvider);
    setState(() {
      _groupsFuture = chatRepo.getGroups();
    });
    // Update badge after loading groups
    _updateTaskbarBadge();
  }
  
  void _updateTaskbarBadge() {
    if (!mounted) return;
    Future.microtask(() async {
      if (!mounted) return;
      try {
        final badgeService = ref.read(taskbarBadgeServiceProvider);
        await badgeService.updateBadge();
      } catch (e) {
        // Silently ignore errors when widget is disposed
        if (mounted) {
          debugPrint('Failed to update taskbar badge: $e');
        }
      }
    });
  }

  void _loadLabels() async {
    try {
      final labelsRepo = ref.read(labelsRepositoryProvider);
      final labels = await labelsRepo.getLabels();
      if (mounted) {
        setState(() {
          _labels = labels;
        });
      }
    } catch (e) {
      debugPrint('Failed to load labels: $e');
      // Don't show error to user - just log it and set empty list
      if (mounted) {
        setState(() {
          _labels = [];
        });
      }
    }
  }

  void _showConversationMenuAtPosition(BuildContext context, ConversationSummary conversation, Offset position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatRepo = ref.read(chatRepositoryProvider);

    showMenu<dynamic>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx,
        MediaQuery.of(context).size.height - position.dy,
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem<dynamic>(
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
        PopupMenuItem<dynamic>(
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
        PopupMenuItem<dynamic>(
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
        PopupMenuItem<dynamic>(
          child: const Row(
            children: [
              Icon(Icons.label_outline),
              SizedBox(width: 8),
              Text('Add to Label'),
            ],
          ),
          onTap: () {
            _showAddToLabelDialog(context, conversation.id);
          },
        ),
        const PopupMenuDivider(),
        PopupMenuItem<dynamic>(
          child: const Row(
            children: [
              Icon(Icons.download),
              SizedBox(width: 8),
              Text('Export chat'),
            ],
          ),
          onTap: () {
            _exportConversation(conversation.id);
          },
        ),
        PopupMenuItem<dynamic>(
          child: const Row(
            children: [
              Icon(Icons.report, color: Colors.orange),
              SizedBox(width: 8),
              Text('Report', style: TextStyle(color: Colors.orange)),
            ],
          ),
          onTap: () {
            _showReportDialog(conversation.otherUser.id, conversation.otherUser.name);
          },
        ),
      ],
    );
  }

  Future<void> _showAddToLabelDialog(BuildContext context, int conversationId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      final labelsRepo = ref.read(labelsRepositoryProvider);
      final labels = await labelsRepo.getLabels();
      
      if (labels.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No labels available. Create one first.')),
          );
        }
        return;
      }

      final selectedLabel = await showDialog<Label>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          title: Text(
            'Add to Label',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: labels.length,
              itemBuilder: (context, index) {
                final label = labels[index];
                return ListTile(
                  leading: const Icon(Icons.label, color: Color(0xFF008069)),
                  title: Text(
                    label.name,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  onTap: () => Navigator.pop(context, label),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
            ),
          ],
        ),
      );

      if (selectedLabel != null) {
        try {
          await labelsRepo.attachLabelToConversation(selectedLabel.id, conversationId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added to ${selectedLabel.name}')),
            );
            _loadConversations();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to add to label: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load labels: $e')),
        );
      }
    }
  }

  Future<void> _showReportDialog(int userId, String userName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? selectedReason;
    final detailsController = TextEditingController();
    bool alsoBlock = false;

    final reasons = [
      'Spam',
      'Harassment',
      'Inappropriate content',
      'Fake account',
      'Scam or fraud',
      'Other',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          title: Text(
            'Report $userName',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why are you reporting this user?',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(
                      reason,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value;
                      });
                    },
                    activeColor: const Color(0xFF008069),
                  )),
                  const SizedBox(height: 16),
                  TextField(
                    controller: detailsController,
                    decoration: InputDecoration(
                      labelText: 'Additional details (optional)',
                      hintText: 'Provide more information',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: Text(
                      'Also block this user',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    value: alsoBlock,
                    onChanged: (value) {
                      setState(() {
                        alsoBlock = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF008069),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Report', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedReason != null) {
      try {
        final apiService = ref.read(apiServiceProvider);
        await apiService.reportUser(
          userId,
          selectedReason!,
          details: detailsController.text.trim().isNotEmpty ? detailsController.text.trim() : null,
          block: alsoBlock,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report submitted${alsoBlock ? " and user blocked" : ""}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to report user: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportConversation(int conversationId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/conversations/$conversationId/export');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // TODO: Implement actual file download/save for desktop
      // This would require using file_picker or similar package
      debugPrint('Export data received: ${response.data}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export chat: $e')),
        );
      }
    }
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
        PopupMenuItem<dynamic>(
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
        PopupMenuItem<dynamic>(
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
        PopupMenuItem<dynamic>(
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
        PopupMenuItem<dynamic>(
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
        PopupMenuItem<dynamic>(
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
        PopupMenuItem<dynamic>(
          child: const Row(
            children: [
              Icon(Icons.qr_code_scanner, size: 20),
              SizedBox(width: 12),
              Text('Scan QR code'),
            ],
          ),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const QRScannerScreen(),
              ),
            );
            if (result != null && context.mounted) {
              await _processQRCode(context, result as String);
            }
          },
        ),
      ],
    );
  }

  Future<void> _processQRCode(BuildContext context, String code) async {
    try {
      // Handle gekychat:// protocol links
      if (code.startsWith('gekychat://')) {
        final deepLinkService = DeepLinkService();
        final parsed = deepLinkService.parseLink(code);
        if (parsed != null && context.mounted) {
          final route = parsed['route'];
          if (route != null) {
            context.go(route);
            // Handle conversation/group/channel IDs if present
            if (parsed.containsKey('conversationId')) {
              final conversationId = int.tryParse(parsed['conversationId']!);
              if (conversationId != null) {
                ref.read(selectedConversationProvider.notifier).selectConversation(conversationId);
              }
            } else if (parsed.containsKey('groupId')) {
              // Group/channel will be selected automatically when navigating to /chats
              // The group chat view will handle it
            }
            return;
          }
        }
      }

      // Handle group invite links (https://chat.gekychat.com/groups/join/{inviteCode})
      // or (https://web.gekychat.com/groups/join/{inviteCode})
      if (code.contains('/groups/join/') || code.contains('/invite/')) {
        String? inviteCode;
        try {
          final uri = Uri.parse(code);
          final pathSegments = uri.pathSegments;
          final joinIndex = pathSegments.indexOf('join');
          final inviteIndex = pathSegments.indexOf('invite');
          
          if (joinIndex != -1 && joinIndex + 1 < pathSegments.length) {
            inviteCode = pathSegments[joinIndex + 1];
          } else if (inviteIndex != -1 && inviteIndex + 1 < pathSegments.length) {
            inviteCode = pathSegments[inviteIndex + 1];
          }
        } catch (e) {
          debugPrint('Error parsing invite link: $e');
        }

        if (inviteCode != null && inviteCode.isNotEmpty) {
          // Join group via invite code
          final apiService = ref.read(apiServiceProvider);
          try {
            final response = await apiService.post('/groups/join/$inviteCode');
            if (response.data['success'] == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response.data['message'] ?? 'Successfully joined group'),
                  backgroundColor: Colors.green,
                ),
              );
              // Refresh groups list
              _loadGroups();
              // Navigate to chats
              context.go('/chats');
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response.data['message'] ?? 'Failed to join group'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to join group: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          return;
        }
      }

      // Handle direct invite codes (just the code itself)
      if (code.length >= 8 && code.length <= 20 && code.contains(RegExp(r'^[a-zA-Z0-9]+$'))) {
        // Likely an invite code - try to join
        final apiService = ref.read(apiServiceProvider);
        try {
          final response = await apiService.post('/groups/join/$code');
          if (response.data['success'] == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.data['message'] ?? 'Successfully joined group'),
                backgroundColor: Colors.green,
              ),
            );
            _loadGroups();
            context.go('/chats');
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.data['message'] ?? 'Invalid invite code'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to join group: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }

      // Unknown QR code format
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unknown QR code format: $code'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProfileAsync = ref.watch(currentUserProvider);
    final isOnline = ref.watch(connectivityProvider);
    
    // Listen to programmatic conversation selection
    ref.listen<int?>(selectedConversationProvider, (previous, next) {
      if (next != null && next != _selectedConversationId) {
        _selectConversationById(next);
      }
    });
    
    // Listen to account changes and refresh data
    ref.listen(currentUserProvider, (previous, next) {
      final previousId = previous?.value?.id;
      final nextId = next.value?.id;
      if (previousId != null && nextId != null && previousId != nextId) {
        debugPrint('🔄 Account changed detected: User ID $previousId -> $nextId');
        debugPrint('🔄 Refreshing conversations, groups, and labels for new account...');
        _loadConversations();
        _loadArchivedConversations();
        _loadGroups();
        _loadLabels();
        debugPrint('✅ Data refresh completed for new account');
      }
    });

    // Use provider for main sections, fallback to route for external routes
    final currentSection = ref.watch(currentSectionProvider);
    final currentRoute = GoRouterState.of(context).uri.path;
    
    // Use currentSection for main sections, currentRoute for external routes
    final effectiveRoute = currentSection;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // Offline indicator banner
          if (!isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withOpacity(0.9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'You are offline. Showing saved conversations.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // Main content
          Expanded(
            child: Row(
              children: [
                // Side Nav (like web version) - Use RepaintBoundary to prevent unnecessary repaints
                RepaintBoundary(
                  child: SideNav(currentRoute: effectiveRoute),
                ),
                
                // Sidebar - Use RepaintBoundary and AutomaticKeepAliveClientMixin
                RepaintBoundary(
                  child: Container(
                    width: 400,
                    color: isDark ? const Color(0xFF111B21) : Colors.white,
                    child: _buildSidebarContent(context, effectiveRoute, isDark),
                  ),
                ),
                // Main Content Area - This is what should reload, not the sidebar
                Expanded(
                  child: _buildMainContent(context, effectiveRoute, isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context, String currentRoute, bool isDark) {
    // Show channels list when on channels route
    if (currentRoute == '/channels' || currentRoute.startsWith('/channels')) {
      return _buildChannelsSidebar(context, isDark);
    }
    
    // For other routes (world, mail, ai), show empty sidebar or hide it
    // For now, we'll show the conversations sidebar for all other routes
    return _buildConversationsSidebar(context, isDark);
  }
  
  Widget _buildChannelsSidebar(BuildContext context, bool isDark) {
    final chatRepo = ref.read(chatRepositoryProvider);
    
    return Column(
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
              const Text(
                'Channels',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.go('/create-group?type=channel'),
                tooltip: 'New channel',
              ),
            ],
          ),
        ),
        // Channels List
        Expanded(
          child: FutureBuilder<List<GroupSummary>>(
            future: chatRepo.getGroups(),
            builder: (context, snapshot) {
              // Handle errors gracefully
              if (snapshot.hasError) {
                debugPrint('Error loading groups: ${snapshot.error}');
                // Return empty list on error
                snapshot = AsyncSnapshot.withData(ConnectionState.done, <GroupSummary>[]);
              }
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final groups = snapshot.data ?? [];
              final channels = groups.where((g) => g.type == 'channel').toList();
              
              if (channels.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign,
                        size: 64,
                        color: isDark ? Colors.white38 : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No channels yet',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final isSelected = _selectedGroupId == channel.id;
                  return GestureDetector(
                    onLongPress: () => _showGroupMenu(context, channel),
                    child: GroupListItem(
                      group: channel,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedGroup = channel;
                          _selectedGroupId = channel.id;
                          _selectedConversation = null;
                          _selectedConversationId = null;
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildConversationsSidebar(BuildContext context, bool isDark) {
    final userProfileAsync = ref.watch(currentUserProvider);
    
    return Column(
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
                data: (userProfile) {
                  if (userProfile.avatarUrl == null || userProfile.avatarUrl!.isEmpty) {
                    return CircleAvatar(
                      radius: 24,
                      child: Text(userProfile.name[0].toUpperCase(), style: const TextStyle(fontSize: 20)),
                    );
                  }
                  return CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[300],
                    child: ClipOval(
                      child: Image(
                        image: CachedNetworkImageProvider(userProfile.avatarUrl!),
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              userProfile.name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
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
        // Search Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search or start new chat',
                    hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey[600]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: isDark ? Colors.white54 : Colors.grey[600]),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A3942) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    // Debounce search for world feed
                    _searchDebounceTimer?.cancel();
                    final router = GoRouter.of(context);
                    final currentRoute = router.routerDelegate.currentConfiguration.uri.path;
                    if (currentRoute == '/world' && value.isNotEmpty) {
                      _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
                        try {
                          final worldFeedRepo = ref.read(worldFeedRepositoryProvider);
                          final response = await worldFeedRepo.getFeed(page: 1, query: value);
                          // TODO: Display search results in a dialog or overlay
                          debugPrint('World feed search results: ${response['data']?.length ?? 0} posts');
                        } catch (e) {
                          debugPrint('World feed search error: $e');
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Filter button (for search filtering) - hide on world feed
              Builder(
                builder: (context) {
                  final router = GoRouter.of(context);
                  final currentRoute = router.routerDelegate.currentConfiguration.uri.path;
                  if (currentRoute == '/world') return const SizedBox.shrink();
                  return IconButton(
                    icon: Icon(Icons.filter_list, color: isDark ? Colors.white70 : Colors.grey[600]),
                    tooltip: 'Search filters',
                    onPressed: () {
                      // TODO: Show search filter options dialog
                    },
                  );
                },
              ),
            ],
          ),
        ),
        // Filter Chips (for conversation list filtering)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202C33) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                width: 1,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('unread', 'Unread', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('groups', 'Groups', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('channels', 'Channels', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('mail', 'Mail', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('archived', 'Archived', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('broadcast', 'Broadcast', isDark),
                // Show labels as filter chips
                ..._labels.map((label) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildFilterChip('label-${label.id}', label.name, isDark),
                  );
                }),
                const SizedBox(width: 8),
                // Add new label button
                FilterChip(
                  label: const Icon(Icons.add, size: 16),
                  selected: false,
                  onSelected: (selected) {
                    _showCreateLabelDialog(context, isDark);
                  },
                  backgroundColor: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
                  side: BorderSide(
                    color: isDark ? const Color(0xFF2A3942) : Colors.grey[300]!,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Conversations/Groups List (Unified list - no tabs)
        Expanded(
          child: FutureBuilder<List<ConversationSummary>>(
            future: _selectedFilter == 'archived' ? _archivedConversationsFuture : _conversationsFuture,
            builder: (context, conversationsSnapshot) {
              // Handle errors gracefully
              if (conversationsSnapshot.hasError) {
                debugPrint('Error loading conversations: ${conversationsSnapshot.error}');
                // Return empty list on error
                conversationsSnapshot = AsyncSnapshot.withData(ConnectionState.done, <ConversationSummary>[]);
              }
              
              return FutureBuilder<List<GroupSummary>>(
                future: _groupsFuture,
                builder: (context, groupsSnapshot) {
                  // Handle errors gracefully
                  if (groupsSnapshot.hasError) {
                    debugPrint('Error loading groups: ${groupsSnapshot.error}');
                    // Return empty list on error
                    groupsSnapshot = AsyncSnapshot.withData(ConnectionState.done, <GroupSummary>[]);
                  }
                  
                  if (conversationsSnapshot.connectionState == ConnectionState.waiting ||
                      groupsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // Get base data
                  List<ConversationSummary> allConversations = conversationsSnapshot.data ?? [];
                  List<GroupSummary> allGroups = groupsSnapshot.data ?? [];
                  
                  // Apply filters
                  List<ConversationSummary> filteredConversations = [];
                  List<GroupSummary> filteredGroups = [];
                  
                  // Apply search query filter first
                  List<ConversationSummary> searchFilteredConversations = allConversations;
                  List<GroupSummary> searchFilteredGroups = allGroups;
                  
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    searchFilteredConversations = allConversations.where((c) {
                      final name = c.otherUser.name.toLowerCase();
                      final phone = c.otherUser.phone?.toLowerCase() ?? '';
                      final lastMessage = (c.lastMessage ?? '').toLowerCase();
                      return name.contains(query) || phone.contains(query) || lastMessage.contains(query);
                    }).toList();
                    searchFilteredGroups = allGroups.where((g) {
                      final name = g.name.toLowerCase();
                      final lastMessage = (g.lastMessage ?? '').toLowerCase();
                      return name.contains(query) || lastMessage.contains(query);
                    }).toList();
                  }
                  
                  if (_selectedFilter == 'all') {
                    // Show all conversations (excluding archived) and all groups (excluding channels)
                    filteredConversations = searchFilteredConversations.where((c) => c.archivedAt == null).toList();
                    filteredGroups = searchFilteredGroups.where((g) => g.type != 'channel').toList();
                  } else if (_selectedFilter == 'unread') {
                    // Show unread conversations and groups
                    filteredConversations = searchFilteredConversations
                        .where((c) => c.unreadCount > 0 && c.archivedAt == null)
                        .toList();
                    filteredGroups = searchFilteredGroups
                        .where((g) => g.unreadCount > 0 && g.type != 'channel')
                        .toList();
                  } else if (_selectedFilter == 'groups') {
                    // Show only groups (not channels, not conversations)
                    filteredConversations = [];
                    filteredGroups = searchFilteredGroups.where((g) => g.type != 'channel').toList();
                  } else if (_selectedFilter == 'channels') {
                    // Show only channels (not regular groups, not conversations)
                    filteredConversations = [];
                    filteredGroups = searchFilteredGroups.where((g) => g.type == 'channel').toList();
                  } else if (_selectedFilter == 'archived') {
                    // Show only archived conversations (already filtered by future)
                    filteredConversations = searchFilteredConversations; // Already filtered by _archivedConversationsFuture
                    filteredGroups = []; // Don't show groups in archived
                  } else if (_selectedFilter == 'mail') {
                    // Mail filter - placeholder for now
                    filteredConversations = [];
                    filteredGroups = [];
                  } else if (_selectedFilter == 'broadcast') {
                    // Broadcast filter - show broadcast lists screen
                    return const BroadcastListsScreen();
                  } else if (_selectedFilter.startsWith('label-')) {
                    // Filter by label
                    final labelIdStr = _selectedFilter.replaceFirst('label-', '');
                    final labelId = int.tryParse(labelIdStr);
                    if (labelId != null) {
                      filteredConversations = searchFilteredConversations
                          .where((c) => c.archivedAt == null && c.labelIds.contains(labelId))
                          .toList();
                      filteredGroups = []; // Labels don't apply to groups
                    } else {
                      filteredConversations = [];
                      filteredGroups = [];
                    }
                  }
                  
                  final conversations = filteredConversations;
                  final groups = filteredGroups;
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
                            // Switch to chats tab if not already there
                            final currentSection = ref.read(currentSectionProvider);
                            if (currentSection != '/chats') {
                              ref.read(currentSectionProvider.notifier).setSection('/chats');
                            }
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
                  
                  // Add groups/channels based on filter
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
                    String emptyMessage;
                    IconData emptyIcon;
                    
                    switch (_selectedFilter) {
                      case 'archived':
                        emptyMessage = 'No archived conversations';
                        emptyIcon = Icons.archive_outlined;
                        break;
                      case 'groups':
                        emptyMessage = 'No groups yet';
                        emptyIcon = Icons.group_outlined;
                        break;
                      case 'channels':
                        emptyMessage = 'No channels yet';
                        emptyIcon = Icons.campaign_outlined;
                        break;
                      case 'unread':
                        emptyMessage = 'No unread messages';
                        emptyIcon = Icons.mark_email_read_outlined;
                        break;
                      case 'mail':
                        emptyMessage = 'No mail conversations';
                        emptyIcon = Icons.mail_outline;
                        break;
                      default:
                        emptyMessage = 'No conversations or groups yet';
                        emptyIcon = Icons.chat_bubble_outline;
                    }
                    
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/gold_no_text/128x128.png',
                            width: 128,
                            height: 128,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to icon if image fails to load
                              return Icon(
                                emptyIcon,
                                size: 64,
                                color: isDark ? Colors.white38 : Colors.grey[400],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            emptyMessage,
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
    );
  }

  Future<void> _showCreateLabelDialog(BuildContext context, bool isDark) async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          'Create Label',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            labelText: 'Label Name',
            hintText: 'e.g., "Work", "Family"',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
            border: const OutlineInputBorder(),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF008069)),
            ),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            child: const Text('Create', style: TextStyle(color: Color(0xFF008069), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final labelsRepo = ref.read(labelsRepositoryProvider);
        await labelsRepo.createLabel(result);
        _loadLabels(); // Reload labels to show in filter chips
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Label created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create label: $e')),
          );
        }
      }
    }
  }
  
  Widget _buildFilterChip(String filter, String label, bool isDark) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      selectedColor: const Color(0xFF008069).withOpacity(0.2),
      checkmarkColor: const Color(0xFF008069),
      labelStyle: TextStyle(
        color: isSelected
            ? const Color(0xFF008069)
            : (isDark ? Colors.white70 : Colors.grey[700]),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF008069)
            : (isDark ? const Color(0xFF2A3942) : Colors.grey[300]!),
      ),
    );
  }
  
  Widget _buildMainContent(BuildContext context, String currentRoute, bool isDark) {
    // Handle channels route
    if (currentRoute == '/channels' || currentRoute.startsWith('/channels')) {
      if (_selectedGroup != null) {
        return GroupChatView(
          groupId: _selectedGroup!.id,
          groupName: _selectedGroup!.name,
          groupAvatarUrl: _selectedGroup!.avatarUrl,
          memberCount: _selectedGroup!.memberCount,
        );
      }
      return Container(
        color: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.campaign,
                size: 64,
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Select a channel to view',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Handle other routes (world, mail, ai, calls, live-broadcast) - show their content
    if (currentRoute == '/world') {
      return const WorldFeedScreen();
    }
    if (currentRoute == '/mail') {
      return const MailScreen();
    }
    if (currentRoute == '/ai') {
      return const AiChatScreen();
    }
    if (currentRoute == '/calls') {
      return const CallsScreen();
    }
    if (currentRoute == '/status') {
      return const StatusListScreen();
    }
    if (currentRoute == '/live-broadcast' || currentRoute.startsWith('/live')) {
      return const LiveBroadcastScreen();
    }
    
    // Handle settings route
    if (currentRoute == '/settings') {
      return const SettingsScreen();
    }
    
    // Default: show conversations/group chats
    if (_selectedConversation != null) {
      return ChatView(
        conversationId: _selectedConversation!.id,
        contactName: _selectedConversation!.otherUser.name,
        contactAvatar: _selectedConversation!.otherUser.avatarUrl,
        otherUser: _selectedConversation!.otherUser,
      );
    }
    
    if (_selectedGroup != null) {
      return GroupChatView(
        groupId: _selectedGroup!.id,
        groupName: _selectedGroup!.name,
        groupAvatarUrl: _selectedGroup!.avatarUrl,
        memberCount: _selectedGroup!.memberCount,
      );
    }
    
    // Empty state
    return Container(
      color: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/gold_no_text/128x128.png',
              width: 128,
              height: 128,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to icon if image fails to load
                return Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                );
              },
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
    );
  }
}
