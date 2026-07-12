import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_repo.dart';
import 'chat_providers.dart';
import 'models.dart';
import '../status/status_repository.dart';
import '../../core/providers.dart';
import '../../core/providers/connectivity_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/avatar_utils.dart';
import '../../utils/storage_url.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/desktop_center_modal.dart';

ImageProvider? _avatarImageProvider(String? url) {
  final resolved = resolveStorageUrl(url);
  if (resolved == null || resolved.trim().isEmpty) return null;
  return CachedNetworkImageProvider(resolved);
}

class ForwardMessageScreen extends ConsumerStatefulWidget {
  final Message message;
  final bool forModal;

  const ForwardMessageScreen({
    super.key,
    required this.message,
    this.forModal = false,
  });

  static Future<void> showModal(BuildContext context, Message message) {
    return showDesktopCenterModal<void>(
      context: context,
      title: 'Forward message',
      maxWidth: 560,
      maxHeightFraction: 0.85,
      child: ForwardMessageScreen(message: message, forModal: true),
    );
  }

  @override
  ConsumerState<ForwardMessageScreen> createState() =>
      _ForwardMessageScreenState();
}

class _ForwardMessageScreenState
    extends ConsumerState<ForwardMessageScreen> {
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Clear previous selections when opening forward screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(_forwardSelectionProvider.notifier).clear();
    });
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    // Do not use [ref] here — Riverpod marks the element disposed before
    // [State.dispose] runs. Selection resets via autoDispose + clear-on-open.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the selection provider to rebuild when selection changes
    final selection = ref.watch(_forwardSelectionProvider);
    final hasSelection = selection.conversations.isNotEmpty || selection.groups.isNotEmpty || selection.savedMessagesSelected;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search contacts...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Chats'),
                    Tab(text: 'Groups & Channels'),
                    Tab(text: 'Status'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ConversationTab(searchQuery: _searchQuery),
                      _GroupTab(searchQuery: _searchQuery),
                      _StatusTab(message: widget.message),
                    ],
                  ),
                ),
                if (widget.forModal)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FilledButton.icon(
                      onPressed: (!hasSelection || _isLoading) ? null : _forward,
                      icon: const Icon(Icons.send),
                      label: const Text('Forward'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF008069),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
              ],
            ),
          );

    if (widget.forModal) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forward Message'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.send,
              color: (!hasSelection || _isLoading)
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                  : theme.colorScheme.primary,
            ),
            onPressed: (!hasSelection || _isLoading) ? null : _forward,
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _forward() async {
    // Check network status first
    final networkStatus = ref.read(connectivityProvider);
    final isOnline = networkStatus;
    
    if (!isOnline) {
      if (!mounted) return;
            context.showInfoToast('Cannot forward message while offline. Please check your connection and try again.');      return;
    }
    
    setState(() => _isLoading = true);
    final repo = ref.read(chatRepositoryProvider);
    final selection = ref.read(_forwardSelectionProvider);

    try {
      // Build all targets in a single list
      final targets = <Map<String, dynamic>>[];
      final forwardedConversationIds = <int>{...selection.conversations};
      
      // Add Saved Messages (self) as a normal conversation target.
      // The forward API expects concrete chat/group IDs and may reject custom "self" types.
      if (selection.savedMessagesSelected) {
        final conversations = await repo.getConversations();
        int? savedConversationId;
        for (final c in conversations) {
          if (c.isSavedMessages) {
            savedConversationId = c.id;
            break;
          }
        }
        if (savedConversationId != null && savedConversationId > 0) {
          forwardedConversationIds.add(savedConversationId);
        } else {
          throw Exception(
            'Unable to find your Saved Messages chat. Open it once and try again.',
          );
        }
      }
      
      // Add all conversation targets
      for (final id in forwardedConversationIds) {
        targets.add({
          'type': 'conversation',
          'id': id,
        });
      }

      // Add all group targets
      for (final id in selection.groups) {
        targets.add({
          'type': 'group',
          'id': id,
        });
      }

      // Forward to all targets in a single API call
      if (targets.isNotEmpty) {
        await repo.forwardMessage(
          widget.message.id,
          targets,
        );
      } else {
        throw Exception('No recipients selected');
      }

      if (!mounted) return;
      // Pop with the targets list so the caller can refresh affected chats
      Navigator.pop(context, {
        'conversations': forwardedConversationIds.toList(),
        'groups': selection.groups.toList(),
        'savedMessages': selection.savedMessagesSelected,
      });
            context.showInfoToast('Message forwarded to ${targets.length} ${targets.length == 1 ? 'recipient' : 'recipients'}');    } catch (e) {
      debugPrint('Error forwarding message: $e');
      if (!mounted) return;
      
      // Provide more user-friendly error message
      String errorMessage = 'Failed to forward message';
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        errorMessage = 'No internet connection. Please try again when online.';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Message not found. It may have been deleted.';
      } else if (e.toString().contains('403')) {
        errorMessage = 'You do not have permission to forward this message.';
      }
      
            context.showErrorToast(errorMessage);    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

/* -------------------------------------------------------------------------- */
/*                                Conversations                                */
/* -------------------------------------------------------------------------- */

class _ConversationTab extends ConsumerWidget {
  final String searchQuery;
  
  const _ConversationTab({this.searchQuery = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(chatRepositoryProvider);
    // Watch the selection provider so the widget rebuilds when selection changes
    final selection = ref.watch(_forwardSelectionProvider);

    return FutureBuilder<List<ConversationSummary>>(
      future: repo.getConversations(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final conversations = snap.data ?? [];
        
        // Check if Saved Messages already exists in the list
        final hasSavedMessages = conversations.any((c) => c.isSavedMessages);
        
        // Put Saved Messages (Yourself) first so user can forward to themselves easily
        var sorted = List<ConversationSummary>.from(conversations)
          ..sort((a, b) {
            if (a.isSavedMessages && !b.isSavedMessages) return -1;
            if (!a.isSavedMessages && b.isSavedMessages) return 1;
            return 0;
          });
        
        // Filter by search query
        if (searchQuery.isNotEmpty) {
          sorted = sorted.where((c) {
            final name = c.isSavedMessages ? 'saved messages' : c.otherUser.name.toLowerCase();
            final phone = c.otherUser.phone?.toLowerCase() ?? '';
            return name.contains(searchQuery) || phone.contains(searchQuery);
          }).toList();
        }
        
        // Calculate if we need to show synthetic Saved Messages entry
        final showSyntheticSavedMessages = !hasSavedMessages && 
            (searchQuery.isEmpty || 'saved messages'.contains(searchQuery));
        
        final totalCount = sorted.length + (showSyntheticSavedMessages ? 1 : 0);
        
        if (totalCount == 0) {
          return Center(
            child: Text(searchQuery.isNotEmpty ? 'No matching conversations' : 'No conversations'),
          );
        }

        return ListView.separated(
          itemCount: totalCount,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            // Show synthetic Saved Messages at index 0 if needed
            if (showSyntheticSavedMessages && i == 0) {
              // Use a special ID (-1) for synthetic saved messages
              final checked = selection.savedMessagesSelected;
              return ListTile(
                leading: Checkbox(
                  value: checked,
                  onChanged: (v) {
                    ref.read(_forwardSelectionProvider.notifier)
                        .toggleSavedMessages();
                  },
                ),
                title: const Text('Saved Messages (You)'),
                subtitle: const Text('Forward to yourself'),
                trailing: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.bookmark, color: Colors.white),
                ),
                onTap: () {
                  ref.read(_forwardSelectionProvider.notifier)
                      .toggleSavedMessages();
                },
              );
            }
            
            // Adjust index if we showed synthetic entry
            final adjustedIndex = showSyntheticSavedMessages ? i - 1 : i;
            final c = sorted[adjustedIndex];
            final user = c.otherUser;
            final checked = c.isSavedMessages 
                ? selection.savedMessagesSelected 
                : selection.conversations.contains(c.id);
            final displayName = c.isSavedMessages ? 'Saved Messages (You)' : user.name;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: c.isSavedMessages
                    ? Theme.of(context).colorScheme.primary
                    : AvatarUtils.getColorForName(displayName),
                backgroundImage: c.isSavedMessages
                    ? null
                    : _avatarImageProvider(user.avatarUrl),
                child: c.isSavedMessages
                    ? const Icon(Icons.bookmark, color: Colors.white)
                    : (_avatarImageProvider(user.avatarUrl) == null
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            )
                          : null),
              ),
              title: Text(displayName),
              subtitle: c.isSavedMessages
                  ? const Text('Forward to yourself')
                  : (c.lastMessage != null
                      ? Text(
                          c.lastMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null),
              trailing: Checkbox(
                value: checked,
                onChanged: (v) {
                  if (c.isSavedMessages) {
                    ref.read(_forwardSelectionProvider.notifier)
                        .toggleSavedMessages();
                  } else {
                    ref.read(_forwardSelectionProvider.notifier)
                        .toggleConversation(c.id);
                  }
                },
              ),
              onTap: () {
                if (c.isSavedMessages) {
                  ref.read(_forwardSelectionProvider.notifier)
                      .toggleSavedMessages();
                } else {
                  ref.read(_forwardSelectionProvider.notifier)
                      .toggleConversation(c.id);
                }
              },
            );
          },
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   Groups                                   */
/* -------------------------------------------------------------------------- */

class _GroupTab extends ConsumerWidget {
  final String searchQuery;
  
  const _GroupTab({this.searchQuery = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(chatRepositoryProvider);
    // Watch the selection provider so the widget rebuilds when selection changes
    final selection = ref.watch(_forwardSelectionProvider);

    return FutureBuilder<List<GroupSummary>>(
      future: repo.getGroups(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        var groups = snap.data ?? [];
        
        // Filter by search query
        if (searchQuery.isNotEmpty) {
          groups = groups.where((g) {
            return g.name.toLowerCase().contains(searchQuery);
          }).toList();
        }
        
        if (groups.isEmpty) {
          return Center(
            child: Text(searchQuery.isNotEmpty ? 'No matching groups' : 'No groups'),
          );
        }

        return ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final g = groups[i];
            final checked = selection.groups.contains(g.id);
            final isChannel = g.type == 'channel';
            
            // Build subtitle with member/follower count
            String? subtitle;
            if (g.memberCount != null && g.memberCount! > 0) {
              final count = g.memberCount!;
              if (isChannel) {
                subtitle = '$count ${count == 1 ? 'follower' : 'followers'}';
              } else {
                subtitle = '$count ${count == 1 ? 'member' : 'members'}';
              }
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: _avatarImageProvider(g.avatarUrl),
                backgroundColor: isChannel
                    ? Theme.of(context).colorScheme.secondary
                    : AvatarUtils.getColorForName(g.name),
                child: _avatarImageProvider(g.avatarUrl) == null
                    ? Icon(
                        isChannel ? Icons.campaign : Icons.groups,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
              title: Text(g.name),
              subtitle: subtitle != null ? Text(subtitle) : null,
              trailing: Checkbox(
                value: checked,
                onChanged: (v) {
                  ref.read(_forwardSelectionProvider.notifier)
                      .toggleGroup(g.id);
                },
              ),
              onTap: () {
                // Toggle selection when tapped
                ref.read(_forwardSelectionProvider.notifier)
                    .toggleGroup(g.id);
              },
            );
          },
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                            Selection State                                  */
/* -------------------------------------------------------------------------- */

final _forwardSelectionProvider =
    StateNotifierProvider.autoDispose<_ForwardSelection, _ForwardSelectionState>(
  (_) => _ForwardSelection(),
);

class _ForwardSelectionState {
  final Set<int> conversations;
  final Set<int> groups;
  final bool savedMessagesSelected;

  const _ForwardSelectionState({
    this.conversations = const {},
    this.groups = const {},
    this.savedMessagesSelected = false,
  });
}

class _ForwardSelection extends StateNotifier<_ForwardSelectionState> {
  _ForwardSelection() : super(const _ForwardSelectionState());

  void toggleConversation(int id) {
    final next = {...state.conversations};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = _ForwardSelectionState(
      conversations: next,
      groups: state.groups,
      savedMessagesSelected: state.savedMessagesSelected,
    );
  }

  void toggleGroup(int id) {
    final next = {...state.groups};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = _ForwardSelectionState(
      conversations: state.conversations,
      groups: next,
      savedMessagesSelected: state.savedMessagesSelected,
    );
  }

  void toggleSavedMessages() {
    state = _ForwardSelectionState(
      conversations: state.conversations,
      groups: state.groups,
      savedMessagesSelected: !state.savedMessagesSelected,
    );
  }

  void clear() {
    state = const _ForwardSelectionState();
  }
}

/* -------------------------------------------------------------------------- */
/*                                   Status                                   */
/* -------------------------------------------------------------------------- */

class _StatusTab extends ConsumerStatefulWidget {
  final Message message;
  
  const _StatusTab({required this.message});

  @override
  ConsumerState<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends ConsumerState<_StatusTab> {
  bool _isPosting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Only allow text messages to be shared to status
    final canShareToStatus = widget.message.body.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share to Status',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Post this message as a text status update visible to your contacts.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          
          // Preview of the message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.message.body.isNotEmpty 
                      ? widget.message.body 
                      : '[Media message - cannot share to status]',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: widget.message.body.isEmpty ? FontStyle.italic : null,
                    color: widget.message.body.isEmpty 
                        ? theme.colorScheme.onSurfaceVariant 
                        : null,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Share to Status button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canShareToStatus && !_isPosting 
                  ? _shareToStatus 
                  : null,
              icon: _isPosting 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: Text(_isPosting ? 'Posting...' : 'Share to Status'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          
          if (!canShareToStatus) ...[
            const SizedBox(height: 8),
            Text(
              'Only text messages can be shared to status.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _shareToStatus() async {
    setState(() => _isPosting = true);
    
    try {
      final statusRepo = ref.read(statusRepositoryProvider);
      await statusRepo.createTextStatus(text: widget.message.body);
      
      if (!mounted) return;
      Navigator.pop(context, {'sharedToStatus': true});
            context.showErrorToast('Shared to your status');    } catch (e) {
      debugPrint('Error sharing to status: $e');
      if (!mounted) return;
            context.showErrorToast('Failed to share: ${e.toString()}');    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }
}
