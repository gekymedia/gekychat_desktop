import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../api_service.dart';
import 'app_version_info.dart';

String currentAppPlatform() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return Platform.operatingSystem;
}

class AppVersionService {
  AppVersionService(this._api);

  final ApiService _api;

  Future<String> installedVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  Future<AppVersionCheckResult> checkForUpdates() async {
    final installed = await installedVersionLabel();
    final response = await _api.getAppVersion(
      platform: currentAppPlatform(),
      currentVersion: installed,
    );

    final raw = response.data;
    final data = raw is Map && raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : Map<String, dynamic>.from(raw as Map);

    return AppVersionCheckResult(
      installedVersion: installed,
      remote: AppVersionInfo.fromJson(data),
    );
  }
}
