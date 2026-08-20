import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _storageKey = 'gekychat_installation_id';

const _storage = FlutterSecureStorage();

/// Stable per-app-install identity for join-call cancel exclusion and device registration.
Future<String> getOrCreateInstallationId() async {
  final existing = await _storage.read(key: _storageKey);
  if (existing != null && existing.trim().isNotEmpty) {
    return existing.trim();
  }

  final id = const Uuid().v4();
  await _storage.write(key: _storageKey, value: id);
  return id;
}
