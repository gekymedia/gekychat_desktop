import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_service.dart';
import '../utils/phone_matcher.dart';

/// Cached bot contact with UI/call capabilities (synced from server + bundled seed).
class BotContactEntry {
  final String botNumber;
  final int? userId;
  final String botType;
  final String name;
  final bool allowCalls;
  final bool showPresence;

  const BotContactEntry({
    required this.botNumber,
    this.userId,
    required this.botType,
    required this.name,
    this.allowCalls = false,
    this.showPresence = false,
  });

  factory BotContactEntry.fromJson(Map<String, dynamic> json) {
    final userIdRaw = json['user_id'] ?? json['userId'];
    final userId = userIdRaw is int
        ? userIdRaw
        : int.tryParse(userIdRaw?.toString() ?? '');
    return BotContactEntry(
      botNumber: (json['bot_number'] ?? json['botNumber'] ?? '').toString(),
      userId: userId != null && userId > 0 ? userId : null,
      botType: (json['type'] ?? json['bot_type'] ?? 'general').toString(),
      name: (json['name'] ?? '').toString(),
      allowCalls: json['allow_calls'] == true || json['allowCalls'] == true,
      showPresence:
          json['show_presence'] == true || json['showPresence'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'bot_number': botNumber,
        if (userId != null) 'user_id': userId,
        'type': botType,
        'name': name,
        'allow_calls': allowCalls,
        'show_presence': showPresence,
      };
}

/// Local + online registry for GekyChat bot contacts (AI, admissions, tasks, etc.).
class BotContactRegistry {
  BotContactRegistry();

  static const _prefsKey = 'bot_contacts_registry_v1';

  /// Bundled fallback when offline / before first API sync (matches server seeder).
  static const List<BotContactEntry> bundledSeed = [
    BotContactEntry(
      botNumber: '0000000000',
      botType: 'general',
      name: 'GekyChat AI',
    ),
    BotContactEntry(
      botNumber: '0000000001',
      botType: 'admissions',
      name: 'CUG Admissions',
    ),
    BotContactEntry(
      botNumber: '0000000002',
      botType: 'tasks',
      name: 'BlackTask',
    ),
  ];

  List<BotContactEntry> _entries = List<BotContactEntry>.from(bundledSeed);
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries = decoded
              .whereType<Map>()
              .map((e) => BotContactEntry.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.botNumber.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ BotContactRegistry load failed: $e');
      _entries = List<BotContactEntry>.from(bundledSeed);
    }
    if (_entries.isEmpty) {
      _entries = List<BotContactEntry>.from(bundledSeed);
    }
    _loaded = true;
  }

  Future<void> syncFromApi(ApiService api) async {
    await ensureLoaded();
    try {
      final response = await api.getBots();
      final data = response.data;
      final list = data is Map ? data['bots'] : null;
      if (list is! List || list.isEmpty) return;

      final merged = <String, BotContactEntry>{};
      for (final seed in bundledSeed) {
        merged[seed.botNumber] = seed;
      }
      for (final item in list) {
        if (item is! Map) continue;
        final entry = BotContactEntry.fromJson(Map<String, dynamic>.from(item));
        if (entry.botNumber.isEmpty) continue;
        merged[entry.botNumber] = entry;
      }
      _entries = merged.values.toList();
      _loaded = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_entries.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('⚠️ BotContactRegistry sync failed: $e');
    }
  }

  BotContactEntry? find({int? userId, String? phone}) {
    if (!_loaded) {
      _entries = List<BotContactEntry>.from(bundledSeed);
      _loaded = true;
    }
    if (userId != null && userId > 0) {
      for (final e in _entries) {
        if (e.userId == userId) return e;
      }
    }
    if (phone != null && phone.trim().isNotEmpty) {
      final digits = PhoneMatcher.normalize(phone);
      for (final e in _entries) {
        if (PhoneMatcher.matchesLoose(e.botNumber, phone) ||
            PhoneMatcher.matchesLoose(e.botNumber, digits)) {
          return e;
        }
      }
      if (digits.length >= 10) {
        final last10 = digits.substring(digits.length - 10);
        for (final e in _entries) {
          if (e.botNumber == last10) return e;
        }
      }
    }
    return null;
  }

  bool isBot({int? userId, String? phone}) =>
      find(userId: userId, phone: phone) != null;

  bool allowCalls({int? userId, String? phone}) =>
      find(userId: userId, phone: phone)?.allowCalls ?? false;

  bool showPresence({int? userId, String? phone}) =>
      find(userId: userId, phone: phone)?.showPresence ?? false;
}

final botContactRegistryProvider = Provider<BotContactRegistry>((ref) {
  return BotContactRegistry();
});
