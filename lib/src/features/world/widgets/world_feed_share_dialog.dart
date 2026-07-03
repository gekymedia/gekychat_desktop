import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../chats/chat_providers.dart';
import '../../chats/models.dart';

class WorldFeedShareTarget {
  final bool isGroup;
  final int id;
  final String title;
  final String? avatarUrl;
  final DateTime? sortAt;

  const WorldFeedShareTarget({
    required this.isGroup,
    required this.id,
    required this.title,
    this.avatarUrl,
    this.sortAt,
  });

  static List<WorldFeedShareTarget> mergeAndRank({
    required List<ConversationSummary> conversations,
    required List<GroupSummary> groups,
    required String baseUrl,
    int maxItems = 16,
  }) {
    final list = <WorldFeedShareTarget>[];
    for (final c in conversations) {
      if (c.archivedAt != null) continue;
      final u = c.otherUser;
      list.add(
        WorldFeedShareTarget(
          isGroup: false,
          id: c.id,
          title: u.name,
          avatarUrl: _resolveAvatarUrl(baseUrl, u.avatarUrl),
          sortAt: c.updatedAt,
        ),
      );
    }
    for (final g in groups) {
      list.add(
        WorldFeedShareTarget(
          isGroup: true,
          id: g.id,
          title: g.name,
          avatarUrl: _resolveAvatarUrl(baseUrl, g.avatarUrl),
          sortAt: g.updatedAt,
        ),
      );
    }
    list.sort((a, b) {
      final ta = a.sortAt;
      final tb = b.sortAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    if (list.length > maxItems) {
      return list.sublist(0, maxItems);
    }
    return list;
  }

  static String? _resolveAvatarUrl(String baseUrl, String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return '$baseUrl/storage/$raw';
  }
}

/// Result codes returned when the share dialog closes.
abstract final class WorldFeedShareResult {
  static const quickSent = 'quick_sent';
  static const gekyChat = 'gekychat';
  static const copy = 'copy';
  static const whatsapp = 'whatsapp';
  static const telegram = 'telegram';
  static const twitter = 'twitter';
  static const facebook = 'facebook';
  static const email = 'email';
  static const more = 'more';
}

Future<String?> showWorldFeedShareDialog(
  BuildContext context, {
  required String shareText,
  required String shareUrl,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => WorldFeedShareDialog(
      shareText: shareText,
      shareUrl: shareUrl,
    ),
  );
}

class WorldFeedShareDialog extends ConsumerStatefulWidget {
  final String shareText;
  final String shareUrl;

  const WorldFeedShareDialog({
    super.key,
    required this.shareText,
    required this.shareUrl,
  });

  @override
  ConsumerState<WorldFeedShareDialog> createState() =>
      _WorldFeedShareDialogState();
}

class _WorldFeedShareDialogState extends ConsumerState<WorldFeedShareDialog> {
  Future<List<dynamic>>? _loadChatsFuture;
  int? _quickSendBusyId;
  bool _quickSendBusyIsGroup = false;

  Future<void> _sendQuick(WorldFeedShareTarget target) async {
    setState(() {
      _quickSendBusyId = target.id;
      _quickSendBusyIsGroup = target.isGroup;
    });
    final repo = ref.read(chatRepositoryProvider);
    try {
      if (target.isGroup) {
        await repo.sendMessageToGroup(
          groupId: target.id,
          body: widget.shareText,
        );
      } else {
        await repo.sendMessageToConversation(
          conversationId: target.id,
          body: widget.shareText,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, WorldFeedShareResult.quickSent);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _quickSendBusyId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF202C33) : Colors.white;
    final fg = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? Colors.white54 : (Colors.grey[600] ?? Colors.grey);
    final baseUrl = ref.read(apiServiceProvider).baseUrl;

    _loadChatsFuture ??= Future.wait([
      ref.read(chatRepositoryProvider).getConversations(),
      ref.read(chatRepositoryProvider).getGroups(),
    ]);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Share post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: muted),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<dynamic>>(
                future: _loadChatsFuture,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: muted,
                          ),
                        ),
                      ),
                    );
                  }
                  final conv = snap.data![0] as List<ConversationSummary>;
                  final gr = snap.data![1] as List<GroupSummary>;
                  final targets = WorldFeedShareTarget.mergeAndRank(
                    conversations: conv,
                    groups: gr,
                    baseUrl: baseUrl,
                  );
                  if (targets.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send to recent chats',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: targets.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final t = targets[i];
                            final busy = _quickSendBusyId == t.id &&
                                _quickSendBusyIsGroup == t.isGroup;
                            return InkWell(
                              onTap: busy ? null : () => _sendQuick(t),
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 72,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: (t.isGroup
                                                  ? Colors.teal
                                                  : AppTheme.primaryGreen)
                                              .withValues(alpha: 0.25),
                                          backgroundImage: t.avatarUrl != null
                                              ? CachedNetworkImageProvider(
                                                  t.avatarUrl!,
                                                )
                                              : null,
                                          child: t.avatarUrl == null
                                              ? Text(
                                                  t.title.isNotEmpty
                                                      ? t.title[0].toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    color: fg,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 20,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        if (busy)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.black38,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      t.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 11, color: fg),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              Text(
                'Share on GekyChat or other apps',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _ShareAction(
                    icon: Icons.chat_rounded,
                    label: 'GekyChat',
                    color: AppTheme.primaryGreen,
                    onTap: () => Navigator.pop(
                      context,
                      WorldFeedShareResult.gekyChat,
                    ),
                  ),
                  _ShareAction(
                    icon: Icons.copy,
                    label: 'Copy link',
                    color: muted,
                    onTap: () => Navigator.pop(
                      context,
                      WorldFeedShareResult.copy,
                    ),
                  ),
                  _ShareAction(
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    child: const Text(
                      'WA',
                      style: TextStyle(
                        color: Color(0xFF25D366),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      WorldFeedShareResult.whatsapp,
                    ),
                  ),
                  _ShareAction(
                    label: 'Telegram',
                    color: const Color(0xFF0088CC),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF0088CC),
                      size: 26,
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      WorldFeedShareResult.telegram,
                    ),
                  ),
                  _ShareAction(
                    icon: Icons.alternate_email,
                    label: 'X',
                    color: fg,
                    onTap: () => Navigator.pop(
                      context,
                      WorldFeedShareResult.twitter,
                    ),
                  ),
                  _ShareAction(
                    icon: Icons.facebook,
                    label: 'Facebook',
                    color: const Color(0xFF1877F2),
                    onTap: () => Navigator.pop(
                      context,
                      WorldFeedShareResult.facebook,
                    ),
                  ),
                  _ShareAction(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    color: muted,
                    onTap: () => Navigator.pop(
                      context,
                      WorldFeedShareResult.email,
                    ),
                  ),
                  _ShareAction(
                    icon: Icons.ios_share,
                    label: 'More',
                    color: muted,
                    onTap: () => Navigator.pop(
                      context,
                      WorldFeedShareResult.more,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Tap a chat above to send instantly, or pick GekyChat to choose multiple chats.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareAction({
    this.icon,
    this.child,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: child ??
                      Icon(icon, size: 26, color: color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
