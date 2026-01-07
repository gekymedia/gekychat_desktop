import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'privacy_repository.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

final privacySettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(privacyRepositoryProvider);
  return await repo.getPrivacySettings();
});

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  String? _lastSeen;
  String? _profilePhoto;
  String? _about;
  Map<String, dynamic>? _statusPrivacy;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(privacySettingsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Privacy Settings'),
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
          _lastSeen ??= settings['last_seen'] ?? 'everyone';
          _profilePhoto ??= settings['profile_photo'] ?? 'everyone';
          _about ??= settings['about'] ?? 'everyone';
          _statusPrivacy ??= settings['status'] ?? {'who_can_see': 'my_contacts'};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PrivacySection(
                  title: 'Who can see',
                  children: [
                    _PrivacyOption(
                      title: 'Last Seen',
                      subtitle: 'Control who can see your last seen timestamp',
                      value: _lastSeen,
                      options: ['everyone', 'my_contacts', 'nobody'],
                      labels: ['Everyone', 'My Contacts', 'Nobody'],
                      onChanged: (value) => setState(() => _lastSeen = value),
                      isDark: isDark,
                    ),
                    _PrivacyOption(
                      title: 'Profile Photo',
                      subtitle: 'Control who can see your profile photo',
                      value: _profilePhoto,
                      options: ['everyone', 'my_contacts', 'nobody'],
                      labels: ['Everyone', 'My Contacts', 'Nobody'],
                      onChanged: (value) => setState(() => _profilePhoto = value),
                      isDark: isDark,
                    ),
                    _PrivacyOption(
                      title: 'About',
                      subtitle: 'Control who can see your about information',
                      value: _about,
                      options: ['everyone', 'my_contacts', 'nobody'],
                      labels: ['Everyone', 'My Contacts', 'Nobody'],
                      onChanged: (value) => setState(() => _about = value),
                      isDark: isDark,
                    ),
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
                _PrivacySection(
                  title: 'Status',
                  children: [
                    _PrivacyOption(
                      title: 'Status Privacy',
                      subtitle: 'Control who can see your status updates',
                      value: _statusPrivacy!['who_can_see'],
                      options: ['my_contacts', 'my_contacts_except', 'only_share_with'],
                      labels: ['My Contacts', 'My Contacts Except...', 'Only Share With...'],
                      onChanged: (value) => setState(() {
                        _statusPrivacy = {..._statusPrivacy!, 'who_can_see': value};
                      }),
                      isDark: isDark,
                    ),
                  ],
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
              Text('Error loading privacy settings: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(privacySettingsProvider),
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
        'last_seen': _lastSeen,
        'profile_photo': _profilePhoto,
        'about': _about,
        'status': _statusPrivacy,
      };
      await ref.read(privacyRepositoryProvider).updatePrivacySettings(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy settings updated')),
        );
      }
      ref.invalidate(privacySettingsProvider);
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

class _PrivacySection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;

  const _PrivacySection({
    required this.title,
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ),
        Card(
          color: isDark ? const Color(0xFF202C33) : Colors.white,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? value;
  final List<String> options;
  final List<String> labels;
  final Function(String) onChanged;
  final bool isDark;

  const _PrivacyOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
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
                            size: 20,
                            color: AppTheme.primaryGreen),
                      if (entry.value == value) const SizedBox(width: 8),
                      Text(labels[entry.key]),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

