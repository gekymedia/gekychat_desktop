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

  final path = s.startsWith('/') ? s : '/$s';
  return '$serverRoot$path';
}
