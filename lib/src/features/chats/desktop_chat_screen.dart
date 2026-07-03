import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/settings_screen.dart';
import '../profile/profile_edit_screen.dart';
import '../contacts/contacts_screen.dart';
import '../contacts/contact_display_service.dart';
import '../search/search_repository.dart';
import '../search/desktop_sidebar_search_results.dart';
import '../status/status_list_screen.dart';
import '../status/create_status_screen.dart';
import 'create_group_screen.dart';
import 'models.dart';
import 'chat_repo.dart';
import 'chat_providers.dart';
import 'sidebar_inbox_bump.dart';
import 'widgets/conversation_list_item.dart';
import 'widgets/group_list_item.dart';
import 'providers/typing_status_provider.dart';
import 'providers/group_typing_status_provider.dart';
import 'widgets/chat_view.dart';
import 'widgets/group_chat_view.dart';
import '../calls/calls_screen.dart';
import '../channels/channels_screen.dart';
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
import '../notices/in_app_notice.dart';
import '../notices/in_app_notice_repository.dart';
import '../notices/in_app_notice_strip.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/feature_flags.dart';
import '../multi_account/account_switcher_screen.dart';
import '../../widgets/side_nav.dart';
import '../../theme/app_theme.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/services/taskbar_badge_service.dart';
import '../../features/auth/auth_provider.dart';
import '../calls/incoming_call_handler.dart';
import '../../services/inbox_realtime_sync.dart';
import '../../widgets/skeleton_loader.dart';
import '../../core/global_navigator_key.dart';

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
  int? _groupInitialScrollMessageId;
  int? _conversationInitialScrollMessageId;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedFilter = 'all';
  String _searchQuery = '';
  Map<String, dynamic>? _searchResults;
  bool _isSearching = false;
  List<String>? _searchFilters;
  Timer? _searchDebounceTimer;
  List<Label> _labels = []; // Store labels for filter chips
  List<InAppNotice> _inAppNotices = [];
  Set<int> _manualUnreadConversationIds = <int>{};
  Set<int> _manualUnreadGroupIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Prefetch data by watching providers (they cache automatically)
    ref.read(optimizedConversationsProvider.future);
    ref.read(optimizedGroupsProvider.future);
    ref.read(optimizedArchivedConversationsProvider.future);
    _loadLabels();
    _loadInAppNotices();
    _loadManualUnreadMarkers();
    // Warm up contact display names after first frame (avoid provider churn during build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(contactDisplayServiceProvider).warmUp();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(incomingCallHandlerProvider).setContext(context);
      _restoreSelectionFromProviders();
    });
  }

  /// After route changes (e.g. /settings → /chats) GoRouter recreates this widget;
  /// restore the open chat from Riverpod so the sidebar tap still opens the thread.
  void _restoreSelectionFromProviders() {
    if (!mounted) return;
    final convId = ref.read(selectedConversationProvider);
    final groupId = ref.read(selectedGroupIdProvider);
    if (convId != null && _selectedConversationId != convId) {
      _selectConversationById(convId);
    } else if (groupId != null && _selectedGroupId != groupId) {
      _selectGroupById(groupId);
    }
  }

  Future<void> _selectGroupById(int groupId, {int? scrollToMessageId}) async {
    try {
      GroupSummary? found;
      for (final g in ref.read(sidebarPendingGroupsProvider)) {
        if (g.id == groupId) {
          found = g;
          break;
        }
      }
      if (found == null) {
        final groups = await ref.read(optimizedGroupsProvider.future);
        for (final g in groups) {
          if (g.id == groupId) {
            found = g;
            break;
          }
        }
      }
      if (!mounted || found == null) return;
      await _popChatOverlayRoutes();
      if (!mounted) return;
      setState(() {
        _selectedConversation = null;
        _selectedConversationId = null;
        _selectedGroup = found;
        _selectedGroupId = groupId;
        _groupInitialScrollMessageId = scrollToMessageId;
        _conversationInitialScrollMessageId = null;
      });
      ref.read(selectedGroupIdProvider.notifier).state = groupId;
      ref.read(selectedConversationProvider.notifier).clearSelection();
      _switchToChatsView();
    } catch (e) {
      debugPrint('Failed to select group: $e');
    }
  }
  
  Future<void> _popChatOverlayRoutes() async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    var safety = 0;
    while (navigator.canPop() && safety < 8) {
      safety++;
      final popped = await navigator.maybePop();
      if (popped != true) break;
    }
  }

  Future<void> _popOverlaysThen(VoidCallback fn) async {
    await _popChatOverlayRoutes();
    if (!mounted) return;
    fn();
  }

  /// Returns to the chats pane when World, Status, Settings, etc. is open.
  void _switchToChatsView() {
    ref.read(currentSectionProvider.notifier).setSection('/chats');
    final path = GoRouterState.of(context).uri.path;
    if (path != '/chats') {
      context.go('/chats');
    }
  }

  void _deferIfMounted(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  Future<void> _selectConversationById(
    int conversationId, {
    int? scrollToMessageId,
  }) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conversation = await chatRepo.getConversation(conversationId);
      if (!mounted) return;
      await _popChatOverlayRoutes();
      if (!mounted) return;
      setState(() {
        _selectedConversation = conversation;
        _selectedConversationId = conversationId;
        _selectedGroup = null;
        _selectedGroupId = null;
        _groupInitialScrollMessageId = null;
        _conversationInitialScrollMessageId = scrollToMessageId;
      });
      ref.read(selectedGroupIdProvider.notifier).state = null;
      _switchToChatsView();
    } catch (e) {
      debugPrint('Failed to select conversation: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _performSidebarSearch() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isSearching = true);
    }

    try {
      final searchRepo = ref.read(searchRepositoryProvider);
      final results = await searchRepo.search(
        query: query,
        filters: _searchFilters?.isNotEmpty == true ? _searchFilters : null,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Sidebar search error: $e');
      if (!mounted) return;
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  Future<void> _selectConversationFromSearch(
    int conversationId, {
    int? messageId,
  }) async {
    _clearSidebarSearch();
    ref.read(selectedConversationProvider.notifier).selectConversation(conversationId);
    await _selectConversationById(conversationId, scrollToMessageId: messageId);
  }

  Future<void> _selectGroupFromSearch(
    int groupId, {
    int? messageId,
  }) async {
    _clearSidebarSearch();
    await _selectGroupById(groupId, scrollToMessageId: messageId);
  }

  void _clearSidebarSearch() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = null;
      _isSearching = false;
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(optimizedConversationsProvider);
      ref.invalidate(optimizedGroupsProvider);
      ref.invalidate(optimizedArchivedConversationsProvider);
      unawaited(ref.read(pusherServiceProvider).resetReconnectPolicyAndConnect());
      unawaited(ref.read(inboxRealtimeSyncProvider).initialize(force: true));
      _updateTaskbarBadge();
      _loadInAppNotices();
    }
  }

  void _refreshConversations() {
    // Invalidate to refresh - shows cached data immediately, then updates
    ref.invalidate(optimizedConversationsProvider);
    _updateTaskbarBadge();
  }

  void _refreshArchivedConversations() {
    ref.invalidate(optimizedArchivedConversationsProvider);
  }

  void _refreshGroups() {
    ref.invalidate(optimizedGroupsProvider);
    _updateTaskbarBadge();
  }

  bool _isManuallyUnreadConversation(int conversationId) {
    return _manualUnreadConversationIds.contains(conversationId);
  }

  bool _isManuallyUnreadGroup(int groupId) {
    return _manualUnreadGroupIds.contains(groupId);
  }

  Future<void> _loadManualUnreadMarkers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final convIds =
          prefs.getStringList('manual_unread_conversation_ids') ?? const [];
      final groupIds =
          prefs.getStringList('manual_unread_group_ids') ?? const [];
      if (!mounted) return;
      setState(() {
        _manualUnreadConversationIds = convIds
            .map(int.tryParse)
            .whereType<int>()
            .toSet();
        _manualUnreadGroupIds =
            groupIds.map(int.tryParse).whereType<int>().toSet();
      });
    } catch (_) {}
  }

  Future<void> _persistManualUnreadMarkers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'manual_unread_conversation_ids',
        _manualUnreadConversationIds.map((e) => e.toString()).toList(),
      );
      await prefs.setStringList(
        'manual_unread_group_ids',
        _manualUnreadGroupIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  Future<void> _setConversationManualUnread(
    int conversationId, {
    required bool value,
  }) async {
    if (value) {
      _manualUnreadConversationIds.add(conversationId);
    } else {
      _manualUnreadConversationIds.remove(conversationId);
    }
    if (mounted) setState(() {});
    await _persistManualUnreadMarkers();
  }

  Future<void> _setGroupManualUnread(int groupId, {required bool value}) async {
    if (value) {
      _manualUnreadGroupIds.add(groupId);
    } else {
      _manualUnreadGroupIds.remove(groupId);
    }
    if (mounted) setState(() {});
    await _persistManualUnreadMarkers();
  }

  void _onFilterChipSelected(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    if (filter == 'archived') {
      _refreshArchivedConversations();
    }
  }

  String _emptyFilterMessage() {
    switch (_selectedFilter) {
      case 'unread':
        return 'No unread conversations';
      case 'groups':
        return 'No groups';
      case 'channels':
        return 'No channels';
      case 'archived':
        return 'No archived conversations';
      case 'broadcast':
        return 'No broadcast lists';
      default:
        if (_selectedFilter.startsWith('label-')) {
          return 'No conversations match this filter';
        }
        return _searchQuery.isNotEmpty
            ? 'No results found'
            : 'No conversations yet';
    }
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
  
  Widget _buildConversationList(List<ConversationSummary> conversations, List<GroupSummary> groups) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter conversations and groups based on selected filter and search query
    List<ConversationSummary> filteredConversations = [];
    List<GroupSummary> filteredGroups = [];
    
    // Apply search filter
    List<ConversationSummary> searchFilteredConversations = conversations;
    List<GroupSummary> searchFilteredGroups = groups;
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      searchFilteredConversations = conversations.where((c) {
        final name = c.otherUser.name.toLowerCase();
        final phone = c.otherUser.phone?.toLowerCase() ?? '';
        final lastMessage = (c.lastMessage ?? '').toLowerCase();
        return name.contains(query) || phone.contains(query) || lastMessage.contains(query);
      }).toList();
      
      searchFilteredGroups = groups.where((g) {
        final name = g.name.toLowerCase();
        final lastMessage = (g.lastMessage ?? '').toLowerCase();
        return name.contains(query) || lastMessage.contains(query);
      }).toList();
    }
    
    // Apply selected filter
    if (_selectedFilter == 'all') {
      filteredConversations = searchFilteredConversations.where((c) => c.archivedAt == null).toList();
      filteredGroups = searchFilteredGroups.where((g) => g.type != 'channel').toList();
    } else if (_selectedFilter == 'unread') {
      filteredConversations = searchFilteredConversations
          .where(
            (c) =>
                c.archivedAt == null &&
                (c.unreadCount > 0 || _isManuallyUnreadConversation(c.id)),
          )
          .toList();
      filteredGroups = searchFilteredGroups
          .where(
            (g) =>
                g.type != 'channel' &&
                (g.unreadCount > 0 || _isManuallyUnreadGroup(g.id)),
          )
          .toList();
    } else if (_selectedFilter == 'groups') {
      filteredConversations = [];
      filteredGroups = searchFilteredGroups.where((g) => g.type != 'channel').toList();
    } else if (_selectedFilter == 'channels') {
      filteredConversations = [];
      filteredGroups = searchFilteredGroups.where((g) => g.type == 'channel').toList();
    } else if (_selectedFilter == 'archived') {
      filteredConversations = searchFilteredConversations.where((c) => c.archivedAt != null).toList();
      filteredGroups = [];
    } else if (_selectedFilter.startsWith('label-')) {
      final labelIdStr = _selectedFilter.replaceFirst('label-', '');
      final labelId = int.tryParse(labelIdStr);
      if (labelId != null) {
        filteredConversations = searchFilteredConversations
            .where((c) => c.archivedAt == null && c.labelIds.contains(labelId))
            .toList();
        filteredGroups = searchFilteredGroups
            .where((g) => g.type != 'channel' && g.labelIds.contains(labelId))
            .toList();
      }
    }
    
    // Combine and sort: pinned first, then by updatedAt
    final allItems = <dynamic>[...filteredConversations, ...filteredGroups];
    allItems.sort((a, b) {
      final aPinned = a is ConversationSummary
          ? a.isPinned
          : (a is GroupSummary ? a.isPinned : false);
      final bPinned = b is ConversationSummary
          ? b.isPinned
          : (b is GroupSummary ? b.isPinned : false);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      final aTime = a is ConversationSummary
          ? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)
          : (a is GroupSummary ? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0));
      final bTime = b is ConversationSummary
          ? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)
          : (b is GroupSummary ? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0));
      return bTime.compareTo(aTime);
    });
    
    if (allItems.isEmpty) {
      return Center(
        child: Text(
          _emptyFilterMessage(),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        if (item is ConversationSummary) {
          final isSelected = _selectedConversationId == item.id;
          return GestureDetector(
            onLongPress: () => _showConversationMenu(context, item),
            child: ConversationListItem(
              conversation: item,
              isSelected: isSelected,
              forceUnreadBadge: _isManuallyUnreadConversation(item.id),
              onTap: () async {
                await _setConversationManualUnread(item.id, value: false);
                if (!mounted) return;
                await _popChatOverlayRoutes();
                if (!mounted) return;
                ref.read(selectedGroupIdProvider.notifier).state = null;
                ref
                    .read(selectedConversationProvider.notifier)
                    .selectConversation(item.id);
                setState(() {
                  _selectedConversation = item;
                  _selectedConversationId = item.id;
                  _selectedGroup = null;
                  _selectedGroupId = null;
                  _groupInitialScrollMessageId = null;
                });
                _switchToChatsView();
              },
            ),
          );
        } else if (item is GroupSummary) {
          final isSelected = _selectedGroupId == item.id;
          return GestureDetector(
            onLongPress: () => _showGroupMenu(context, item),
            child: GroupListItem(
              group: item,
              isSelected: isSelected,
              forceUnreadBadge: _isManuallyUnreadGroup(item.id),
              onTap: () async {
                await _setGroupManualUnread(item.id, value: false);
                if (!mounted) return;
                await _popChatOverlayRoutes();
                if (!mounted) return;
                ref.read(selectedGroupIdProvider.notifier).state = item.id;
                ref.read(selectedConversationProvider.notifier).clearSelection();
                setState(() {
                  _selectedGroup = item;
                  _selectedGroupId = item.id;
                  _selectedConversation = null;
                  _selectedConversationId = null;
                  _groupInitialScrollMessageId = null;
                });
                _switchToChatsView();
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
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

  Future<void> _loadInAppNotices() async {
    try {
      final repo = ref.read(inAppNoticeRepositoryProvider);
      final list = await repo.fetchVisible();
      if (mounted) setState(() => _inAppNotices = list);
    } catch (e) {
      debugPrint('In-app notices load skipped: $e');
    }
  }

  Future<void> _dismissInAppNotice(String noticeKey) async {
    try {
      final repo = ref.read(inAppNoticeRepositoryProvider);
      await repo.dismiss(noticeKey);
      if (mounted) {
        setState(() {
          _inAppNotices = _inAppNotices.where((n) => n.noticeKey != noticeKey).toList();
        });
      }
    } catch (e) {
      debugPrint('Dismiss in-app notice: $e');
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
              _refreshConversations();
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
              _refreshConversations();
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
              await _setConversationManualUnread(conversation.id, value: true);
              _refreshConversations();
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
            _refreshConversations();
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
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exporting chat...')),
        );
      }
      
      // Get export data
      final response = await apiService.get('/conversations/$conversationId/export');
      
      // Get download directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      
      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'gekychat_export_${conversationId}_$timestamp.txt';
      final savePath = '${downloadDir.path}/$fileName';
      
      // Save export data to file
      final file = File(savePath);
      await file.writeAsString(response.data.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat exported to Downloads/$fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
              _refreshGroups();
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
              _refreshGroups();
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
              await chatRepo.markGroupUnread(group.id);
              await _setGroupManualUnread(group.id, value: true);
              _refreshGroups();
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
              _refreshGroups();
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
            _refreshGroups();
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

    ref.listen<GroupSummary?>(pendingDesktopGroupOpenProvider, (previous, next) {
      if (next == null) return;
      _deferIfMounted(() {
        unawaited(_popOverlaysThen(() {
          ref.read(pendingDesktopGroupOpenProvider.notifier).state = null;
          setState(() {
            _selectedConversation = null;
            _selectedConversationId = null;
            _selectedGroup = next;
            _selectedGroupId = next.id;
          });
          ref.read(selectedGroupIdProvider.notifier).state = next.id;
          ref.read(selectedConversationProvider.notifier).clearSelection();
          _switchToChatsView();
        }));
      });
    });

    ref.listen<int?>(pendingDesktopGroupSelectProvider, (previous, next) async {
      if (next == null) return;
      ref.read(pendingDesktopGroupSelectProvider.notifier).state = null;
      GroupSummary? found;
      for (final g in ref.read(sidebarPendingGroupsProvider)) {
        if (g.id == next) {
          found = g;
          break;
        }
      }
      try {
        if (found == null) {
          final groups = await ref.read(optimizedGroupsProvider.future);
          for (final g in groups) {
            if (g.id == next) {
              found = g;
              break;
            }
          }
        }
        if (!mounted) return;
        if (found != null) {
          final group = found;
          await _popChatOverlayRoutes();
          if (!mounted) return;
          setState(() {
            _selectedConversation = null;
            _selectedConversationId = null;
            _selectedGroup = group;
            _selectedGroupId = group.id;
          });
          ref.read(selectedGroupIdProvider.notifier).state = group.id;
          ref.read(selectedConversationProvider.notifier).clearSelection();
          _switchToChatsView();
        }
      } catch (_) {}
    });

    ref.listen<AsyncValue<List<GroupSummary>>>(optimizedGroupsProvider, (previous, next) {
      next.whenData((groups) {
        final pending = ref.read(sidebarPendingGroupsProvider);
        if (pending.isEmpty) return;
        final syncedIds = groups.map((g) => g.id).toSet();
        final remaining =
            pending.where((g) => !syncedIds.contains(g.id)).toList();
        if (remaining.length != pending.length) {
          ref.read(sidebarPendingGroupsProvider.notifier).state = remaining;
        }
      });
    });

    ref.listen<DesktopPendingStatusChatOpen?>(
        pendingDesktopStatusChatOpenProvider, (previous, next) {
      if (next != null) {
        _selectConversationById(next.conversationId);
      }
    });

    ref.listen<DesktopPendingGroupPrivateOpen?>(
        pendingDesktopGroupPrivateOpenProvider, (previous, next) {
      if (next != null) {
        _selectConversationById(next.conversationId);
      }
    });

    ref.listen<AsyncValue<List<ConversationSummary>>>(
        optimizedConversationsProvider, (previous, next) {
      next.whenData((conversations) {
        final ids = conversations.map((c) => c.id).toList();
        ref.read(typingStatusProvider.notifier).subscribeToConversations(ids);
        ref.read(recordingStatusProvider.notifier).subscribeToConversations(ids);
      });
    });

    ref.listen<AsyncValue<List<GroupSummary>>>(optimizedGroupsProvider,
        (previous, next) {
      next.whenData((groups) {
        final ids = groups.map((g) => g.id).toList();
        ref.read(groupTypingStatusProvider.notifier).subscribeToGroups(ids);
        ref.read(groupRecordingStatusProvider.notifier).subscribeToGroups(ids);
      });
    });

    ref.listen<DesktopGroupDeepLink?>(
        pendingDesktopGroupDeepLinkProvider, (previous, next) async {
      if (next == null) return;
      final link = next;
      ref.read(pendingDesktopGroupDeepLinkProvider.notifier).state = null;
      try {
        final groups = await ref.read(optimizedGroupsProvider.future);
        GroupSummary? found;
        for (final g in groups) {
          if (g.id == link.groupId) {
            found = g;
            break;
          }
        }
        if (!mounted) return;
        final group = found;
        if (group != null) {
          _deferIfMounted(() {
            unawaited(_popOverlaysThen(() {
              setState(() {
                _selectedConversation = null;
                _selectedConversationId = null;
                _selectedGroup = group;
                _selectedGroupId = group.id;
                _groupInitialScrollMessageId = link.messageId;
              });
              ref.read(selectedGroupIdProvider.notifier).state = group.id;
              ref.read(selectedConversationProvider.notifier).clearSelection();
              _switchToChatsView();
            }));
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group not found in your list.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open group: $e')),
          );
        }
      }
    });
    
    // Listen to account changes and refresh data
    ref.listen(currentUserProvider, (previous, next) {
      final previousId = previous?.valueOrNull?.id;
      final nextId = next.valueOrNull?.id;
      if (previousId != null && nextId != null && previousId != nextId) {
        debugPrint('🔄 Account changed detected: User ID $previousId -> $nextId');
        debugPrint('🔄 Refreshing conversations, groups, and labels for new account...');
        _refreshConversations();
        _refreshArchivedConversations();
        _refreshGroups();
        _loadLabels();
        debugPrint('✅ Data refresh completed for new account');
      }
    });

    // Use provider for main sections, fallback to route for external routes
    final currentSection = ref.watch(currentSectionProvider);
    final currentRoute = GoRouterState.of(context).uri.path;
    
    // Use currentSection for main sections, currentRoute for external routes like /settings
    // Main sections use provider state, but settings and other external routes use actual router state
    final isSettingsRoute =
        currentRoute == '/settings' || currentRoute.startsWith('/settings');
    // Shell stays on /chats; sidenav + main pane use [currentSectionProvider].
    final effectiveRoute =
        isSettingsRoute ? currentRoute : currentSection;
    
    debugPrint('🔧 [ROUTE] currentRoute: $currentRoute, currentSection: $currentSection, effectiveRoute: $effectiveRoute');

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
                return const SkeletonList(
                  skeletonItem: SkeletonConversationItem(),
                  itemCount: 6,
                );
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
                          _groupInitialScrollMessageId = null;
                        });
                        ref.read(selectedGroupIdProvider.notifier).state = channel.id;
                        ref.read(selectedConversationProvider.notifier).clearSelection();
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
                      userProfileAsync.valueOrNull?.name ?? 'User',
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
              // Account Switcher (opens account switcher screen)
              IconButton(
                icon: Icon(Icons.account_circle_outlined, color: isDark ? Colors.white70 : Colors.grey[600]),
                tooltip: 'Switch account',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AccountSwitcherScreen(),
                    ),
                  );
                },
              ),
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
                          _switchToChatsView();
                          _searchFocusNode.requestFocus();
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
                  focusNode: _searchFocusNode,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search or start new chat',
                    hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey[600]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: isDark ? Colors.white54 : Colors.grey[600]),
                            onPressed: _clearSidebarSearch,
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
                      if (value.trim().isEmpty) {
                        _searchResults = null;
                        _isSearching = false;
                      } else {
                        _isSearching = true;
                      }
                    });
                    _searchDebounceTimer?.cancel();
                    final router = GoRouter.of(context);
                    final currentRoute = router.routerDelegate.currentConfiguration.uri.path;
                    if (value.trim().isEmpty) return;
                    if (currentRoute == '/world') {
                      _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
                        try {
                          final worldFeedRepo = ref.read(worldFeedRepositoryProvider);
                          final response = await worldFeedRepo.getFeed(page: 1, query: value);
                          debugPrint('World feed search results: ${response['data']?.length ?? 0} posts');
                        } catch (e) {
                          debugPrint('World feed search error: $e');
                        }
                      });
                    } else {
                      _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
                        _performSidebarSearch();
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
                      _showSearchFilterDialog(context, ref);
                    },
                  );
                },
              ),
            ],
          ),
        ),
        if (_inAppNotices.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            color: isDark ? const Color(0xFF202C33) : Colors.white,
            child: InAppNoticeStrip(
              notices: _inAppNotices,
              onDismiss: _dismissInAppNotice,
            ),
          ),
        if (_searchQuery.trim().isEmpty)
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
                  _buildFilterChip('archived', 'Archived', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('broadcast', 'Broadcast', isDark),
                  ..._labels.map((label) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildFilterChip('label-${label.id}', label.name, isDark),
                    );
                  }),
                  const SizedBox(width: 8),
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
        Expanded(
          child: _searchQuery.trim().isNotEmpty
              ? DesktopSidebarSearchResults(
                  query: _searchQuery.trim(),
                  results: _searchResults,
                  isSearching: _isSearching,
                  onSelectConversation: _selectConversationFromSearch,
                  onSelectGroup: _selectGroupFromSearch,
                )
              : _selectedFilter == 'broadcast'
              ? const EmbeddableBroadcastListsScreen()
              : Consumer(
            builder: (context, ref, child) {
              // Use providers instead of FutureBuilder - shows cached data immediately
              final conversationsAsync = _selectedFilter == 'archived'
                  ? ref.watch(optimizedArchivedConversationsProvider)
                  : ref.watch(sidebarConversationsProvider);
              
              final groupsAsync = ref.watch(sidebarGroupsProvider);
              
              return conversationsAsync.when(
                data: (allConversations) {
                  return groupsAsync.when(
                    data: (allGroups) {
                      // Show data immediately - Telegram-style smooth experience
                      return _buildConversationList(allConversations, allGroups);
                    },
                    loading: () {
                      // Show conversations while groups are loading (stale-while-revalidate)
                      return _buildConversationList(allConversations, []);
                    },
                    error: (error, stack) {
                      debugPrint('Error loading groups: $error');
                      // Show conversations even if groups fail
                      return _buildConversationList(allConversations, []);
                    },
                  );
                },
                loading: () {
                  // First load - show skeleton loaders
                  return groupsAsync.when(
                    data: (allGroups) => _buildConversationList([], allGroups),
                    loading: () => const SkeletonList(
                      skeletonItem: SkeletonConversationItem(),
                      itemCount: 8,
                    ),
                    error: (_, __) => _buildConversationList([], []),
                  );
                },
                error: (error, stack) {
                  debugPrint('Error loading conversations: $error');
                  // Try to show groups even if conversations fail
                  return groupsAsync.when(
                    data: (allGroups) => _buildConversationList([], allGroups),
                    loading: () => const Center(child: Text('Error loading conversations')),
                    error: (_, __) => const Center(child: Text('Error loading data')),
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
    
    // Calculate unread count for unread filter using providers
    if (filter == 'unread') {
      final conversationsAsync = ref.watch(sidebarConversationsProvider);
      final groupsAsync = ref.watch(sidebarGroupsProvider);
      
      return Consumer(
        builder: (context, ref, child) {
          int? unreadCount;
          conversationsAsync.whenData((conversations) {
            groupsAsync.whenData((groups) {
              unreadCount = conversations
                  .where((c) => c.unreadCount > 0 && c.archivedAt == null)
                  .fold<int>(0, (sum, c) => sum + c.unreadCount) +
                  groups
                      .where((g) => g.unreadCount > 0 && g.type != 'channel')
                      .fold<int>(0, (sum, g) => sum + g.unreadCount);
            });
          });
          return _buildFilterChipWidget(filter, label, isDark, isSelected, unreadCount);
        },
      );
    }
    
    return _buildFilterChipWidget(filter, label, isDark, isSelected, null);
  }
  
  Widget _buildFilterChipWidget(String filter, String label, bool isDark, bool isSelected, int? unreadCount) {
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (unreadCount != null && unreadCount > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF008069)
                    : (isDark ? Colors.white24 : Colors.grey[400]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) => _onFilterChipSelected(filter),
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
    // Open chat always wins over World, Settings, etc. (sidebar tap while browsing).
    if (_selectedConversation != null) {
      return ChatView(
        key: ValueKey('conv-${_selectedConversation!.id}'),
        conversationId: _selectedConversation!.id,
        contactName: _selectedConversation!.isSavedMessages
            ? 'Saved Messages'
            : _selectedConversation!.otherUser.name,
        contactAvatar: _selectedConversation!.otherUser.avatarUrl,
        otherUser: _selectedConversation!.otherUser,
        isSavedMessages: _selectedConversation!.isSavedMessages,
        initialScrollToMessageId: _conversationInitialScrollMessageId,
        onInitialScrollConsumed: () {
          if (_conversationInitialScrollMessageId != null) {
            setState(() => _conversationInitialScrollMessageId = null);
          }
        },
      );
    }

    if (_selectedGroup != null) {
      return GroupChatView(
        key: ValueKey('group-${_selectedGroup!.id}'),
        groupId: _selectedGroup!.id,
        groupName: _selectedGroup!.name,
        groupAvatarUrl: _selectedGroup!.avatarUrl,
        memberCount: _selectedGroup!.memberCount,
        initialScrollToMessageId: _groupInitialScrollMessageId,
        onInitialScrollConsumed: () {
          if (_groupInitialScrollMessageId != null) {
            setState(() => _groupInitialScrollMessageId = null);
          }
        },
      );
    }

    // Handle settings route (before other section routes)
    if (currentRoute == '/settings' || currentRoute.startsWith('/settings')) {
      debugPrint('🔧 [SETTINGS] Showing SettingsScreen for route: $currentRoute');
      return const SettingsScreen();
    }
    
    // Handle channels route
    if (currentRoute == '/channels' || currentRoute.startsWith('/channels')) {
      if (_selectedGroup != null) {
        return GroupChatView(
          key: ValueKey('channel-${_selectedGroup!.id}'),
          groupId: _selectedGroup!.id,
          groupName: _selectedGroup!.name,
          groupAvatarUrl: _selectedGroup!.avatarUrl,
          memberCount: _selectedGroup!.memberCount,
          initialScrollToMessageId: _groupInitialScrollMessageId,
          onInitialScrollConsumed: () {
            if (_groupInitialScrollMessageId != null) {
              setState(() => _groupInitialScrollMessageId = null);
            }
          },
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
    if (currentRoute == '/live-broadcast') {
      return const LiveBroadcastScreen();
    }
    if (currentRoute == '/status') {
      return const StatusListScreen();
    }
    
    // Empty state (no chat selected)
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

  Future<void> _showSearchFilterDialog(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<String> selectedFilters = [];

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getSearchFilters();
      final availableFilters = (response.data['available_filters'] as List?) ?? [];

      final result = await showDialog<List<String>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
            title: Text(
              'Search Filters',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: availableFilters.map<Widget>((filter) {
                  final key = filter['key'] as String;
                  final label = filter['label'] as String;
                  final isSelected = selectedFilters.contains(key);
                  
                  return CheckboxListTile(
                    title: Text(
                      label,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedFilters.add(key);
                        } else {
                          selectedFilters.remove(key);
                        }
                      });
                    },
                    activeColor: const Color(0xFF008069),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, selectedFilters),
                child: const Text('Apply', style: TextStyle(color: Color(0xFF008069))),
              ),
            ],
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _searchFilters = result.isEmpty ? null : result;
        });
        if (_searchQuery.trim().isNotEmpty) {
          _performSidebarSearch();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load filters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
