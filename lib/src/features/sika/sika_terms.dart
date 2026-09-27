import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Legacy process-wide key (pre per-user scoping). Cleared on read/write/logout.
const sikaTermsAcceptedKey = 'sika_wallet_terms_accepted_v1';

const sikaTermsAcceptedKeyPrefix = 'sika_wallet_terms_accepted_v1_';

const sikaTermsUrl = 'https://gekychat.com/terms-of-service';

String? sikaTermsKeyForUserId(int? userId) {
  if (userId == null) return null;
  return '$sikaTermsAcceptedKeyPrefix$userId';
}

Future<bool> isSikaTermsAccepted() async {
  final prefs = await SharedPreferences.getInstance();
  // Drop legacy process-wide acceptance so it cannot leak across accounts.
  if (prefs.containsKey(sikaTermsAcceptedKey)) {
    await prefs.remove(sikaTermsAcceptedKey);
  }
  final key = sikaTermsKeyForUserId(prefs.getInt('user_id'));
  if (key == null) return false;
  return prefs.getBool(key) ?? false;
}

Future<void> setSikaTermsAccepted(bool accepted) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(sikaTermsAcceptedKey)) {
    await prefs.remove(sikaTermsAcceptedKey);
  }
  final key = sikaTermsKeyForUserId(prefs.getInt('user_id'));
  if (key == null) return;
  await prefs.setBool(key, accepted);
}

/// Removes legacy process-wide acceptance. Per-user keys are kept so the same
/// account does not need to re-consent after re-login.
Future<void> clearLegacySikaTermsAcceptance() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(sikaTermsAcceptedKey)) {
    await prefs.remove(sikaTermsAcceptedKey);
  }
}

Future<void> openSikaTermsUrl() async {
  final uri = Uri.parse(sikaTermsUrl);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
