import 'package:url_launcher/url_launcher.dart';

Future<bool> launchExternalShareUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> shareViaWhatsApp(String text) {
  return launchExternalShareUrl(
    'https://wa.me/?text=${Uri.encodeComponent(text)}',
  );
}

Future<bool> shareViaTelegram({required String url, required String text}) {
  return launchExternalShareUrl(
    'https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=${Uri.encodeComponent(text)}',
  );
}

Future<bool> shareViaTwitter(String text) {
  return launchExternalShareUrl(
    'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}',
  );
}

Future<bool> shareViaFacebook(String url) {
  return launchExternalShareUrl(
    'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}',
  );
}

Future<bool> shareViaEmail({required String subject, required String body}) {
  return launchExternalShareUrl(
    'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
}
