import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-first Hidden Chat (chat lock) — device-only secret code + hidden IDs.
class HiddenChatService extends ChangeNotifier {
  static const _codeHashKey = 'hidden_chat_secret_code_hash';
  static const _hiddenIdsKey = 'hidden_conversation_ids';
  static const _onboardedKey = 'hidden_chat_onboarded';

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
    final hash = prefs.getString(_codeHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setSecretCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.length < 4) {
      throw ArgumentError('Secret code must be at least 4 characters');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeHashKey, _simpleHash(trimmed));
    await prefs.setBool(_onboardedKey, true);
    notifyListeners();
  }

  Future<bool> verifySecretCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_codeHashKey);
    if (hash == null || hash.isEmpty) return false;
    return hash == _simpleHash(code.trim());
  }

  Future<Set<int>> hiddenConversationIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_hiddenIdsKey) ?? const [];
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
    final ids = await hiddenConversationIds()..add(conversationId);
    await prefs.setStringList(
      _hiddenIdsKey,
      ids.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  Future<void> unhideConversation(int conversationId) async {
    if (conversationId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = await hiddenConversationIds()..remove(conversationId);
    await prefs.setStringList(
      _hiddenIdsKey,
      ids.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }
}

final hiddenChatServiceProvider = ChangeNotifierProvider<HiddenChatService>((ref) {
  return HiddenChatService();
});

/// Hidden conversation IDs for this device (rebuilds when the service notifies).
final hiddenConversationIdsProvider = FutureProvider<Set<int>>((ref) async {
  final service = ref.watch(hiddenChatServiceProvider);
  return service.hiddenConversationIds();
});
