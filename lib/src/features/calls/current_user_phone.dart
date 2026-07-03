import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_service.dart';

const String kUserPhonePrefsKey = 'user_phone';

class CurrentUserPhone {
  CurrentUserPhone._();

  static Future<String> resolve() async {
    final prefs = await SharedPreferences.getInstance();
    var phone = prefs.getString(kUserPhonePrefsKey)?.trim() ?? '';
    if (phone.isNotEmpty) return phone;
    phone = await _fromMeApi();
    if (phone.isNotEmpty) {
      await prefs.setString(kUserPhonePrefsKey, phone);
    }
    return phone;
  }

  static Future<String> _fromMeApi() async {
    try {
      final api = ApiService();
      final response = await api.get('/me').timeout(const Duration(seconds: 8));
      final raw = response.data;
      if (raw is! Map) return '';
      final userJson = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : Map<String, dynamic>.from(raw);
      return (userJson['phone'] as String? ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  static Future<void> persistFromAuth(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserPhonePrefsKey, trimmed);
  }
}
