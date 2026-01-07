import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'media_auto_download_repository.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

final mediaAutoDownloadSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(mediaAutoDownloadRepositoryProvider);
  return await repo.getSettings();
});

class MediaAutoDownloadScreen extends ConsumerStatefulWidget {
  const MediaAutoDownloadScreen({super.key});

  @override
  ConsumerState<MediaAutoDownloadScreen> createState() =>
      _MediaAutoDownloadScreenState();
}

class _MediaAutoDownloadScreenState
    extends ConsumerState<MediaAutoDownloadScreen> {
  String? _photos;
  String? _videos;
  String? _documents;
  String? _audio;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(mediaAutoDownloadSettingsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Media Auto-Download'),
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
          _photos ??= settings['photos'] ?? 'wifi_mobile';
          _videos ??= settings['videos'] ?? 'wifi_only';
          _documents ??= settings['documents'] ?? 'wifi_mobile';
          _audio ??= settings['audio'] ?? 'wifi_mobile';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Choose when media should be automatically downloaded',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _MediaTypeOption(
                  icon: Icons.image,
                  title: 'Photos',
                  value: _photos,
                  options: ['never', 'wifi_only', 'wifi_mobile', 'always'],
                  labels: [
                    'Never',
                    'Wi-Fi only',
                    'Wi-Fi and mobile',
                    'Always'
                  ],
                  onChanged: (value) => setState(() => _photos = value),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _MediaTypeOption(
                  icon: Icons.video_library,
                  title: 'Videos',
                  value: _videos,
                  options: ['never', 'wifi_only', 'wifi_mobile', 'always'],
                  labels: [
                    'Never',
                    'Wi-Fi only',
                    'Wi-Fi and mobile',
                    'Always'
                  ],
                  onChanged: (value) => setState(() => _videos = value),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _MediaTypeOption(
                  icon: Icons.description,
                  title: 'Documents',
                  value: _documents,
                  options: ['never', 'wifi_only', 'wifi_mobile', 'always'],
                  labels: [
                    'Never',
                    'Wi-Fi only',
                    'Wi-Fi and mobile',
                    'Always'
                  ],
                  onChanged: (value) => setState(() => _documents = value),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _MediaTypeOption(
                  icon: Icons.audiotrack,
                  title: 'Audio',
                  value: _audio,
                  options: ['never', 'wifi_only', 'wifi_mobile', 'always'],
                  labels: [
                    'Never',
                    'Wi-Fi only',
                    'Wi-Fi and mobile',
                    'Always'
                  ],
                  onChanged: (value) => setState(() => _audio = value),
                  isDark: isDark,
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
                onPressed: () => ref.invalidate(mediaAutoDownloadSettingsProvider),
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
      final settings = <String, dynamic>{
        'photos': _photos,
        'videos': _videos,
        'documents': _documents,
        'audio': _audio,
      };
      await ref.read(mediaAutoDownloadRepositoryProvider).updateSettings(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated')),
        );
      }
      ref.invalidate(mediaAutoDownloadSettingsProvider);
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

class _MediaTypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final List<String> options;
  final List<String> labels;
  final Function(String) onChanged;
  final bool isDark;

  const _MediaTypeOption({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? const Color(0xFF202C33) : Colors.white,
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: onChanged,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[options.indexOf(value ?? options[0])],
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down,
                    color: isDark ? Colors.white54 : Colors.grey[600]),
              ],
            ),
          ),
          itemBuilder: (context) => options
              .asMap()
              .entries
              .map((entry) => PopupMenuItem(
                    value: entry.value,
                    child: Row(
                      children: [
                        if (entry.value == value)
                          Icon(Icons.check,
                              size: 20, color: AppTheme.primaryGreen),
                        if (entry.value == value) const SizedBox(width: 8),
                        Text(labels[entry.key]),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

