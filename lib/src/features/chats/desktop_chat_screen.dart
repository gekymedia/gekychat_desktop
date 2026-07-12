import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/services/deep_link_service.dart';
import '../ai/ai_chat_screen.dart';
import '../live/live_broadcast_screen.dart';
import '../labels/labels_repository.dart';
import '../notices/in_app_notice.dart';
import '../notices/in_app_notice_repository.dart';
import '../notices/in_app_notice_strip.dart';
import '../birthdays/birthday_celebrants_panel.dart';
import '../birthdays/birthday_chat_banner.dart';
import '../birthdays/birthday_repository.dart';
import '../birthdays/birthday_sticker_picker.dart';
import '../birthdays/models.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/feature_flags.dart';
import '../../widgets/side_nav.dart';
import '../../theme/app_theme.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/services/taskbar_badge_service.dart';
import '../../features/auth/auth_provider.dart';
import '../calls/incoming_call_handler.dart';
import '../../services/inbox_realtime_sync.dart';
import '../../widgets/skeleton_loader.dart';
import '../../core/global_navigator_key.dart';
import '../../services/product_analytics_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/desktop_shell_colors.dart';
import '../../widgets/resizable_sidebar_panel.dart';
import '../../widgets/desktop_typography.dart';
import '../../widgets/desktop_filter_pill.dart';
import '../../widgets/desktop_empty_state.dart';
import '../../widgets/desktop_shortcuts_hint.dart';
import '../../widgets/gekychat_doodle_background.dart';
import '../../widgets/desktop_glass_popup.dart';
import '../../widgets/desktop_glass_context_menu.dart';

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
  final FocusNode _shellFocusNode = FocusNode();
  String _selectedFilter = 'all';
  String _searchQuery = '';
  Map<String, dynamic>? _searchResults;
  bool _isSearching = false;
  List<String>? _searchFilters;
  Timer? _searchDebounceTimer;
  List<Label> _labels = []; // Store labels for filter chips
  List<InAppNotice> _inAppNotices = [];
  BirthdaySummary _birthdaySummary = BirthdaySummary.empty();
  Set<int> _manualUnreadConversationIds = <int>{};
  Set<int> _manualUnreadGroupIds = <int>{};

  static const _kChatListWidthKey = 'desktop_chat_list_panel_width';
  static const double _kDefaultChatListWidth = 380;
  static const double _kMinChatListWidth = 300;
  static const double _kMaxChatListWidth = 520;
  double _chatListPanelWidth = _kDefaultChatListWidth;
  final GlobalKey _newChatHeaderButtonKey = GlobalKey();
  final GlobalKey _chatsMoreMenuButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadChatListPanelWidth());
    // Prefetch data by watching providers (they cache automatically)
    ref.read(optimizedConversationsProvider.future);
    ref.read(optimizedGroupsProvider.future);
    ref.read(optimizedArchivedConversationsProvider.future);
    _loadLabels();
    _loadInAppNotices();
    _loadBirthdaySummary();
    _loadManualUnreadMarkers();
    // Warm up contact display names after first frame (avoid provider churn during build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(contactDisplayServiceProvider).warmUp();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(productAnalyticsProvider).startSession());
      unawaited(ref.read(productAnalyticsProvider).trackFeature(ref.read(currentSectionProvider)));
      ref.read(incomingCallHandlerProvider).setContext(context);

      // Legacy /settings URL → section state (shell URL stays /chats).
      final path = GoRouterState.of(context).uri.path;
      if (path == '/settings' || path.startsWith('/settings/')) {
        ref.read(currentSectionProvider.notifier).setSection('/settings');
        if (path != '/chats') {
          context.go('/chats');
        }
        return;
      }

      // Only restore open chat when the chats pane is active — otherwise
      // _switchToChatsView() would immediately leave Settings/World/etc.
      if (ref.read(currentSectionProvider) != '/chats') return;
      _restoreSelectionFromProviders();
    });
  }

  Future<void> _loadChatListPanelWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_kChatListWidthKey);
      if (!mounted || saved == null) return;
      setState(() {
        _chatListPanelWidth =
            saved.clamp(_kMinChatListWidth, _kMaxChatListWidth);
      });
    } catch (e) {
      debugPrint('Failed to load chat list panel width: $e');
    }
  }

  Future<void> _persistChatListPanelWidth(double width) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kChatListWidthKey, width);
    } catch (e) {
      debugPrint('Failed to save chat list panel width: $e');
    }
  }

  Future<void> _markAllChatsAsRead() async {
    final chatRepo = ref.read(chatRepositoryProvider);
    try {
      final conversations =
          ref.read(sidebarConversationsProvider).valueOrNull ?? [];
      final groups = ref.read(sidebarGroupsProvider).valueOrNull ?? [];
      for (final c in conversations) {
        if (c.unreadCount > 0) {
          await chatRepo.markConversationAsRead(c.id);
        }
      }
      for (final g in groups) {
        if (g.unreadCount > 0) {
          await chatRepo.markGroupAsRead(g.id);
        }
      }
      if (mounted) {
        context.showSuccessToast('All chats marked as read');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to mark all as read: $e');
      }
    }
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
      if (found == null) {
        final api = ref.read(apiServiceProvider);
        final response = await api.get('/groups/$groupId');
        final raw = response.data;
        final data = raw is Map ? raw['data'] : null;
        if (data is Map && data.isNotEmpty) {
          found = GroupSummary.fromJson(Map<String, dynamic>.from(data));
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
    _shellFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _clearChatSelection() {
    if (_selectedConversation == null && _selectedGroup == null) return;
    setState(() {
      _selectedConversation = null;
      _selectedGroup = null;
      _selectedConversationId = null;
      _selectedGroupId = null;
      _groupInitialScrollMessageId = null;
      _conversationInitialScrollMessageId = null;
    });
    ref.read(selectedConversationProvider.notifier).clearSelection();
    ref.read(selectedGroupIdProvider.notifier).state = null;
  }

  void _handleShellEscape() {
    if (_searchController.text.isNotEmpty) {
      _clearSidebarSearch();
      return;
    }
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      return;
    }
    _clearChatSelection();
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
            context.showErrorToast('Search failed: $e');    }
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
      unawaited(ProductAnalyticsLifecycle.onResumed(ref));
      unawaited(
        ref.read(optimizedConversationsProvider.notifier).refreshSilently(),
      );
      unawaited(ref.read(optimizedGroupsProvider.notifier).refreshSilently());
      ref.invalidate(optimizedArchivedConversationsProvider);
      unawaited(ref.read(pusherServiceProvider).resetReconnectPolicyAndConnect());
      unawaited(ref.read(inboxRealtimeSyncProvider).initialize(force: true));
      _updateTaskbarBadge();
      _loadInAppNotices();
      _loadBirthdaySummary();
    } else if (state == AppLifecycleState.paused) {
      unawaited(ProductAnalyticsLifecycle.onPaused(ref));
    }
  }

  void _refreshConversations() {
    unawaited(
      ref.read(optimizedConversationsProvider.notifier).refreshSilently(),
    );
    _updateTaskbarBadge();
  }

  void _refreshArchivedConversations() {
    ref.invalidate(optimizedArchivedConversationsProvider);
  }

  void _refreshGroups() {
    unawaited(ref.read(optimizedGroupsProvider.notifier).refreshSilently());
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
    if (filter == 'broadcast') {
      showBroadcastListsModal(context);
      return;
    }
    setState(() {
      _selectedFilter = filter;
    });
    if (filter == 'archived') {
      _refreshArchivedConversations();
    }
  }

  void _showCreateGroupModal({String groupType = 'group'}) {
    CreateGroupScreen.showModal(context, groupType: groupType);
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
      return DesktopEmptyState(
        icon: _selectedFilter == 'archived'
            ? Icons.archive_outlined
            : Icons.chat_bubble_outline,
        message: _emptyFilterMessage(),
        actionLabel: _selectedFilter == 'all' ? 'Start a chat' : null,
        onAction: _selectedFilter == 'all'
            ? () {
                final anchor = _newChatHeaderButtonKey.currentContext;
                if (anchor != null) _showNewChatMenu(anchor);
              }
            : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        if (item is ConversationSummary) {
          final isSelected = _selectedConversationId == item.id;
          return ConversationListItem(
              conversation: item,
              isSelected: isSelected,
              forceUnreadBadge: _isManuallyUnreadConversation(item.id),
              onLongPress: () => _showConversationMenu(context, item),
              onSecondaryTapDown: (details) => _showConversationMenuAtPosition(
                context,
                item,
                details.globalPosition,
              ),
              onMenuTap: (position) => _showConversationMenuAtPosition(
                context,
                item,
                position,
              ),
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
            );
        } else if (item is GroupSummary) {
          final isSelected = _selectedGroupId == item.id;
          return GroupListItem(
              group: item,
              isSelected: isSelected,
              forceUnreadBadge: _isManuallyUnreadGroup(item.id),
              onLongPress: () => _showGroupMenu(context, item),
              onSecondaryTapDown: (details) => _showGroupMenuAtPosition(
                context,
                item,
                details.globalPosition,
              ),
              onMenuTap: (position) => _showGroupMenuAtPosition(
                context,
                item,
                position,
              ),
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

  Future<void> _loadBirthdaySummary() async {
    try {
      final summary = await ref.read(birthdayRepositoryProvider).fetchSummary();
      if (mounted) setState(() => _birthdaySummary = summary);
    } catch (e) {
      debugPrint('Birthday summary load skipped: $e');
    }
  }

  Future<void> _dismissBirthdayBanner() async {
    final key = _birthdaySummary.dismissKey;
    if (key.isEmpty) return;
    await ref.read(birthdayRepositoryProvider).dismissBanner(key);
    if (mounted) {
      setState(() => _birthdaySummary = BirthdaySummary.empty());
    }
  }

  Future<void> _openBirthdayCelebrants() async {
    var summary = _birthdaySummary;
    if (summary.today.isEmpty && summary.yesterday.isEmpty) {
      summary = await ref.read(birthdayRepositoryProvider).fetchSummary();
      if (!mounted) return;
      setState(() => _birthdaySummary = summary);
    }
    if (summary.today.isEmpty && summary.yesterday.isEmpty) return;
    await showBirthdayCelebrantsDesktop(
      context,
      summary: summary,
      onSendWish: _sendBirthdayWish,
      onSendSticker: _sendBirthdaySticker,
      onAddBirthday: _openBirthdaySettings,
    );
  }

  void _openBirthdaySettings() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    ref.read(currentSectionProvider.notifier).setSection('/settings');
  }

  Future<void> _sendBirthdayWish(BirthdayCelebrant celebrant) async {
    if (celebrant.isSelf) {
      _openBirthdaySettings();
      return;
    }
    var conversationId = celebrant.conversationId;
    if (conversationId == null) {
      try {
        final response =
            await ref.read(apiServiceProvider).startConversation(celebrant.userId);
        final data = response.data;
        conversationId = data is Map
            ? (data['data'] is Map
                ? data['data']['id'] as int?
                : data['id'] as int?)
            : null;
      } catch (e) {
        if (mounted) context.showErrorToast('Could not open chat: $e');
        return;
      }
    }
    if (conversationId == null || !mounted) return;

    final draft = 'Happy birthday, ${celebrant.name}! 🎂';
    ref.read(pendingDesktopComposerDraftProvider.notifier).state =
        DesktopPendingComposerDraft(
      conversationId: conversationId,
      text: draft,
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    ref.read(selectedConversationProvider.notifier).selectConversation(conversationId);
    await _selectConversationById(conversationId);
  }

  Future<void> _sendBirthdaySticker(BirthdayCelebrant celebrant) async {
    if (celebrant.isSelf) {
      context.showInfoToast('Send stickers to friends from their birthday row');
      return;
    }
    await showBirthdayStickerPicker(
      context,
      celebrantName: celebrant.name,
      onSelected: (file) async {
        final conversationId =
            await ref.read(birthdayRepositoryProvider).resolveConversationId(celebrant);
        if (conversationId == null || !mounted) {
          context.showErrorToast('Could not open chat');
          return;
        }
        try {
          await ref.read(chatRepositoryProvider).sendMessageToConversation(
                conversationId: conversationId,
                attachments: [file],
                skipCompression: true,
              );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          if (mounted) {
            context.showSuccessToast('Birthday sticker sent to ${celebrant.name}');
          }
        } catch (e) {
          if (mounted) {
            context.showErrorToast('Failed to send sticker: $e');
          }
        }
      },
    );
  }

  void _showConversationMenuAtPosition(BuildContext context, ConversationSummary conversation, Offset position) {
    final chatRepo = ref.read(chatRepositoryProvider);

    DesktopGlassContextMenu.showAtPosition(
      context: context,
      globalPosition: position,
      items: [
        DesktopGlassMenuItem(
          icon: conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          label: conversation.isPinned ? 'Unpin' : 'Pin',
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
                context.showErrorToast('Failed: $e');
              }
            }
          },
        ),
        DesktopGlassMenuItem(
          icon: conversation.archivedAt != null ? Icons.unarchive : Icons.archive,
          label: conversation.archivedAt != null ? 'Unarchive' : 'Archive',
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
                context.showErrorToast('Failed: $e');
              }
            }
          },
        ),
        DesktopGlassMenuItem(
          icon: Icons.mark_chat_unread,
          label: 'Mark as unread',
          onTap: () async {
            try {
              await chatRepo.markConversationUnread(conversation.id);
              await _setConversationManualUnread(conversation.id, value: true);
              _refreshConversations();
            } catch (e) {
              if (mounted) {
                context.showErrorToast('Failed: $e');
              }
            }
          },
        ),
        DesktopGlassMenuItem(
          icon: Icons.label_outline,
          label: 'Add to Label',
          onTap: () => _showAddToLabelDialog(context, conversation.id),
        ),
        DesktopGlassMenuItem(
          icon: Icons.download,
          label: 'Export chat',
          onTap: () => _exportConversation(conversation.id),
        ),
        DesktopGlassMenuItem(
          icon: Icons.report,
          label: 'Report',
          accentColor: Colors.orange,
          onTap: () => _showReportDialog(
            conversation.otherUser.id,
            conversation.otherUser.name,
          ),
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
                    context.showInfoToast('No labels available. Create one first.');        }
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
          content: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 280,
              maxWidth: 360,
              maxHeight: 360,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: labels.length,
              itemBuilder: (context, index) {
                final label = labels[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
                        context.showSuccessToast('Added to ${selectedLabel.name}');            _refreshConversations();
          }
        } catch (e) {
          if (mounted) {
                        context.showErrorToast('Failed to add to label: $e');          }
        }
      }
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to load labels: $e');      }
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
                    context.showSuccessToast('Report submitted${alsoBlock ? " and user blocked" : ""}');        }
      } catch (e) {
        if (mounted) {
                    context.showErrorToast('Failed to report user: $e');        }
      }
    }
  }

  Future<void> _exportConversation(int conversationId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Show loading indicator
      if (mounted) {
                context.showInfoToast('Exporting chat...');      }
      
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
                context.showInfoToast('Chat exported to Downloads/$fileName');      }
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to export chat: $e');      }
    }
  }

  void _showConversationMenu(BuildContext context, ConversationSummary conversation) {
    final renderObject = context.findRenderObject();
    final position = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(renderObject.size.center(Offset.zero))
        : Offset(
            MediaQuery.sizeOf(context).width / 2,
            MediaQuery.sizeOf(context).height / 2,
          );
    _showConversationMenuAtPosition(context, conversation, position);
  }

  void _showGroupMenuAtPosition(BuildContext context, GroupSummary group, Offset position) {
    final chatRepo = ref.read(chatRepositoryProvider);

    DesktopGlassContextMenu.showAtPosition(
      context: context,
      globalPosition: position,
      items: [
        DesktopGlassMenuItem(
          icon: group.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          label: group.isPinned ? 'Unpin' : 'Pin',
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
                context.showErrorToast('Failed: $e');
              }
            }
          },
        ),
        DesktopGlassMenuItem(
          icon: group.isMuted ? Icons.notifications : Icons.notifications_off,
          label: group.isMuted ? 'Unmute' : 'Mute',
          onTap: () async {
            try {
              if (group.isMuted) {
                await chatRepo.unmuteGroup(group.id);
              } else {
                await chatRepo.muteGroup(group.id, minutes: 1440);
              }
              _refreshGroups();
            } catch (e) {
              if (mounted) {
                context.showErrorToast('Failed: $e');
              }
            }
          },
        ),
        DesktopGlassMenuItem(
          icon: Icons.mark_chat_unread,
          label: 'Mark as unread',
          onTap: () async {
            try {
              await chatRepo.markGroupUnread(group.id);
              await _setGroupManualUnread(group.id, value: true);
              _refreshGroups();
            } catch (e) {
              if (mounted) {
                context.showErrorToast('Failed: $e');
              }
            }
          },
        ),
      ],
    );
  }

  void _showGroupMenu(BuildContext context, GroupSummary group) {
    final renderObject = context.findRenderObject();
    final position = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(renderObject.size.center(Offset.zero))
        : Offset(
            MediaQuery.sizeOf(context).width / 2,
            MediaQuery.sizeOf(context).height / 2,
          );
    _showGroupMenuAtPosition(context, group, position);
  }

  void _showNewChatMenu(BuildContext anchorContext) {
    DesktopGlassPopup.show(
      context: context,
      anchorContext: anchorContext,
      alignRight: true,
      items: [
        DesktopGlassMenuItem(
          icon: Icons.group_add_outlined,
          label: 'New group',
          onTap: () => _showCreateGroupModal(),
        ),
        DesktopGlassMenuItem(
          icon: Icons.campaign_outlined,
          label: 'New channel',
          onTap: () => _showCreateGroupModal(groupType: 'channel'),
        ),
        DesktopGlassMenuItem(
          icon: Icons.person_add_outlined,
          label: 'New contact',
          onTap: () => ContactsScreen.showModal(context),
        ),
      ],
    );
  }

  void _showChatsMoreMenu(BuildContext anchorContext) {
    DesktopGlassPopup.show(
      context: context,
      anchorContext: anchorContext,
      alignRight: true,
      items: [
        DesktopGlassMenuItem(
          icon: Icons.group_add_outlined,
          label: 'New group',
          onTap: () => _showCreateGroupModal(),
        ),
        DesktopGlassMenuItem(
          icon: Icons.campaign_outlined,
          label: 'New channel',
          onTap: () => _showCreateGroupModal(groupType: 'channel'),
        ),
        DesktopGlassMenuItem(
          icon: Icons.person_add_outlined,
          label: 'New contact',
          onTap: () => ContactsScreen.showModal(context),
        ),
        const DesktopGlassMenuItem.divider(),
        DesktopGlassMenuItem(
          icon: Icons.archive_outlined,
          label: 'Archived',
          onTap: () => setState(() => _selectedFilter = 'archived'),
        ),
        DesktopGlassMenuItem(
          icon: Icons.done_all_outlined,
          label: 'Mark all as read',
          onTap: _markAllChatsAsRead,
        ),
        DesktopGlassMenuItem(
          icon: Icons.podcasts_outlined,
          label: 'Broadcast lists',
          onTap: () => showBroadcastListsModal(context),
        ),
      ],
    );
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
                _groupInitialScrollMessageId =
                    link.messageId > 0 ? link.messageId : null;
              });
              ref.read(selectedGroupIdProvider.notifier).state = group.id;
              ref.read(selectedConversationProvider.notifier).clearSelection();
              _switchToChatsView();
            }));
          });
        } else {
          await _selectGroupById(
            link.groupId,
            scrollToMessageId: link.messageId > 0 ? link.messageId : null,
          );
        }
      } catch (e) {
        if (mounted) {
                    context.showErrorToast('Could not open group: $e');        }
      }
    });
    
    // Listen to account changes and refresh data
    ref.listen(currentUserProvider, (previous, next) {
      final previousId = previous?.valueOrNull?.id;
      final nextId = next.valueOrNull?.id;
      if (previousId != null && nextId != null && previousId != nextId) {
        debugPrint('🔄 Account changed detected: User ID $previousId -> $nextId');
        debugPrint('🔄 Refreshing conversations, groups, and labels for new account...');
        ref.invalidate(optimizedConversationsProvider);
        ref.invalidate(optimizedGroupsProvider);
        _refreshArchivedConversations();
        _loadLabels();
        debugPrint('✅ Data refresh completed for new account');
      }
    });

    // Use provider for main sections, fallback to route for external routes
    final currentSection = ref.watch(currentSectionProvider);
    final currentRoute = GoRouterState.of(context).uri.path;
    
    // Shell stays on /chats; sidenav + main pane use [currentSectionProvider].
    final effectiveRoute = currentSection;
    
    debugPrint('🔧 [ROUTE] currentRoute: $currentRoute, currentSection: $currentSection, effectiveRoute: $effectiveRoute');

    final shellBackground =
        DesktopShellColors.shellChromeBackground(context, isDark: isDark);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const _FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const _FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const _NewChatIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const _NewChatIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const _ClearShellIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              if (effectiveRoute == '/chats') {
                _searchFocusNode.requestFocus();
              }
              return null;
            },
          ),
          _NewChatIntent: CallbackAction<_NewChatIntent>(
            onInvoke: (_) {
              if (effectiveRoute == '/chats') {
                final anchor = _newChatHeaderButtonKey.currentContext;
                if (anchor != null) {
                  _showNewChatMenu(anchor);
                } else {
                  _showNewChatMenu(context);
                }
              }
              return null;
            },
          ),
          _ClearShellIntent: CallbackAction<_ClearShellIntent>(
            onInvoke: (_) {
              _handleShellEscape();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _shellFocusNode,
          autofocus: true,
          child: Scaffold(
      backgroundColor: shellBackground,
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
                RepaintBoundary(
                  child: SideNav(
                    currentRoute: effectiveRoute,
                    backgroundColor: shellBackground,
                  ),
                ),
                RepaintBoundary(
                  child: ResizableSidebarPanel(
                    width: _chatListPanelWidth,
                    minWidth: _kMinChatListWidth,
                    maxWidth: _kMaxChatListWidth,
                    isDark: isDark,
                    onWidthChanged: (width) {
                      setState(() => _chatListPanelWidth = width);
                      unawaited(_persistChatListPanelWidth(width));
                    },
                    child: _buildSidebarContent(context, effectiveRoute, isDark),
                  ),
                ),
                Expanded(
                  child: _buildMainContent(context, effectiveRoute, isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
        ),
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
    final listBg = DesktopShellColors.listPanelBackground(isDark);
    final borderColor = DesktopShellColors.listPanelBorder(isDark);
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
          decoration: BoxDecoration(
            color: listBg,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: Row(
            children: [
              Text(
                'Channels',
                style: DesktopTypography.sectionTitle(isDark: isDark),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: isDark ? Colors.white70 : const Color(0xFF667781),
                ),
                onPressed: () => _showCreateGroupModal(groupType: 'channel'),
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
                  return GroupListItem(
                      group: channel,
                      isSelected: isSelected,
                      onLongPress: () => _showGroupMenu(context, channel),
                      onSecondaryTapDown: (details) => _showGroupMenuAtPosition(
                        context,
                        channel,
                        details.globalPosition,
                      ),
                      onMenuTap: (position) => _showGroupMenuAtPosition(
                        context,
                        channel,
                        position,
                      ),
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
    final listBg = DesktopShellColors.listPanelBackground(isDark);

    return Column(
      children: [
        // Header + search — single clean block
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
          color: listBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Chats',
                    style: DesktopTypography.sectionTitle(isDark: isDark),
                  ),
                  const Spacer(),
                  IconButton(
                    key: _newChatHeaderButtonKey,
                    icon: Icon(
                      Icons.add_comment_outlined,
                      color: isDark ? Colors.white70 : const Color(0xFF667781),
                    ),
                    tooltip: 'New chat',
                    onPressed: () {
                      final anchor = _newChatHeaderButtonKey.currentContext;
                      if (anchor != null) {
                        _showNewChatMenu(anchor);
                      }
                    },
                  ),
                  IconButton(
                    key: _chatsMoreMenuButtonKey,
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.white70 : const Color(0xFF667781),
                    ),
                    tooltip: 'More options',
                    onPressed: () {
                      final anchor = _chatsMoreMenuButtonKey.currentContext;
                      if (anchor != null) {
                        _showChatsMoreMenu(anchor);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF111B21),
                          fontSize: DesktopTypography.searchHintSize,
                          fontFamily: DesktopTypography.fontFamily,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search or press Ctrl+K',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF707579),
                            fontSize: DesktopTypography.searchHintSize,
                            fontFamily: DesktopTypography.fontFamily,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF667781),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF667781),
                                  ),
                                  onPressed: _clearSidebarSearch,
                                )
                              : null,
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF2A3942)
                              : const Color(0xFFF0F2F5),
                          border: OutlineInputBorder(
                            borderRadius: DesktopShellColors.pillBorderRadius,
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: DesktopShellColors.pillBorderRadius,
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: DesktopShellColors.pillBorderRadius,
                            borderSide: BorderSide(
                              color: const Color(0xFF008069)
                                  .withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          isDense: true,
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
                          final currentRoute =
                              router.routerDelegate.currentConfiguration.uri.path;
                          if (value.trim().isEmpty) return;
                          if (currentRoute == '/world') {
                            _searchDebounceTimer =
                                Timer(const Duration(milliseconds: 500), () async {
                              try {
                                final worldFeedRepo =
                                    ref.read(worldFeedRepositoryProvider);
                                final response = await worldFeedRepo.getFeed(
                                  page: 1,
                                  query: value,
                                );
                                debugPrint(
                                  'World feed search results: ${response['data']?.length ?? 0} posts',
                                );
                              } catch (e) {
                                debugPrint('World feed search error: $e');
                              }
                            });
                          } else {
                            _searchDebounceTimer =
                                Timer(const Duration(milliseconds: 400), () {
                              _performSidebarSearch();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (context) {
                      final router = GoRouter.of(context);
                      final currentRoute =
                          router.routerDelegate.currentConfiguration.uri.path;
                      if (currentRoute == '/world') {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: Icon(
                          Icons.tune,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                        tooltip: 'Search filters',
                        onPressed: () {
                          _showSearchFilterDialog(context, ref);
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_searchQuery.trim().isEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            color: listBg,
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
                  _buildAddLabelPill(isDark),
                ],
              ),
            ),
          ),
        if (_inAppNotices.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            color: listBg,
            child: InAppNoticeStrip(
              notices: _inAppNotices,
              onDismiss: _dismissInAppNotice,
            ),
          ),
        BirthdayChatBanner(
          summary: _birthdaySummary,
          isDark: isDark,
          onTap: _openBirthdayCelebrants,
          onDismiss: _dismissBirthdayBanner,
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
                  final staleConversations = conversationsAsync.valueOrNull;
                  if (staleConversations != null) {
                    return groupsAsync.when(
                      data: (allGroups) =>
                          _buildConversationList(staleConversations, allGroups),
                      loading: () =>
                          _buildConversationList(staleConversations, []),
                      error: (_, __) =>
                          _buildConversationList(staleConversations, []),
                    );
                  }
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
                    context.showSuccessToast('Label created successfully');        }
      } catch (e) {
        if (mounted) {
                    context.showErrorToast('Failed to create label: $e');        }
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
  
  Widget _buildAddLabelPill(bool isDark) {
    return SizedBox(
      height: 32,
      child: Material(
        color: isDark ? const Color(0xFF2A3942) : const Color(0xFFF0F2F5),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showCreateLabelDialog(context, isDark),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.add, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChipWidget(
    String filter,
    String label,
    bool isDark,
    bool isSelected,
    int? unreadCount,
  ) {
    return DesktopFilterPill(
      label: label,
      isSelected: isSelected,
      isDark: isDark,
      badgeCount: unreadCount,
      onTap: () => _onFilterChipSelected(filter),
    );
  }

  Widget _buildEmptyChatPane(bool isDark) {
    final shellBg = DesktopShellColors.chatPaneBackground(isDark);
    final muted = isDark ? Colors.white60 : const Color(0xFF707579);

    return Container(
      color: shellBg,
      child: Stack(
        children: [
          GekyChatDoodleBackground(isDark: isDark),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/gold_no_text/128x128.png',
                  width: 96,
                  height: 96,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Select a conversation to start chatting',
                  style: DesktopTypography.sectionTitle(isDark: isDark, color: muted)
                      .copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildEmptyPaneAction(
                      isDark: isDark,
                      icon: Icons.person_add_outlined,
                      label: 'New chat',
                      onTap: _showNewChatMenu,
                    ),
                    const SizedBox(width: 20),
                    _buildEmptyPaneAction(
                      isDark: isDark,
                      icon: Icons.group_add_outlined,
                      label: 'New group',
                      onTap: (_) => _showCreateGroupModal(),
                    ),
                    const SizedBox(width: 20),
                    _buildEmptyPaneAction(
                      isDark: isDark,
                      icon: Icons.archive_outlined,
                      label: 'Archived',
                      onTap: (_) => setState(() => _selectedFilter = 'archived'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const DesktopShortcutsHint(),
        ],
      ),
    );
  }

  Widget _buildEmptyPaneAction({
    required bool isDark,
    required IconData icon,
    required String label,
    required void Function(BuildContext anchorContext) onTap,
  }) {
    return Builder(
      builder: (anchorContext) => InkWell(
        onTap: () => onTap(anchorContext),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
                shape: BoxShape.circle,
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.white70 : const Color(0xFF667781),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: DesktopTypography.fontFamily,
                color: isDark ? Colors.white70 : const Color(0xFF707579),
                fontSize: DesktopTypography.listSubtitleSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildMainContent(BuildContext context, String currentRoute, bool isDark) {
    if (currentRoute == '/settings' || currentRoute.startsWith('/settings')) {
      return const SettingsScreen();
    }

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
        color: DesktopShellColors.chatPaneBackground(isDark),
        child: Stack(
          children: [
            GekyChatDoodleBackground(isDark: isDark),
            Center(
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
                      fontFamily: DesktopTypography.fontFamily,
                      color: isDark ? Colors.white70 : const Color(0xFF707579),
                      fontSize: DesktopTypography.emptyStateSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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

    // Chats pane — show the open thread when one is selected.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _selectedConversation != null
          ? ChatView(
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
      )
          : _selectedGroup != null
              ? GroupChatView(
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
      )
              : KeyedSubtree(
                  key: const ValueKey('empty-chat-pane'),
                  child: _buildEmptyChatPane(isDark),
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
                context.showErrorToast('Failed to load filters: $e');      }
    }
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _NewChatIntent extends Intent {
  const _NewChatIntent();
}

class _ClearShellIntent extends Intent {
  const _ClearShellIntent();
}
