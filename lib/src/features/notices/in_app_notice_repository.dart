import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'in_app_notice.dart';

final inAppNoticeRepositoryProvider = Provider<InAppNoticeRepository>((ref) {
  return InAppNoticeRepository(ref.read(apiServiceProvider));
});

class InAppNoticeRepository {
  InAppNoticeRepository(this._api);

  final ApiService _api;

  Future<int> _accountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('current_account_id') ?? 1;
  }

  String _prefsKey(int accountId) => 'in_app_notice_dismissed_$accountId';

  Future<Set<String>> _localDismissedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final aid = await _accountId();
    final raw = prefs.getString(_prefsKey(aid));
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _addLocalDismiss(String noticeKey) async {
    final prefs = await SharedPreferences.getInstance();
    final aid = await _accountId();
    final keys = await _localDismissedKeys();
    keys.add(noticeKey);
    await prefs.setString(_prefsKey(aid), jsonEncode(keys.toList()));
  }

  /// Merges server list with local dismissals (offline-friendly).
  Future<List<InAppNotice>> fetchVisible() async {
    final local = await _localDismissedKeys();
    try {
      final response = await _api.get('/in-app-notices');
      final raw = response.data;
      List<dynamic> data;
      if (raw is Map && raw['data'] is List) {
        data = raw['data'] as List<dynamic>;
      } else if (raw is List) {
        data = raw;
      } else {
        return [];
      }
      final out = <InAppNotice>[];
      for (final item in data) {
        if (item is! Map) continue;
        final n = InAppNotice.fromJson(Map<String, dynamic>.from(item));
        if (n.noticeKey.isEmpty) continue;
        if (local.contains(n.noticeKey)) continue;
        out.add(n);
      }
      return out;
    } catch (e) {
      debugPrint('InAppNoticeRepository.fetchVisible: $e');
      return [];
    }
  }

  Future<void> dismiss(String noticeKey) async {
    await _addLocalDismiss(noticeKey);
    try {
      await _api.post('/in-app-notices/dismiss', data: {'notice_key': noticeKey});
    } catch (e) {
      debugPrint('InAppNoticeRepository.dismiss (API): $e');
    }
  }
}
