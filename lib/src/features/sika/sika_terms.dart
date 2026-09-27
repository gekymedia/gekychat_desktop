import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared prefs key for Sika Wallet terms acceptance (device-local).
const sikaTermsAcceptedKey = 'sika_wallet_terms_accepted_v1';

const sikaTermsUrl = 'https://gekychat.com/terms-of-service';

Future<bool> isSikaTermsAccepted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(sikaTermsAcceptedKey) ?? false;
}

Future<void> setSikaTermsAccepted(bool accepted) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(sikaTermsAcceptedKey, accepted);
}

Future<void> openSikaTermsUrl() async {
  final uri = Uri.parse(sikaTermsUrl);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
