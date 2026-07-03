import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves avatar paths from inbox payloads and API-relative storage URLs.
class NotificationAvatarHelper {
  NotificationAvatarHelper._();

  static String? get _storageOrigin {
    var base = dotenv.env['API_BASE_URL']?.trim();
    if (base == null || base.isEmpty) return null;
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final lower = base.toLowerCase();
    if (lower.endsWith('/api/v1')) {
      base = base.substring(0, base.length - '/api/v1'.length);
    } else if (lower.endsWith('/api')) {
      base = base.substring(0, base.length - '/api'.length);
    }
    return base;
  }

  static String? resolveAvatarUrl(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final origin = _storageOrigin;
    if (origin == null) return null;
    var path = value.startsWith('/') ? value.substring(1) : value;
    if (path.startsWith('storage/')) {
      return '$origin/$path';
    }
    return '$origin/storage/$path';
  }

  static String? avatarFromMessageMap(Map<String, dynamic> messageMap) {
    final sender = messageMap['sender'];
    if (sender is Map) {
      for (final key in ['avatar_url', 'avatar_path', 'avatar', 'photo']) {
        final resolved = resolveAvatarUrl(sender[key]?.toString());
        if (resolved != null) return resolved;
      }
    }

    for (final key in [
      'sender_avatar_url',
      'sender_avatar',
      'sender_avatar_path',
      'avatar_url',
    ]) {
      final resolved = resolveAvatarUrl(messageMap[key]?.toString());
      if (resolved != null) return resolved;
    }

    final otherUser = messageMap['other_user'];
    if (otherUser is Map) {
      for (final key in ['avatar_url', 'avatar_path', 'avatar']) {
        final resolved = resolveAvatarUrl(otherUser[key]?.toString());
        if (resolved != null) return resolved;
      }
    }

    return null;
  }
}
