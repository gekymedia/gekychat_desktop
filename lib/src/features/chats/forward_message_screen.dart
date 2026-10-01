import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'chat_providers.dart';
import 'models.dart';
import '../status/status_repository.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../utils/avatar_utils.dart';
import '../../utils/storage_url.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/desktop_center_modal.dart';

ImageProvider? _avatarImageProvider(String? url) {
  final resolved = resolveStorageUrl(url);
  if (resolved == null || resolved.trim().isEmpty) return null;
  return CachedNetworkImageProvider(resolved);
}

const _brand = Color(0xFF008069);

enum _ForwardFilter { recent, chats, groups, status }

class ForwardMessageScreen extends ConsumerStatefulWidget {
  final List<Message> messages;
  final bool forModal;

  ForwardMessageScreen({
    super.key,
    required Message message,
    this.forModal = false,
  }) : messages = [message];

  const ForwardMessageScreen.multiple({
    super.key,
    required this.messages,
    this.forModal = false,
  });

  Message get primaryMessage => messages.first;

  static Future<void> showModal(BuildContext context, Message message) {
    return showDesktopCenterModal<void>(
      context: context,
      title: 'Forward message to',
      maxWidth: 520,
      maxHeightFraction: 0.88,
      barrierOpacity: 0.55,
      child: ForwardMessageScreen(message: message, forModal: true),
    );
  }

  static Future<void> showModalForMessages(
    BuildContext context,
    List<Message> messages,
  ) {
    if (messages.isEmpty) return Future.value();
    final title = messages.length == 1
        ? 'Forward message to'
        : 'Forward ${messages.length} messages to';
    return showDesktopCenterModal<void>(
      context: context,
      title: title,
      maxWidth: 520,
      maxHeightFraction: 0.88,
      barrierOpacity: 0.55,
      child: ForwardMessageScreen.multiple(
        messages: messages,
        forModal: true,
      ),
    );
  }

  @override
  ConsumerState<ForwardMessageScreen> createState() =>
      _ForwardMessageScreenState();
}

