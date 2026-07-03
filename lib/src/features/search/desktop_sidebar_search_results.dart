import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chats/chat_providers.dart';

/// Normalizes API search payload into section buckets (matches mobile + SearchScreen).
Map<String, List<Map<String, dynamic>>> normalizeSidebarSearchResults(
  Map<String, dynamic>? raw,
) {
  if (raw == null) return {};
  final resultsRaw = raw['results'];
  if (resultsRaw is List) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in resultsRaw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final type = map['type']?.toString() ?? 'unknown';
      final bucket = switch (type) {
        'contact' => 'contacts',
        'user' => 'users',
        'group' => 'groups',
        'message' => 'messages',
        'conversation' => 'conversations',
        _ => 'other',
      };
      grouped.putIfAbsent(bucket, () => []).add(map);
    }
    return grouped;
  }
  if (resultsRaw is Map) {
    return Map<String, List<Map<String, dynamic>>>.from(
      resultsRaw.map(
        (key, value) => MapEntry(
          key.toString(),
          (value is List ? value : [value])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        ),
      ),
    );
  }
  return {};
}

typedef SidebarSearchSelectConversation = Future<void> Function(
  int conversationId, {
  int? messageId,
});
typedef SidebarSearchSelectGroup = Future<void> Function(
  int groupId, {
  int? messageId,
});

/// In-sidebar global search results (WhatsApp-style — same pane as the chat list).
class DesktopSidebarSearchResults extends ConsumerWidget {
  final String query;
  final Map<String, dynamic>? results;
  final bool isSearching;
  final SidebarSearchSelectConversation onSelectConversation;
  final SidebarSearchSelectGroup onSelectGroup;

