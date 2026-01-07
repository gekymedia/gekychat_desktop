import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/api_service.dart';
import '../chats/models.dart';

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

  Future<List<GekyContact>> listContacts() async {
    try {
      final r = await api.fetchContacts();
      final list = _ensureList(r.data);
      final parsed = list
          .map((j) => GekyContact.fromJson(_ensureMap(j)))
          .toList(growable: false);
      return UnmodifiableListView(parsed);
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
    } catch (e) {
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