class _ForwardMessageScreenState
    extends ConsumerState<ForwardMessageScreen> {
  bool _isLoading = false;
  bool _isBootstrapping = true;
  bool _isPostingStatus = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ForwardFilter _filter = _ForwardFilter.recent;

  List<ConversationSummary> _conversations = [];
  List<GroupSummary> _groups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(_forwardSelectionProvider.notifier).clear();
      _bootstrapRecipients();
    });
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
  }

  Future<void> _bootstrapRecipients() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final results = await Future.wait([
        repo.getConversations(),
        repo.getGroups(),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations = results[0] as List<ConversationSummary>;
        _groups = results[1] as List<GroupSummary>;
        _isBootstrapping = false;
      });
    } catch (e) {
      debugPrint('Forward recipients load failed: $e');
      if (!mounted) return;
      setState(() => _isBootstrapping = false);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(String name, {String? phone, String? username}) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.startsWith('@') ? _searchQuery.substring(1) : _searchQuery;
    return name.toLowerCase().contains(q) ||
        (phone?.toLowerCase().contains(q) ?? false) ||
        (username?.toLowerCase().contains(q) ?? false);
  }

  List<ConversationSummary> get _filteredConversations {
    final hasSaved = _conversations.any((c) => c.isSavedMessages);
    var list = List<ConversationSummary>.from(_conversations)
      ..sort((a, b) {
        if (a.isSavedMessages && !b.isSavedMessages) return -1;
        if (!a.isSavedMessages && b.isSavedMessages) return 1;
        final aT = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bT = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bT.compareTo(aT);
      });

    if (!hasSaved &&
        (_searchQuery.isEmpty || 'saved messages'.contains(_searchQuery))) {
      // Synthetic entry is rendered separately; keep list as-is.
    }

    return list.where((c) {
      final name =
          c.isSavedMessages ? 'saved messages' : c.otherUser.name.toLowerCase();
      return _matchesQuery(
        name,
        phone: c.otherUser.phone,
      );
    }).toList();
  }

  List<GroupSummary> get _filteredGroups {
    return _groups.where((g) => _matchesQuery(g.name)).toList();
  }

  bool get _showSyntheticSaved {
    final hasSaved = _conversations.any((c) => c.isSavedMessages);
    return !hasSaved &&
        (_searchQuery.isEmpty || 'saved messages'.contains(_searchQuery));
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(_forwardSelectionProvider);
    final hasSelection = selection.conversations.isNotEmpty ||
        selection.groups.isNotEmpty ||
        selection.savedMessagesSelected;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator(color: _brand))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search name, number or @username',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white54
                          : const Color(0xFF667781),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark
                          ? Colors.white54
                          : const Color(0xFF667781),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF202C33)
                        : const Color(0xFFF0F2F5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: _brand, width: 1.5),
                    ),
                  ),
                ),
              ),
              if (hasSelection) _SelectedChipsRow(
                conversations: _conversations,
                groups: _groups,
              ),
              _FilterChips(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
                isDark: isDark,
              ),
              Expanded(
                child: _isBootstrapping
                    ? const Center(
                        child: CircularProgressIndicator(color: _brand),
                      )
                    : _filter == _ForwardFilter.status
                        ? _StatusSharePane(
                            message: widget.primaryMessage,
                            isPosting: _isPostingStatus,
                            onShare: _shareToStatus,
                          )
                        : _RecipientList(
                            filter: _filter,
                            conversations: _filteredConversations,
                            groups: _filteredGroups,
                            showSyntheticSaved: _showSyntheticSaved,
                            showMyStatusRow: _searchQuery.isEmpty,
                            onShareToStatus: _shareToStatus,
                            isPostingStatus: _isPostingStatus,
                          ),
              ),
              _MessagePreviewBar(messages: widget.messages, isDark: isDark),
              if (widget.forModal)
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: hasSelection
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FloatingActionButton(
                              heroTag: 'forward_send_fab',
                              backgroundColor: _brand,
                              onPressed: _isLoading ? null : _forward,
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(height: 8),
                ),
            ],
          );

    if (widget.forModal) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forward message to'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: (!hasSelection || _isLoading)
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                  : _brand,
            ),
            onPressed: (!hasSelection || _isLoading) ? null : _forward,
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _shareToStatus() async {
    if (_isPostingStatus) return;
    final message = widget.primaryMessage;
    if (message.body.trim().isEmpty) {
      if (!mounted) return;
      context.showInfoToast('Only text messages can be shared to status.');
      return;
    }
    setState(() => _isPostingStatus = true);
    try {
      final statusRepo = ref.read(statusRepositoryProvider);
      await statusRepo.createTextStatus(text: message.body);
      if (!mounted) return;
      Navigator.pop(context, {'sharedToStatus': true});
      context.showInfoToast('Shared to your status');
    } catch (e) {
      debugPrint('Error sharing to status: $e');
      if (!mounted) return;
      context.showErrorToast('Failed to share: $e');
    } finally {
      if (mounted) setState(() => _isPostingStatus = false);
    }
  }

  Future<void> _forward() async {
    final networkStatus = ref.read(connectivityProvider);
    if (!networkStatus) {
      if (!mounted) return;
      context.showInfoToast(
        'Cannot forward message while offline. Please check your connection and try again.',
      );
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(chatRepositoryProvider);
    final selection = ref.read(_forwardSelectionProvider);

    try {
      final targets = <Map<String, dynamic>>[];
      final forwardedConversationIds = <int>{...selection.conversations};

      if (selection.savedMessagesSelected) {
        final conversations = _conversations.isNotEmpty
            ? _conversations
            : await repo.getConversations();
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

      for (final id in forwardedConversationIds) {
        targets.add({'type': 'conversation', 'id': id});
      }
      for (final id in selection.groups) {
        targets.add({'type': 'group', 'id': id});
      }

      if (targets.isEmpty) {
        throw Exception('No recipients selected');
      }

      for (final message in widget.messages) {
        await repo.forwardMessage(message.id, targets);
      }

      if (!mounted) return;
      Navigator.pop(context, {
        'conversations': forwardedConversationIds.toList(),
        'groups': selection.groups.toList(),
        'savedMessages': selection.savedMessagesSelected,
      });
      final msgCount = widget.messages.length;
      final recipientLabel =
          '${targets.length} ${targets.length == 1 ? 'recipient' : 'recipients'}';
      if (msgCount == 1) {
        context.showInfoToast('Message forwarded to $recipientLabel');
      } else {
        context.showInfoToast(
          '$msgCount messages forwarded to $recipientLabel',
        );
      }
    } catch (e) {
      debugPrint('Error forwarding message: $e');
      if (!mounted) return;
      var errorMessage = 'Failed to forward message';
      final raw = e.toString();
      if (raw.contains('SocketException') || raw.contains('Connection')) {
        errorMessage =
            'No internet connection. Please try again when online.';
      } else if (raw.contains('404')) {
        errorMessage = 'Message not found. It may have been deleted.';
      } else if (raw.contains('403')) {
        errorMessage = 'You do not have permission to forward this message.';
      }
      context.showErrorToast(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

/* -------------------------------------------------------------------------- */
/*                              Filter chips                                   */
/* -------------------------------------------------------------------------- */

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.onChanged,
    required this.isDark,
  });

  final _ForwardFilter filter;
  final ValueChanged<_ForwardFilter> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _ForwardFilter value) {
      final active = filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: active,
          onSelected: (_) => onChanged(value),
          selectedColor: _brand.withValues(alpha: isDark ? 0.28 : 0.14),
          labelStyle: TextStyle(
            color: active
                ? (isDark ? Colors.white : _brand)
                : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
          side: BorderSide(
            color: active
                ? _brand
                : (isDark ? Colors.white24 : const Color(0xFFD1D7DB)),
          ),
          backgroundColor: Colors.transparent,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('Recent', _ForwardFilter.recent),
          chip('Chats', _ForwardFilter.chats),
          chip('Groups', _ForwardFilter.groups),
          chip('Status', _ForwardFilter.status),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                            Selected chips                                   */
/* -------------------------------------------------------------------------- */

class _SelectedChipsRow extends ConsumerWidget {
  const _SelectedChipsRow({
    required this.conversations,
    required this.groups,
  });

  final List<ConversationSummary> conversations;
  final List<GroupSummary> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(_forwardSelectionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chips = <Widget>[];

    if (selection.savedMessagesSelected) {
      chips.add(
        _RecipientChip(
          label: 'Saved Messages',
          avatar: _ChipAvatar.icon(Icons.bookmark),
          onDeleted: () =>
              ref.read(_forwardSelectionProvider.notifier).toggleSavedMessages(),
          isDark: isDark,
        ),
      );
    }

    for (final id in selection.conversations) {
      ConversationSummary? c;
      for (final x in conversations) {
        if (x.id == id) {
          c = x;
          break;
        }
      }
      final name = c == null
          ? 'Chat'
          : (c.isSavedMessages ? 'Saved Messages' : c.otherUser.name);
      final avatarUrl =
          c?.isSavedMessages == true ? null : c?.otherUser.avatarUrl;
      chips.add(
        _RecipientChip(
          label: name,
          avatar: c?.isSavedMessages == true
              ? _ChipAvatar.icon(Icons.bookmark)
              : _ChipAvatar.urlOrInitial(name, avatarUrl),
          onDeleted: () => ref
              .read(_forwardSelectionProvider.notifier)
              .toggleConversation(id),
          isDark: isDark,
        ),
      );
    }

    for (final id in selection.groups) {
      GroupSummary? g;
      for (final x in groups) {
        if (x.id == id) {
          g = x;
          break;
        }
      }
      final name = g?.name ?? 'Group';
      chips.add(
        _RecipientChip(
          label: name,
          avatar: _ChipAvatar.urlOrInitial(
            name,
            g?.avatarUrl,
            fallbackIcon: g?.type == 'channel' ? Icons.campaign : Icons.groups,
          ),
          onDeleted: () =>
              ref.read(_forwardSelectionProvider.notifier).toggleGroup(id),
          isDark: isDark,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

class _ChipAvatar {
  final ImageProvider? image;
  final String? initial;
  final IconData? icon;
  final Color? color;

  const _ChipAvatar._({this.image, this.initial, this.icon, this.color});

  factory _ChipAvatar.icon(IconData icon) =>
      _ChipAvatar._(icon: icon, color: _brand);

  factory _ChipAvatar.urlOrInitial(
    String name,
    String? url, {
    IconData? fallbackIcon,
  }) {
    final img = _avatarImageProvider(url);
    if (img != null) return _ChipAvatar._(image: img);
    if (fallbackIcon != null) {
      return _ChipAvatar._(
        icon: fallbackIcon,
        color: AvatarUtils.getColorForName(name),
      );
    }
    return _ChipAvatar._(
      initial: name.isNotEmpty ? name[0].toUpperCase() : '?',
      color: AvatarUtils.getColorForName(name),
    );
  }
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({
    required this.label,
    required this.avatar,
    required this.onDeleted,
    required this.isDark,
  });

  final String label;
  final _ChipAvatar avatar;
  final VoidCallback onDeleted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: CircleAvatar(
        backgroundColor: avatar.color ?? _brand,
        backgroundImage: avatar.image,
        child: avatar.image != null
            ? null
            : (avatar.icon != null
                ? Icon(avatar.icon, size: 14, color: Colors.white)
                : Text(
                    avatar.initial ?? '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  )),
      ),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      onDeleted: onDeleted,
      deleteIconColor: isDark ? Colors.white70 : const Color(0xFF54656F),
      backgroundColor:
          isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                             Recipient list                                  */
/* -------------------------------------------------------------------------- */

class _RecipientList extends ConsumerWidget {
  const _RecipientList({
    required this.filter,
    required this.conversations,
    required this.groups,
    required this.showSyntheticSaved,
    required this.showMyStatusRow,
    required this.onShareToStatus,
    required this.isPostingStatus,
  });

  final _ForwardFilter filter;
  final List<ConversationSummary> conversations;
  final List<GroupSummary> groups;
  final bool showSyntheticSaved;
  final bool showMyStatusRow;
  final VoidCallback onShareToStatus;
  final bool isPostingStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(_forwardSelectionProvider);
    final entries = <_ListEntry>[];

    if (showMyStatusRow &&
        (filter == _ForwardFilter.recent || filter == _ForwardFilter.chats)) {
      entries.add(const _ListEntry.myStatus());
    }

    if (filter == _ForwardFilter.recent || filter == _ForwardFilter.chats) {
      if (showSyntheticSaved) {
        entries.add(const _ListEntry.savedSynthetic());
      }
      for (final c in conversations) {
        if (filter == _ForwardFilter.chats || filter == _ForwardFilter.recent) {
          entries.add(_ListEntry.conversation(c));
        }
      }
    }

    if (filter == _ForwardFilter.recent || filter == _ForwardFilter.groups) {
      // In Recent, interleave groups after chats (WA-style recent mixed list).
      for (final g in groups) {
        entries.add(_ListEntry.group(g));
      }
    }

    if (entries.isEmpty) {
      return Center(
        child: Text(
          filter == _ForwardFilter.groups
              ? 'No matching groups'
              : 'No matching chats',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final showRecentHeader = filter == _ForwardFilter.recent &&
        entries.any((e) => e.kind != _EntryKind.myStatus);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: entries.length + (showRecentHeader ? 1 : 0),
      itemBuilder: (context, index) {
        var i = index;
        if (showRecentHeader) {
          // Insert "Recent chats" after My status (if present).
          final statusOffset =
              entries.isNotEmpty && entries.first.kind == _EntryKind.myStatus
                  ? 1
                  : 0;
          if (index == statusOffset) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
              child: Text(
                'Recent chats',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : const Color(0xFF667781),
                ),
              ),
            );
          }
          if (index > statusOffset) i = index - 1;
        }

        final entry = entries[i];
        switch (entry.kind) {
          case _EntryKind.myStatus:
            return _HoverRow(
              onTap: isPostingStatus ? null : onShareToStatus,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: const SizedBox(width: 24), // align with checkbox column
                title: const Text('My status'),
                subtitle: const Text('My contacts'),
                trailing: isPostingStatus
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _brand,
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: _brand.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.portrait_outlined,
                          color: _brand,
                        ),
                      ),
              ),
            );
          case _EntryKind.savedSynthetic:
            final checked = selection.savedMessagesSelected;
            return _RecipientRow(
              checked: checked,
              title: 'Saved Messages (You)',
              subtitle: 'Forward to yourself',
              avatar: CircleAvatar(
                backgroundColor: _brand,
                child: const Icon(Icons.bookmark, color: Colors.white),
              ),
              onToggle: () => ref
                  .read(_forwardSelectionProvider.notifier)
                  .toggleSavedMessages(),
            );
          case _EntryKind.conversation:
            final c = entry.conversation!;
            final checked = c.isSavedMessages
                ? selection.savedMessagesSelected
                : selection.conversations.contains(c.id);
            final displayName =
                c.isSavedMessages ? 'Saved Messages (You)' : c.otherUser.name;
            final avatarImg = c.isSavedMessages
                ? null
                : _avatarImageProvider(c.otherUser.avatarUrl);
            return _RecipientRow(
              checked: checked,
              title: displayName,
              subtitle: c.isSavedMessages
                  ? 'Forward to yourself'
                  : (c.lastMessage ?? c.otherUser.phone),
              avatar: CircleAvatar(
                backgroundColor: c.isSavedMessages
                    ? _brand
                    : AvatarUtils.getColorForName(displayName),
                backgroundImage: avatarImg,
                child: c.isSavedMessages
                    ? const Icon(Icons.bookmark, color: Colors.white)
                    : (avatarImg == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          )
                        : null),
              ),
              onToggle: () {
                if (c.isSavedMessages) {
                  ref
                      .read(_forwardSelectionProvider.notifier)
                      .toggleSavedMessages();
                } else {
                  ref
                      .read(_forwardSelectionProvider.notifier)
                      .toggleConversation(c.id);
                }
              },
            );
          case _EntryKind.group:
            final g = entry.group!;
            final checked = selection.groups.contains(g.id);
            final isChannel = g.type == 'channel';
            String? subtitle = g.lastMessage;
            if ((subtitle == null || subtitle.isEmpty) &&
                g.memberCount != null &&
                g.memberCount! > 0) {
              final count = g.memberCount!;
              subtitle = isChannel
                  ? '$count ${count == 1 ? 'follower' : 'followers'}'
                  : '$count ${count == 1 ? 'member' : 'members'}';
            }
            final avatarImg = _avatarImageProvider(g.avatarUrl);
            return _RecipientRow(
              checked: checked,
              title: g.name,
              subtitle: subtitle,
              avatar: CircleAvatar(
                backgroundColor: isChannel
                    ? Theme.of(context).colorScheme.secondary
                    : AvatarUtils.getColorForName(g.name),
                backgroundImage: avatarImg,
                child: avatarImg == null
                    ? Icon(
                        isChannel ? Icons.campaign : Icons.groups,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
              onToggle: () => ref
                  .read(_forwardSelectionProvider.notifier)
                  .toggleGroup(g.id),
            );
        }
      },
    );
  }
}

enum _EntryKind { myStatus, savedSynthetic, conversation, group }

class _ListEntry {
  final _EntryKind kind;
  final ConversationSummary? conversation;
  final GroupSummary? group;

  const _ListEntry.myStatus()
      : kind = _EntryKind.myStatus,
        conversation = null,
        group = null;

  const _ListEntry.savedSynthetic()
      : kind = _EntryKind.savedSynthetic,
        conversation = null,
        group = null;

  const _ListEntry.conversation(ConversationSummary c)
      : kind = _EntryKind.conversation,
        conversation = c,
        group = null;

  const _ListEntry.group(GroupSummary g)
      : kind = _EntryKind.group,
        conversation = null,
        group = g;
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF0F2F5))
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.checked,
    required this.title,
    required this.subtitle,
    required this.avatar,
    required this.onToggle,
  });

  final bool checked;
  final String title;
  final String? subtitle;
  final Widget avatar;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _HoverRow(
      onTap: onToggle,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Checkbox(
          value: checked,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _brand;
            return null;
          }),
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null || subtitle!.isEmpty
            ? null
            : Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: avatar,
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                           Message preview bar                               */
/* -------------------------------------------------------------------------- */

class _MessagePreviewBar extends StatelessWidget {
  const _MessagePreviewBar({
    required this.messages,
    required this.isDark,
  });

  final List<Message> messages;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primary = messages.first;
    final meta = _previewMeta(primary);
    final caption = _previewCaption(primary, messages.length);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (meta.thumbnailUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: meta.thumbnailUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _typeIconBox(meta.icon),
              ),
            ),
            const SizedBox(width: 10),
          ] else ...[
            _typeIconBox(meta.icon),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(meta.icon, size: 16, color: _brand),
                    const SizedBox(width: 6),
                    Text(
                      meta.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (messages.length > 1) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${messages.length}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF667781),
                        ),
                      ),
                    ],
                  ],
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF667781),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeIconBox(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: _brand),
    );
  }

  static ({String label, IconData icon, String? thumbnailUrl}) _previewMeta(
    Message message,
  ) {
    final att = message.attachments.isNotEmpty ? message.attachments.first : null;
    if (att != null) {
      if (att.isImage) {
        return (
          label: 'Photo',
          icon: Icons.photo_camera_outlined,
          thumbnailUrl: att.thumbnailUrl ?? att.url,
        );
      }
      if (att.isVideo) {
        return (
          label: 'Video',
          icon: Icons.videocam_outlined,
          thumbnailUrl: att.thumbnailUrl,
        );
      }
      if (att.isAudio) {
        return (
          label: att.isVoicenote ? 'Voice message' : 'Audio',
          icon: Icons.mic_none_outlined,
          thumbnailUrl: null,
        );
      }
      if (att.isDocument) {
        return (
          label: 'Document',
          icon: Icons.insert_drive_file_outlined,
          thumbnailUrl: null,
        );
      }
    }
    if (message.locationData != null) {
      return (label: 'Location', icon: Icons.location_on_outlined, thumbnailUrl: null);
    }
    if (message.contactData != null) {
      return (label: 'Contact', icon: Icons.person_outline, thumbnailUrl: null);
    }
    if (message.pollData != null) {
      return (label: 'Poll', icon: Icons.poll_outlined, thumbnailUrl: null);
    }
    return (label: 'Message', icon: Icons.chat_bubble_outline, thumbnailUrl: null);
  }

  static String _previewCaption(Message message, int count) {
    if (count > 1) return '$count messages selected';
    final body = message.body.trim();
    if (body.isNotEmpty) return body;
    final att = message.attachments.isNotEmpty ? message.attachments.first : null;
    return att?.originalName?.trim() ?? '';
  }
}

/* -------------------------------------------------------------------------- */
/*                              Status pane                                    */
/* -------------------------------------------------------------------------- */

class _StatusSharePane extends StatelessWidget {
  const _StatusSharePane({
    required this.message,
    required this.isPosting,
    required this.onShare,
  });

  final Message message;
  final bool isPosting;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canShare = message.body.trim().isNotEmpty;

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
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              canShare
                  ? message.body
                  : '[Media message — cannot share to status]',
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: canShare ? null : FontStyle.italic,
                color: canShare ? null : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canShare && !isPosting ? onShare : null,
              icon: isPosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.share_outlined),
              label: Text(isPosting ? 'Posting...' : 'Share to Status'),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                            Selection State                                  */
/* -------------------------------------------------------------------------- */

final _forwardSelectionProvider = StateNotifierProvider.autoDispose<
    _ForwardSelection, _ForwardSelectionState>(
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
