import 'dart:collection';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/api_service.dart';
import '../chats/models.dart';
import '../../utils/phone_matcher.dart';

typedef Json = Map<String, dynamic>;

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return ContactsRepository(api);
});

class ContactsRepository {
  ContactsRepository(this.api);
  final ApiService api;

  Future<void> syncDeviceContacts(
    List<Map<String, String>> contacts, {
    int? chunkSize,
    void Function(int sent, int total)? onChunk,
  }) async {
    try {
      if (chunkSize == null || chunkSize <= 0 || contacts.length <= chunkSize) {
        await api.syncContacts(contacts);
        onChunk?.call(contacts.length, contacts.length);
        return;
      }

      var sent = 0;
      for (var i = 0; i < contacts.length; i += chunkSize) {
        final end = (i + chunkSize) > contacts.length ? contacts.length : (i + chunkSize);
        final slice = contacts.sublist(i, end);
        await api.syncContacts(slice);
        sent = end;
        onChunk?.call(sent, contacts.length);
      }
    } catch (e) {
      throw ContactsException('Failed to sync contacts: $e');
    }
  }

  Future<List<GekyContact>> listContacts({int page = 1, int perPage = 50}) async {
    try {
      final r = await api.get('/contacts', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      final responseData = r.data;
      // Handle paginated response
      final data = responseData is Map && responseData['data'] != null
          ? responseData['data']
          : (responseData is List ? responseData : []);
      final list = _ensureList(data);
      final parsed = <GekyContact>[];
      for (final j in list) {
        try {
          final c = GekyContact.fromJson(_ensureMap(j));
          if (c.id > 0) parsed.add(c);
        } catch (_) {}
      }
      return UnmodifiableListView(parsed);
    } catch (e) {
      throw ContactsException('Failed to fetch contacts: $e');
    }
  }
  
  Future<Map<String, dynamic>> listContactsPaginated({int page = 1, int perPage = 50}) async {
    try {
      final r = await api.get('/contacts', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      final responseData = r.data;
      final data = responseData is Map && responseData['data'] != null
          ? responseData['data']
          : (responseData is List ? responseData : []);
      final list = _ensureList(data);
      final parsed = <GekyContact>[];
      for (final j in list) {
        try {
          final c = GekyContact.fromJson(_ensureMap(j));
          if (c.id > 0) parsed.add(c);
        } catch (_) {}
      }

      // Extract pagination metadata
      final meta = responseData is Map && responseData['meta'] != null
          ? responseData['meta']
          : {
              'current_page': 1,
              'last_page': 1,
              'per_page': perPage,
              'total': parsed.length,
            };
      
      return {
        'data': UnmodifiableListView(parsed),
        'meta': meta,
      };
    } catch (e) {
      throw ContactsException('Failed to fetch contacts: $e');
    }
  }

  Future<List<Map<String, dynamic>>> resolvePhones(List<String> phones) async {
    try {
      final r = await api.resolveContacts(phones);
      final list = _ensureList(r.data);
      return list.map(_ensureMap).toList(growable: false);
    } catch (e) {
      throw ContactsException('Failed to resolve phones: $e');
    }
  }

  Future<GekyContact?> getContactById(int id) async {
    try {
      final all = await listContacts();
      for (final c in all) {
        if (c.id == id) return c;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fresh profile with online/last-seen and whether they are in your contacts.
  Future<({User user, bool isContact, GekyContact? gekyContact})>
      getUserProfile(int userId) async {
    try {
      final r = await api.get('/contacts/user/$userId/profile');
      final data = r.data;
      if (data is! Map) {
        throw ContactsException('Unexpected profile response');
      }
      final map = Map<String, dynamic>.from(data);
      final userRaw = map['user'] ?? map['data'];
      if (userRaw is! Map) {
        throw ContactsException('Profile missing user payload');
      }
      final userMap = Map<String, dynamic>.from(userRaw);
      final user = User.fromJson(userMap);
      final isContact =
          userMap['is_contact'] == true || map['is_contact'] == true;

      GekyContact? gekyContact;
      final contactData = userMap['contact_data'];
      if (contactData is Map) {
        final cd = Map<String, dynamic>.from(contactData);
        final id = GekyContact.parseInt(cd['id']);
        if (id != null && id > 0) {
          gekyContact = GekyContact(
            id: id,
            name: (cd['display_name'] ?? user.name).toString(),
            phone: cd['phone']?.toString() ?? user.phone,
            avatarUrl: user.avatarUrl,
            isRegistered: true,
            contactUserId: user.id > 0 ? user.id : null,
            note: cd['note']?.toString(),
          );
        }
      }

      return (user: user, isContact: isContact, gekyContact: gekyContact);
    } catch (e) {
      throw ContactsException('Failed to load user profile: $e');
    }
  }

  Future<bool> isUserInContacts({int? userId, String? phone}) async {
    if (userId != null && userId > 0) {
      try {
        final profile = await getUserProfile(userId);
        if (profile.isContact || profile.gekyContact != null) return true;
      } catch (_) {}
    }

    try {
      var page = 1;
      while (page <= 5) {
        final batch = await listContacts(page: page, perPage: 100);
        if (batch.isEmpty) break;
        for (final c in batch) {
          if (userId != null &&
              userId > 0 &&
              c.contactUserId != null &&
              c.contactUserId == userId) {
            return true;
          }
          if (phone != null &&
              phone.trim().isNotEmpty &&
              PhoneMatcher.matchesLoose(c.phone, phone)) {
            return true;
          }
        }
        if (batch.length < 100) break;
        page++;
      }
    } catch (_) {}
    return false;
  }

  /// Returns the saved GekyChat contact row for [userId] or [phone], if any.
  Future<GekyContact?> getGekyContactForUser({
    int? userId,
    String? phone,
  }) async {
    // Prefer profile contact_data — reliable even when the contacts list is huge.
    if (userId != null && userId > 0) {
      try {
        final profile = await getUserProfile(userId);
        if (profile.gekyContact != null) return profile.gekyContact;
      } catch (_) {}
    }

    // Search endpoint when we have a phone (avoids paging the full book).
    if (phone != null && phone.trim().isNotEmpty) {
      final searchTerms = <String>{
        phone.trim(),
        if (PhoneMatcher.normalizeGhanaLoginPhone(phone).isNotEmpty)
          PhoneMatcher.normalizeGhanaLoginPhone(phone),
        ...PhoneMatcher.candidates(phone),
      };
      for (final term in searchTerms) {
        if (term.isEmpty) continue;
        try {
          final r = await api.get('/contacts', queryParameters: {
            'search': term,
            'per_page': 50,
          });
          final responseData = r.data;
          final data = responseData is Map && responseData['data'] != null
              ? responseData['data']
              : (responseData is List ? responseData : []);
          for (final raw in _ensureList(data)) {
            try {
              final c = GekyContact.fromJson(_ensureMap(raw));
              if (c.id <= 0) continue;
              if (userId != null &&
                  userId > 0 &&
                  c.contactUserId != null &&
                  c.contactUserId == userId) {
                return c;
              }
              if (PhoneMatcher.matchesLoose(c.phone, phone)) return c;
            } catch (_) {}
          }
        } catch (_) {}
      }
    }

    try {
      var page = 1;
      while (page <= 20) {
        final batch = await listContacts(page: page, perPage: 100);
        if (batch.isEmpty) break;
        for (final c in batch) {
          if (userId != null &&
              userId > 0 &&
              c.contactUserId != null &&
              c.contactUserId == userId) {
            return c;
          }
          if (phone != null &&
              phone.trim().isNotEmpty &&
              PhoneMatcher.matchesLoose(c.phone, phone)) {
            return c;
          }
        }
        if (batch.length < 100) break;
        page++;
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateContact(
    int contactId, {
    String? displayName,
    String? phone,
    String? note,
    bool? isFavorite,
  }) async {
    try {
      await api.updateContact(
        contactId,
        displayName: displayName,
        phone: phone,
        note: note,
        isFavorite: isFavorite,
      );
    } catch (e) {
      throw ContactsException('Failed to update contact: $e');
    }
  }

  Future<GekyContact> saveContact({
    required String displayName,
    required String phone,
    int? contactUserId,
    String? note,
    bool? isFavorite,
  }) async {
    try {
      final r = await api.createContact(
        displayName: displayName,
        phone: phone,
        contactUserId: contactUserId,
        note: note,
        isFavorite: isFavorite,
      );
      final data = r.data;
      final contactData = data is Map && data['data'] != null ? data['data'] : data;
      return GekyContact.fromJson(_ensureMap(contactData));
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw ContactAlreadyExistsException(
          'Contact with this phone number already exists',
        );
      }
      throw ContactsException('Failed to save contact: $e');
    } catch (e) {
      if (e is ContactAlreadyExistsException) rethrow;
      throw ContactsException('Failed to save contact: $e');
    }
  }

  List<GekyContact> filterRegistered(Iterable<GekyContact> contacts) =>
      contacts.where((c) => c.isRegistered).toList(growable: false);

  List<dynamic> _ensureList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map && raw['data'] is List) return raw['data'] as List;
    if (raw == null) return const [];
    throw ContactsException('Unexpected contacts payload: not a list');
  }

  Json _ensureMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw ContactsException('Unexpected item payload: not an object');
  }
}

class ContactsException implements Exception {
  final String message;
  ContactsException(this.message);
  @override
  String toString() => 'ContactsException: $message';
}

class ContactAlreadyExistsException implements Exception {
  final String message;
  ContactAlreadyExistsException(this.message);
  @override
  String toString() => message;
}


