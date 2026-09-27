import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-first Hidden Chat (chat lock) — device-only secret code + hidden IDs.
///
/// Prefs are namespaced by the signed-in user / account so a second account on
/// the same device does not inherit another account's code or locked set.
class HiddenChatService extends ChangeNotifier {
  static const _legacyCodeHashKey = 'hidden_chat_secret_code_hash';
  static const _legacyHiddenIdsKey = 'hidden_conversation_ids';
  static const _legacyOnboardedKey = 'hidden_chat_onboarded';

  Future<String> _scopeSuffix() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) return 'u$userId';
    final accountId = prefs.getInt('current_account_id');
    if (accountId != null) return 'a$accountId';
    return 'anon';
  }

  Future<String> _codeHashKey() async =>
      '$_legacyCodeHashKey://${await _scopeSuffix()}';

  Future<String> _hiddenIdsKey() async =>
      '$_legacyHiddenIdsKey://${await _scopeSuffix()}';

  Future<String> _onboardedKey() async =>
      '$_legacyOnboardedKey://${await _scopeSuffix()}';

  /// One-time migrate unscoped keys into the current account scope, then drop
  /// the legacy keys so other accounts cannot inherit them.
  Future<void> _migrateLegacyIfNeeded(SharedPreferences prefs) async {
    final codeKey = await _codeHashKey();
    final idsKey = await _hiddenIdsKey();
    final onboardedKey = await _onboardedKey();

    final hasScoped = (prefs.getString(codeKey)?.isNotEmpty ?? false) ||
        (prefs.getStringList(idsKey)?.isNotEmpty ?? false) ||
        prefs.containsKey(onboardedKey);

    if (!hasScoped) {
      final legacyHash = prefs.getString(_legacyCodeHashKey);
      final legacyIds = prefs.getStringList(_legacyHiddenIdsKey);
      final legacyOnboarded = prefs.getBool(_legacyOnboardedKey);
      if (legacyHash != null && legacyHash.isNotEmpty) {
        await prefs.setString(codeKey, legacyHash);
      }
      if (legacyIds != null && legacyIds.isNotEmpty) {
        await prefs.setStringList(idsKey, legacyIds);
      }
      if (legacyOnboarded != null) {
        await prefs.setBool(onboardedKey, legacyOnboarded);
      }
    }

    if (prefs.containsKey(_legacyCodeHashKey)) {
      await prefs.remove(_legacyCodeHashKey);
    }
    if (prefs.containsKey(_legacyHiddenIdsKey)) {
      await prefs.remove(_legacyHiddenIdsKey);
    }
    if (prefs.containsKey(_legacyOnboardedKey)) {
      await prefs.remove(_legacyOnboardedKey);
    }
  }

  String _simpleHash(String code) {
    // Lightweight obfuscation (device-local). Not a password KDF.
    final bytes = utf8.encode('gekychat-hidden-v1:$code');
    var h = 0xcbf29ce484222325;
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  Future<bool> hasSecretCode() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyIfNeeded(prefs);
    final hash = prefs.getString(await _codeHashKey());
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyIfNeeded(prefs);
    return prefs.getBool(await _onboardedKey()) ?? false;
  }

  Future<void> setSecretCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.length < 4) {
      throw ArgumentError('Secret code must be at least 4 characters');
    }
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyIfNeeded(prefs);
    await prefs.setString(await _codeHashKey(), _simpleHash(trimmed));
    await prefs.setBool(await _onboardedKey(), true);
    notifyListeners();
  }

  Future<bool> verifySecretCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyIfNeeded(prefs);
    final hash = prefs.getString(await _codeHashKey());
    if (hash == null || hash.isEmpty) return false;
    return hash == _simpleHash(code.trim());
  }

  Future<Set<int>> hiddenConversationIds() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyIfNeeded(prefs);
    final raw = prefs.getStringList(await _hiddenIdsKey()) ?? const [];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<bool> isHidden(int conversationId) async {
    if (conversationId <= 0) return false;
    final ids = await hiddenConversationIds();
    return ids.contains(conversationId);
  }

  Future<void> hideConversation(int conversationId) async {
    if (conversationId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyIfNeeded(prefs);
    final ids = await hiddenConversationIds()..add(conversationId);
    await prefs.setStringList(
      await _hiddenIdsKey(),
      ids.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  Future<void> unhideConversation(int conversationId) async {
    if (conversationId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyIfNeeded(prefs);
    final ids = await hiddenConversationIds()..remove(conversationId);
    await prefs.setStringList(
      await _hiddenIdsKey(),
      ids.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  /// Drop scoped Hidden Chat prefs for a removed account (and optional user id).
  Future<void> clearScopedDataForAccount({
    required int accountId,
    int? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final suffixes = <String>{'a$accountId'};
    if (userId != null) suffixes.add('u$userId');
    for (final key in prefs.getKeys().toList()) {
      for (final suffix in suffixes) {
        if (key.endsWith('_$suffix')) {
          await prefs.remove(key);
        }
      }
    }
    notifyListeners();
  }
}

/// Parse a conversation id from a global-search result item.
int? conversationIdFromSearchItem(Map<String, dynamic> item) {
  int? asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  final direct = asInt(item['conversation_id']);
  if (direct != null) return direct;
  if (item['conversation'] is Map) {
    return asInt((item['conversation'] as Map)['id']);
  }
  final id = item['id']?.toString();
  if (id != null && id.startsWith('conversation_')) {
    return int.tryParse(id.replaceFirst('conversation_', ''));
  }
  final type = item['type']?.toString();
  if (type == 'conversation' || type == 'message') {
    return asInt(item['id']);
  }
  return null;
}

/// Strip locked chats (and their message hits) from a server search payload.
Map<String, dynamic> filterHiddenFromSearchResults(
  Map<String, dynamic> raw,
  Set<int> hiddenIds,
) {
  if (hiddenIds.isEmpty) return raw;

  bool isHiddenItem(Map item) {
    final id = conversationIdFromSearchItem(Map<String, dynamic>.from(item));
    return id != null && hiddenIds.contains(id);
  }

  final copy = Map<String, dynamic>.from(raw);
  final resultsRaw = copy['results'];
  if (resultsRaw is List) {
    copy['results'] = resultsRaw.where((item) {
      if (item is! Map) return true;
      final type = item['type']?.toString();
      if (type == 'conversation' || type == 'message') {
        return !isHiddenItem(item);
      }
      return true;
    }).toList();
    return copy;
  }
  if (resultsRaw is Map) {
    final grouped = Map<String, dynamic>.from(resultsRaw);
    for (final key in ['conversations', 'messages']) {
      final list = grouped[key];
      if (list is! List) continue;
      grouped[key] = list.where((item) {
        if (item is! Map) return true;
        return !isHiddenItem(item);
      }).toList();
    }
    copy['results'] = grouped;
  }
  return copy;
}

final hiddenChatServiceProvider = ChangeNotifierProvider<HiddenChatService>((ref) {
  return HiddenChatService();
});

/// Hidden conversation IDs for the current account (rebuilds when the service notifies).
final hiddenConversationIdsProvider = FutureProvider<Set<int>>((ref) async {
  final service = ref.watch(hiddenChatServiceProvider);
  return service.hiddenConversationIds();
});
