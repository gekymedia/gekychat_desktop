import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../utils/snackbar_helper.dart';
import '../../widgets/desktop_typography.dart';
import 'issue_report_providers.dart';
import 'issue_report_repository.dart';

class IssueReportScreen extends ConsumerStatefulWidget {
  const IssueReportScreen({super.key, required this.source});

  final IssueReportSource source;

  @override
  ConsumerState<IssueReportScreen> createState() => _IssueReportScreenState();
}

class _IssueReportScreenState extends ConsumerState<IssueReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _category = 'bug';
  bool _includeDiagnostics = false;
  bool _submitting = false;
  File? _screenshot;

  String _appVersion = '—';
  String _platform = '—';
  String _deviceModel = '—';
  String _osVersion = '—';
  String? _screenName;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      String platform;
      String model;
      String os;

      if (Platform.isWindows) {
        final windows = await deviceInfo.windowsInfo;
        platform = 'windows';
        model = windows.computerName;
        os = 'Windows ${windows.majorVersion}.${windows.minorVersion}';
      } else if (Platform.isMacOS) {
        final mac = await deviceInfo.macOsInfo;
        platform = 'macos';
        model = mac.model;
        os = 'macOS ${mac.osRelease}';
      } else if (Platform.isLinux) {
        final linux = await deviceInfo.linuxInfo;
        platform = 'linux';
        model = linux.name;
        os = linux.version ?? linux.prettyName;
      } else {
        platform = Platform.operatingSystem;
        model = Platform.localHostname;
        os = Platform.operatingSystemVersion;
      }

      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
        _platform = platform;
        _deviceModel = model;
        _osVersion = os;
        try {
          _screenName = GoRouterState.of(context).uri.toString();
        } catch (_) {
          _screenName = null;
        }
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _buildDiagnostics() async {
    if (!_includeDiagnostics) return null;

    final connectivity = await Connectivity().checkConnectivity();

    return {
      'connectivity': connectivity.toString(),
      'locale': Platform.localeName,
      'report_source': widget.source.name,
    };
  }

  Future<void> _pickScreenshot() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _screenshot = File(path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(issueReportRepositoryProvider);
      await repo.submit(
        category: _category,
        description: _descriptionController.text.trim(),
        source: widget.source,
        appVersion: _appVersion,
        platform: _platform,
        deviceModel: _deviceModel,
        osVersion: _osVersion,
        screenName: _screenName,
        diagnostics: await _buildDiagnostics(),
        screenshot: _screenshot,
      );
      if (!mounted) return;
      context.showSuccessToast('Thanks — your report was sent to our team.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Could not send report. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Tell us what went wrong. We never include your messages unless you describe them below.',
            style: TextStyle(
              fontFamily: DesktopTypography.fontFamily,
              color: isDark ? Colors.white70 : const Color(0xFF54656F),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'What happened?',
            style: TextStyle(
              fontFamily: DesktopTypography.fontFamily,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'bug', label: Text('Bug')),
              ButtonSegment(value: 'crash', label: Text('Crash')),
              ButtonSegment(value: 'other', label: Text('Other')),
            ],
            selected: {_category},
            onSelectionChanged: (s) => setState(() => _category = s.first),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 5,
            maxLength: 5000,
            style: TextStyle(
              fontFamily: DesktopTypography.fontFamily,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What were you doing? What did you expect?',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.length < 10) {
                return 'Please add at least 10 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _InfoCard(
            isDark: isDark,
            title: 'Included automatically',
            items: [
              'App version: $_appVersion',
              'Device: $_deviceModel',
              'OS: $_osVersion',
              if (_screenName != null) 'Screen: $_screenName',
            ],
            footer:
                'No chat messages or media are attached unless you add them below.',
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include diagnostic details'),
            subtitle: const Text(
              'Connectivity and locale — no message content.',
            ),
            value: _includeDiagnostics,
            onChanged: (v) => setState(() => _includeDiagnostics = v),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Attach a screenshot (optional)'),
            subtitle: Text(
              _screenshot == null
                  ? 'You choose what to share — nothing is captured automatically.'
                  : _screenshot!.path.split(Platform.pathSeparator).last,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.image_outlined),
              onPressed: _pickScreenshot,
            ),
          ),
          if (_screenshot != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _screenshot = null),
                child: const Text('Remove screenshot'),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF008069),
              minimumSize: const Size.fromHeight(44),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send report'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.isDark,
    required this.title,
    required this.items,
    required this.footer,
  });

  final bool isDark;
  final String title;
  final List<String> items;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? const Color(0xFF202C33) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: DesktopTypography.fontFamily,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item,
                  style: TextStyle(
                    fontFamily: DesktopTypography.fontFamily,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF54656F),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              footer,
              style: TextStyle(
                fontFamily: DesktopTypography.fontFamily,
                fontSize: 13,
                color: const Color(0xFF008069),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
