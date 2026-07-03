import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum EmbeddedAppType { blackTask }

class EmbeddedAppConfig {
  final String name;
  final String defaultUrl;
  final String envKey;
  final String ssoEndpoint;

  const EmbeddedAppConfig({
    required this.name,
    required this.defaultUrl,
    required this.envKey,
    required this.ssoEndpoint,
  });

  String getUrl() {
    try {
      final url = dotenv.env[envKey];
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    return defaultUrl;
  }
}

const _configs = <EmbeddedAppType, EmbeddedAppConfig>{
  EmbeddedAppType.blackTask: EmbeddedAppConfig(
    name: 'BlackTask',
    defaultUrl: 'https://blacktask.gekymedia.com',
    envKey: 'BLACKTASK_URL',
    ssoEndpoint: '/auth/gekychat-sso',
  ),
};

/// Opens embedded apps in the system browser (desktop has no in-app WebView).
class EmbeddedAppLauncher {
  static Future<void> openBlackTask({
    int? recipientUserId,
    String? recipientName,
  }) async {
    await _open(
      EmbeddedAppType.blackTask,
      recipientUserId: recipientUserId,
      recipientName: recipientName,
    );
  }

  static Future<void> _open(
    EmbeddedAppType appType, {
    int? recipientUserId,
    String? recipientName,
  }) async {
    final config = _configs[appType]!;
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone');

    final base = Uri.parse(config.getUrl());
    final queryParams = <String, String>{
      'source': 'gekychat',
      'auto_login': 'true',
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (recipientUserId != null) 'recipient_id': recipientUserId.toString(),
      if (recipientName != null && recipientName.isNotEmpty)
        'recipient_name': recipientName,
    };

    final url = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: phone != null && phone.isNotEmpty ? config.ssoEndpoint : base.path,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('Could not open ${config.name}');
    }
  }
}
