import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolve a relative storage path (e.g. `storage/avatars/abc.jpg`) returned
/// by some API endpoints into a fully-qualified URL.
///
/// If [raw] is already an absolute URL (starts with `http`) it is returned unchanged.
/// If [raw] is null / empty, null is returned.
String? resolveStorageUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final s = raw.trim();
  if (s.startsWith('http://') || s.startsWith('https://')) return s;

  // Derive the server root from API_BASE_URL (strip /api/v1 suffix)
  final apiBase = dotenv.env['API_BASE_URL'] ?? '';
  if (apiBase.isEmpty) return s; // can't resolve without config
  final serverRoot = apiBase
      .replaceAll(RegExp(r'/api/v1$', caseSensitive: false), '')
      .replaceAll(RegExp(r'/api$', caseSensitive: false), '')
      .replaceAll(RegExp(r'/$'), '');

  var path = s.startsWith('/') ? s.substring(1) : s;
  // Bare avatar/media paths from some payloads omit the `storage/` prefix.
  if (!path.startsWith('storage/')) {
    path = 'storage/$path';
  }
  return '$serverRoot/$path';
}

/// Avatar-safe resolver: absolute http(s) URLs unchanged; relative paths get
/// `{origin}/storage/...`. Returns null when unresolvable (never a relative URI).
String? resolveAvatarUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return resolveStorageUrl(value);
}
