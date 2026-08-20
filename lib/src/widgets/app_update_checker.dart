import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_version/app_version_providers.dart';
import '../core/app_version/app_version_info.dart';
import '../utils/snackbar_helper.dart';

class AppUpdateChecker extends ConsumerStatefulWidget {
  const AppUpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateChecker> createState() => _AppUpdateCheckerState();
}

class _AppUpdateCheckerState extends ConsumerState<AppUpdateChecker> {
  static const _dismissedKey = 'dismissed_optional_update_version';
  static bool _checkedThisSession = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  Future<void> _runCheck() async {
    if (_checkedThisSession || !mounted) return;
    _checkedThisSession = true;

    try {
      final result = await ref.read(appVersionCheckProvider.future);
      if (!mounted) return;
      await _handleResult(result);
    } catch (_) {}
  }

  Future<void> _handleResult(AppVersionCheckResult result) async {
    if (_dialogVisible || !mounted) return;

    if (result.requiresForceUpdate) {
      await _showForceUpdateDialog(result);
      return;
    }

    if (!result.hasOptionalUpdate) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(_dismissedKey);
    if (dismissed == result.remote.latestVersion) return;

    await _showOptionalUpdateDialog(result);
  }

  Future<void> _showForceUpdateDialog(AppVersionCheckResult result) async {
    _dialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update required'),
          content: Text(
            'This version (${result.installedVersion}) is no longer supported. '
            'Please update to ${result.remote.latestVersion} or newer to continue.\n\n'
            'Quit GekyChat from the system tray (Exit) before running the installer.',
          ),
          actions: [
            FilledButton(
              onPressed: () => _openDownloadUrl(result.remote.downloadUrl),
              child: const Text('Update now'),
            ),
          ],
        ),
      ),
    );
    _dialogVisible = false;
  }

  Future<void> _showOptionalUpdateDialog(AppVersionCheckResult result) async {
    _dialogVisible = true;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'A newer version (${result.remote.latestVersion}) is available. '
          'You are on ${result.installedVersion}.\n\n'
          'Download the installer, then fully quit GekyChat (right-click the tray icon → Exit) '
          'before running the setup. The installer will upgrade your existing install.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'later'),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'update'),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    _dialogVisible = false;

    if (action == 'update') {
      await _openDownloadUrl(result.remote.downloadUrl);
    } else if (action == 'later') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedKey, result.remote.latestVersion);
    }
  }

  Future<void> _openDownloadUrl(String? url) async {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null) {
      if (mounted) context.showErrorToast('No download link configured yet.');
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        context.showErrorToast('Could not open update link.');
      }
    } catch (_) {
      if (mounted) context.showErrorToast('Could not open update link.');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
