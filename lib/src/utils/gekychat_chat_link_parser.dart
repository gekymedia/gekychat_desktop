import 'world_feed_link_navigation.dart';

/// Types of GekyChat deep links we surface in chat bubbles.
enum GekychatChatLinkKind {
  worldFeed,
  groupJoin,
  groupOpen,
  channel,
}

/// First matching special GekyChat link found in [body] (URL order in text).
class GekychatChatLinkMatch {
  const GekychatChatLinkMatch({
    required this.kind,
    required this.matchedUrl,
    this.groupId,
    this.inviteCode,
    this.channelId,
  });

  final GekychatChatLinkKind kind;
  final String matchedUrl;
  final int? groupId;
  final String? inviteCode;
  final int? channelId;
}

final RegExp _urlExtract = RegExp(
  r'(https?://[^\s<>\[\]()]+|gekychat://[^\s<>\[\]()]+)',
  caseSensitive: false,
);

String _trimTrailingPunctuation(String s) {
  var t = s.trim();
  while (t.isNotEmpty && ').,;]'.contains(t[t.length - 1])) {
    t = t.substring(0, t.length - 1);
  }
  return t;
}

Iterable<String> _urlsInText(String body) sync* {
  for (final m in _urlExtract.allMatches(body)) {
    final u = _trimTrailingPunctuation(m.group(0)!);
    if (u.isNotEmpty) yield u;
  }
}

/// Returns the first URL in [body] that should get a custom bubble / CTA.
GekychatChatLinkMatch? parseFirstGekychatSpecialLink(String? body) {
  if (body == null || body.trim().isEmpty) return null;

  for (final raw in _urlsInText(body)) {
    if (looksLikeGekychatWorldFeedNavigationUrl(raw)) {
      return GekychatChatLinkMatch(
        kind: GekychatChatLinkKind.worldFeed,
        matchedUrl: raw,
      );
    }

    final uri = Uri.tryParse(raw);
    if (uri == null) continue;

    final host = uri.host.toLowerCase();
    final path = uri.path;

    if (host == 'chat.gekychat.com' || host == 'web.gekychat.com') {
      if (path.contains('/groups/join/')) {
        final parts = path.split('/').where((s) => s.isNotEmpty).toList();
        final idx = parts.indexOf('join');
        if (idx >= 0 && idx + 1 < parts.length) {
          final code = parts[idx + 1];
          if (code.isNotEmpty) {
            return GekychatChatLinkMatch(
              kind: GekychatChatLinkKind.groupJoin,
              matchedUrl: raw,
              inviteCode: code,
            );
          }
        }
      }

      final gDirect = RegExp(r'^/g/(\d+)(/|\?|$)').firstMatch(path);
      if (gDirect != null) {
        final id = int.tryParse(gDirect.group(1)!);
        if (id != null) {
          return GekychatChatLinkMatch(
            kind: GekychatChatLinkKind.groupOpen,
            matchedUrl: raw,
            groupId: id,
          );
        }
      }

      final ch = RegExp(r'^/channels/(\d+)').firstMatch(path);
      if (ch != null) {
        final id = int.tryParse(ch.group(1)!);
        if (id != null) {
          return GekychatChatLinkMatch(
            kind: GekychatChatLinkKind.channel,
            matchedUrl: raw,
            channelId: id,
          );
        }
      }
    }

    if (uri.scheme == 'gekychat') {
      if (uri.host == 'group' && uri.pathSegments.isNotEmpty) {
        final id = int.tryParse(uri.pathSegments.first);
        if (id != null) {
          return GekychatChatLinkMatch(
            kind: GekychatChatLinkKind.groupOpen,
            matchedUrl: raw,
            groupId: id,
          );
        }
      }
      if (uri.host == 'channel' && uri.pathSegments.isNotEmpty) {
        final id = int.tryParse(uri.pathSegments.first);
        if (id != null) {
          return GekychatChatLinkMatch(
            kind: GekychatChatLinkKind.channel,
            matchedUrl: raw,
            channelId: id,
          );
        }
      }
    }
  }
  return null;
}
