/// Parsed remote version policy from GET /app/version.
class AppVersionInfo {
  const AppVersionInfo({
    required this.platform,
    required this.latestVersion,
    required this.minVersion,
    this.downloadUrl,
    this.currentVersion,
    this.updateRequired,
    this.updateAvailable,
    this.isLatest,
  });

  final String platform;
  final String latestVersion;
  final String minVersion;
  final String? downloadUrl;
  final String? currentVersion;
  final bool? updateRequired;
  final bool? updateAvailable;
  final bool? isLatest;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      platform: json['platform']?.toString() ?? '',
      latestVersion: json['latest_version']?.toString() ?? '0.0.0',
      minVersion: json['min_version']?.toString() ?? '0.0.0',
      downloadUrl: json['download_url']?.toString(),
      currentVersion: json['current_version']?.toString(),
      updateRequired: json['update_required'] as bool?,
      updateAvailable: json['update_available'] as bool?,
      isLatest: json['is_latest'] as bool?,
    );
  }

  bool get requiresForceUpdate => updateRequired == true;

  bool get hasOptionalUpdate =>
      updateAvailable == true && updateRequired != true;
}

class AppVersionCheckResult {
  const AppVersionCheckResult({
    required this.installedVersion,
    required this.remote,
  });

  final String installedVersion;
  final AppVersionInfo remote;

  bool get requiresForceUpdate => remote.requiresForceUpdate;

  bool get hasOptionalUpdate => remote.hasOptionalUpdate;

  bool get isUpToDate => remote.isLatest == true;
}