  const DesktopSidebarSearchResults({
    super.key,
    required this.query,
    required this.results,
    required this.isSearching,
    required this.onSelectConversation,
    required this.onSelectGroup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results == null) {
      return Center(
        child: Text(
          'Type to search chats, contacts, and messages',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      );
    }

    final grouped = normalizeSidebarSearchResults(results);
    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No results for "$query"',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final conversationItems = grouped['conversations'] ?? const [];
    final contactItems = [
      ...?grouped['contacts'],
      ...?grouped['users'],
    ];
    final groupItems = grouped['groups'] ?? const [];
    final messageItems = grouped['messages'] ?? const [];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (conversationItems.isNotEmpty)
          ..._section(
            context,
            ref,
            isDark,
            'Chats',
            Icons.chat,
            conversationItems,
            'conversations',
          ),
        if (contactItems.isNotEmpty)
          ..._section(
            context,
            ref,
            isDark,
            'Contacts',
            Icons.person,
            contactItems,
            'contacts',
          ),
        if (groupItems.isNotEmpty)
          ..._section(
            context,
            ref,
            isDark,
            'Groups',
            Icons.group,
            groupItems,
            'groups',
          ),
        if (messageItems.isNotEmpty)
          ..._section(
            context,
            ref,
            isDark,
            'Messages',
            Icons.message,
            messageItems,
            'messages',
          ),
      ],
    );
  }

  List<Widget> _section(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    String title,
    IconData icon,
    List<Map<String, dynamic>> items,
    String sectionKind,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
      ...items.map(
        (item) => _resultTile(context, ref, isDark, item, sectionKind),
      ),
    ];
  }

  Widget _resultTile(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    Map<String, dynamic> item,
    String sectionKind,
  ) {
    final name = _itemName(item);
    final subtitle = _itemSubtitle(item);
    final avatarUrl = _itemAvatar(item);

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: isDark ? const Color(0xFF2A3942) : Colors.grey[300],
        backgroundImage:
            avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
        child: avatarUrl == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 14),
              )
            : null,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            )
          : null,
      onTap: () => _onTap(context, ref, item, sectionKind),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
    String sectionKind,
  ) async {
    try {
      final type = item['type']?.toString();
      if (type == 'group' || sectionKind == 'groups') {
        final groupId = _parseGroupId(item);
        if (groupId != null) await onSelectGroup(groupId);
        return;
      }

      if (type == 'message' || sectionKind == 'messages') {
        final messageId = _parseMessageId(item);
        final groupId = _parseGroupId(item);
        final conversationId = _parseConversationId(item);
        if (groupId != null) {
          await onSelectGroup(groupId, messageId: messageId);
        } else if (conversationId != null) {
          await onSelectConversation(conversationId, messageId: messageId);
        }
        return;
      }

      final conversationId = _parseConversationId(item);
      if (conversationId != null) {
        await onSelectConversation(conversationId);
        return;
      }

      final userId = _parseUserId(item);
      if (userId != null) {
        await _startConversation(context, ref, userId);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open result: $e')),
        );
      }
    }
  }

  Future<void> _startConversation(BuildContext context, WidgetRef ref, int userId) async {
    final chatRepo = ref.read(chatRepositoryProvider);
    final conversations = await chatRepo.getConversations();
    for (final c in conversations) {
      if (c.otherUser.id == userId) {
        await onSelectConversation(c.id);
        return;
      }
    }
    final conversationId = await chatRepo.startConversation(userId);
    await onSelectConversation(conversationId);
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static int? _parseConversationId(Map<String, dynamic> item) {
    final direct = _asInt(item['conversation_id']);
    if (direct != null) return direct;
    if (item['conversation'] is Map) {
      return _asInt((item['conversation'] as Map)['id']);
    }
    final id = item['id']?.toString();
    if (id != null && id.startsWith('conversation_')) {
      return int.tryParse(id.replaceFirst('conversation_', ''));
    }
    return null;
  }

  static int? _parseGroupId(Map<String, dynamic> item) {
    final direct = _asInt(item['group_id']);
    if (direct != null) return direct;
    if (item['group'] is Map) {
      return _asInt((item['group'] as Map)['id']);
    }
    final id = item['id']?.toString();
    if (id != null && id.startsWith('group_')) {
      return int.tryParse(id.replaceFirst('group_', ''));
    }
    return _asInt(item['id']);
  }

  static int? _parseMessageId(Map<String, dynamic> item) {
    final direct = _asInt(item['message_id']);
    if (direct != null) return direct;
    if (item['message'] is Map) {
      final nested = _asInt((item['message'] as Map)['id']);
      if (nested != null) return nested;
    }
    final id = item['id']?.toString();
    if (id != null && id.startsWith('message_')) {
      return int.tryParse(id.replaceFirst('message_', ''));
    }
    return null;
  }

  static int? _parseUserId(Map<String, dynamic> item) {
    if (item['user'] is Map) {
      final id = _asInt((item['user'] as Map)['id']);
      if (id != null) return id;
    }
    final id = item['id']?.toString();
    if (id != null && id.startsWith('user_')) {
      return int.tryParse(id.replaceFirst('user_', ''));
    }
    return _asInt(item['user_id'] ?? item['id']);
  }

  static String _itemName(Map<String, dynamic> item) {
    var name = item['name']?.toString() ??
        item['display_name']?.toString() ??
        item['conversation_name']?.toString() ??
        item['title']?.toString();
    if ((name == null || name.isEmpty) && item['user'] is Map) {
      name = (item['user'] as Map)['name']?.toString();
    }
    if ((name == null || name.isEmpty) && item['conversation'] is Map) {
      name = (item['conversation'] as Map)['title']?.toString();
    }
    if ((name == null || name.isEmpty) && item['contact'] is Map) {
      name = (item['contact'] as Map)['display_name']?.toString();
    }
    if ((name == null || name.isEmpty) && item['group'] is Map) {
      name = (item['group'] as Map)['name']?.toString();
    }
    return name?.isNotEmpty == true ? name! : 'Unknown';
  }

  static String _itemSubtitle(Map<String, dynamic> item) {
    final body = item['body']?.toString() ??
        item['snippet']?.toString() ??
        item['last_message']?.toString() ??
        item['match_snippet']?.toString();
    if (body != null && body.isNotEmpty) return body;
    if (item['message'] is Map) {
      final nested = (item['message'] as Map)['body']?.toString();
      if (nested != null && nested.isNotEmpty) return nested;
    }
    final phone = item['phone']?.toString();
    if (phone != null && phone.isNotEmpty) return phone;
    if (item['user'] is Map) {
      return (item['user'] as Map)['phone']?.toString() ?? '';
    }
    return '';
  }

  static String? _itemAvatar(Map<String, dynamic> item) {
    final direct = item['avatar_url']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    if (item['user'] is Map) {
      return (item['user'] as Map)['avatar_url']?.toString();
    }
    if (item['group'] is Map) {
      return (item['group'] as Map)['avatar_url']?.toString();
    }
    return null;
  }
}
