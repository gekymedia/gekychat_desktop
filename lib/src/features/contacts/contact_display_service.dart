// lib/src/features/contacts/contact_display_service.dart
//
// Desktop contact name / phone resolution service.
//
// On desktop there is no local contacts DB (unlike mobile), so we maintain
// an in-memory map that is populated from the server `/contacts` list.
// Falls back to the standard User.name API field when no contact entry exists.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'contacts_repository.dart';
import '../../utils/phone_matcher.dart';

final contactDisplayServiceProvider = Provider<ContactDisplayService>((ref) {
  final repo = ref.read(contactsRepositoryProvider);
  return ContactDisplayService(repo);
});

class ContactDisplayService {
  ContactDisplayService(this._repo);

  final ContactsRepository _repo;

  // userId → contact-book display name
  final Map<int, String> _nameById = {};
  // normalized phone → contact-book display name
  final Map<String, String> _nameByPhone = {};

  bool _loaded = false;

  /// Load (or reload) contacts from the server into the in-memory cache.
  /// Safe to call multiple times; subsequent calls refresh the cache.
  Future<void> warmUp({int maxPages = 5}) async {
    try {
      _nameById.clear();
      _nameByPhone.clear();
      for (var page = 1; page <= maxPages; page++) {
        final contacts = await _repo.listContacts(page: page, perPage: 100);
        for (final c in contacts) {
          final name = c.name.trim();
          if (name.isEmpty) continue;
          if (c.contactUserId != null && c.contactUserId! > 0) {
            _nameById[c.contactUserId!] = name;
          }
          if (c.phone != null && c.phone!.isNotEmpty) {
            for (final norm in PhoneMatcher.candidates(c.phone)) {
              _nameByPhone[norm] = name;
            }
          }
        }
        if (contacts.length < 100) break; // last page
      }
      _loaded = true;
    } catch (_) {
      // Non-fatal — callers fall back to API name
    }
  }

  /// Resolve the display name for a user.
  ///
  /// Priority: contact-book name → [apiName] fallback.
  String resolve({
    int? userId,
    String? phone,
    required String apiName,
  }) {
    if (!_loaded) return _sanitize(apiName);

    if (userId != null && userId > 0) {
      final n = _nameById[userId];
      if (n != null && n.isNotEmpty) return n;
    }
    if (phone != null && phone.isNotEmpty) {
      for (final norm in PhoneMatcher.candidates(phone)) {
        final n = _nameByPhone[norm];
        if (n != null && n.isNotEmpty) return n;
      }
    }
    return _sanitize(apiName);
  }

  /// Convenience: resolve then sanitize.
  String _sanitize(String? raw) {
    final s = raw?.trim() ?? '';
    return s.isEmpty ? 'Unknown' : s;
  }

  bool get isLoaded => _loaded;

  /// Return a copy of the name-by-userId cache (for seeding contact name maps in widgets).
  Map<int, String> exportCache() => Map<int, String>.unmodifiable(_nameById);
}
