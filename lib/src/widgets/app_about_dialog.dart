import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_version/app_version_providers.dart';
import '../core/app_version/app_version_info.dart';
import '../utils/snackbar_helper.dart';
import 'desktop_typography.dart';

Future<void> showAppAboutDialog(
  BuildContext context, {
  required String appName,
  required String description,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _AppAboutDialog(
      appName: appName,
      description: description,
    ),
  );
}

class _AppAboutDialog extends ConsumerStatefulWidget {
  const _AppAboutDialog({
    required this.appName,
    required this.description,
  });

  final String appName;
  final String description;

  @override
  ConsumerState<_AppAboutDialog> createState() => _AppAboutDialogState();
}

class _AppAboutDialogState extends ConsumerState<_AppAboutDialog> {
  String? _installedVersion;
  AppVersionCheckResult? _checkResult;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final info = await PackageInfo.fromPlatform();
      final installed = '${info.version}+${info.buildNumber}';
      final result = await ref.read(appVersionCheckProvider.future);
      if (!mounted) return;
      setState(() {
        _installedVersion = installed;
        _checkResult = result;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Could not check for updates';
      });
      try {
        final info = await PackageInfo.fromPlatform();
        _installedVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}
    }
  }

  Future<void> _openDownload() async {
    final url = _checkResult?.remote.downloadUrl;
    final uri = Uri.tryParse(url ?? '');
    if (uri == null) {
      if (mounted) context.showErrorToast('No download link configured.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _buildStatusText();

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
      title: Text(
        'About',
        style: TextStyle(
          fontFamily: DesktopTypography.fontFamily,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.appName,
            style: TextStyle(
              fontFamily: DesktopTypography.fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _installedVersion == null
                ? 'Loading version…'
                : 'Version $_installedVersion',
            style: TextStyle(
              fontFamily: DesktopTypography.fontFamily,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          if (_checking) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(
              status,
              style: TextStyle(
                fontFamily: DesktopTypography.fontFamily,
                fontWeight: FontWeight.w500,
                color: _checkResult?.requiresForceUpdate == true
                    ? Colors.red.shade400
                    : const Color(0xFF008069),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontFamily: DesktopTypography.fontFamily,
                color: Colors.red.shade400,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            widget.description,
            style: TextStyle(
              fontFamily: DesktopTypography.fontFamily,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ),
      actions: [
        if (_checkResult?.hasOptionalUpdate == true ||
            _checkResult?.requiresForceUpdate == true)
          TextButton(
            onPressed: _openDownload,
            child: const Text('Update'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String? _buildStatusText() {
    final result = _checkResult;
    if (result == null || _checking) return null;
    if (result.requiresForceUpdate) {
      return 'Update required — please install ${result.remote.latestVersion}';
    }
    if (result.hasOptionalUpdate) {
      return 'Update available — latest is ${result.remote.latestVersion}';
    }
    if (result.isUpToDate) return 'You’re up to date';
    return null;
  }
}
