import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/api_service.dart';
import '../../theme/app_theme.dart';

final notificationSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getNotificationSettings();
  return response.data['data'] ?? {};
});

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool? _soundEnabled;
  bool? _desktopEnabled;
  bool? _previewEnabled;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('Save'),
            ),
        ],
      ),
      body: settingsAsync.when(
        data: (settings) {
          _soundEnabled ??= settings['sound_enabled'] ?? true;
          _desktopEnabled ??= settings['desktop_enabled'] ?? true;
          _previewEnabled ??= settings['preview_enabled'] ?? true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Sounds'),
                        subtitle: const Text('Play notification sounds'),
                        value: _soundEnabled!,
                        onChanged: (value) => setState(() => _soundEnabled = value),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Desktop Notifications'),
                        subtitle: const Text('Show desktop notifications'),
                        value: _desktopEnabled!,
                        onChanged: (value) => setState(() => _desktopEnabled = value),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Message Preview'),
                        subtitle: const Text('Show message preview in notifications'),
                        value: _previewEnabled!,
                        onChanged: (value) => setState(() => _previewEnabled = value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading settings: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(notificationSettingsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateNotificationSettings({
        'sound_enabled': _soundEnabled,
        'desktop_enabled': _desktopEnabled,
        'preview_enabled': _previewEnabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated')),
        );
      }
      ref.invalidate(notificationSettingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

