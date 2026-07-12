import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'models.dart';

final birthdayRepositoryProvider = Provider<BirthdayRepository>((ref) {
  return BirthdayRepository(ref.read(apiServiceProvider));
});

class BirthdayRepository {
  BirthdayRepository(this._api);

  final ApiService _api;

  Future<int> _accountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('current_account_id') ?? 1;
  }

  String _dismissPrefsKey(int accountId) => 'birthday_banner_dismissed_$accountId';

  Future<Set<String>> _localDismissedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final aid = await _accountId();
    final raw = prefs.getString(_dismissPrefsKey(aid));
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> dismissBanner(String dismissKey) async {
    if (dismissKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final aid = await _accountId();
    final keys = await _localDismissedKeys();
    keys.add(dismissKey);
    await prefs.setString(_dismissPrefsKey(aid), jsonEncode(keys.toList()));
    try {
      await _api.post('/in-app-notices/dismiss', data: {'notice_key': dismissKey});
    } catch (e) {
      debugPrint('BirthdayRepository.dismiss (API): $e');
    }
  }

  Future<int?> resolveConversationId(BirthdayCelebrant celebrant) async {
    if (celebrant.conversationId != null) return celebrant.conversationId;
    try {
      final response = await _api.startConversation(celebrant.userId);
      final data = response.data;
      if (data is Map) {
        if (data['data'] is Map) {
          return data['data']['id'] as int?;
        }
        return data['id'] as int?;
      }
    } catch (e) {
      debugPrint('BirthdayRepository.resolveConversationId: $e');
    }
    return null;
  }

  Future<BirthdaySummary> fetchSummary() async {
    try {
      final response = await _api.get('/birthdays/summary');
      final raw = response.data;
      final map = raw is Map && raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw is Map
              ? Map<String, dynamic>.from(raw)
              : null;
      if (map == null) return BirthdaySummary.empty();

      final summary = BirthdaySummary.fromJson(map);
      final dismissed = await _localDismissedKeys();
      if (dismissed.contains(summary.dismissKey)) {
        return BirthdaySummary(
          dismissKey: summary.dismissKey,
          todayCount: summary.todayCount,
          yesterdayCount: summary.yesterdayCount,
          showBanner: false,
          previewAvatars: summary.previewAvatars,
          bannerTitle: summary.bannerTitle,
          bannerSubtitle: summary.bannerSubtitle,
          today: summary.today,
          yesterday: summary.yesterday,
          selfToday: summary.selfToday,
          hasBirthdaySet: summary.hasBirthdaySet,
        );
      }
      return summary;
    } catch (e) {
      debugPrint('BirthdayRepository.fetchSummary: $e');
      return BirthdaySummary.empty();
    }
  }
}
