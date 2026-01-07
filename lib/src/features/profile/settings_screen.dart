import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers.dart';
import 'profile_edit_screen.dart';
import '../quick_replies/quick_replies_screen.dart';
import '../two_factor/two_factor_screen.dart';
import '../linked_devices/linked_devices_screen.dart';
import '../privacy/privacy_settings_screen.dart';
import '../storage/storage_usage_screen.dart';
import '../media/media_gallery_screen.dart';
import '../media_auto_download/media_auto_download_screen.dart';
import '../notifications/notification_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SettingsSection(
                title: 'Account',
                children: [
                  _SettingsTile(
                    icon: Icons.person,
                    title: 'Profile',
                    subtitle: 'Update your name, avatar, and about',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileEditScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.cake,
                    title: 'Birthday',
                    subtitle: 'Set your birth month and day',
                    onTap: () {
                      _showBirthdayDialog(context, ref);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'Chat',
                children: [
                  _SettingsTile(
                    icon: Icons.reply,
                    title: 'Quick Replies',
                    subtitle: 'Manage your quick reply messages',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuickRepliesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'Privacy',
                children: [
                  _SettingsTile(
                    icon: Icons.privacy_tip,
                    title: 'Privacy Settings',
                    subtitle: 'Manage all privacy preferences',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacySettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'Account',
                children: [
                  _SettingsTile(
                    icon: Icons.security,
                    title: 'Two-Step Verification',
                    subtitle: 'Add extra security to your account',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TwoFactorScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.devices,
                    title: 'Linked Devices',
                    subtitle: 'View and manage devices',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LinkedDevicesScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.delete_forever,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account',
                    onTap: () {
                      _showDeleteAccountDialog(context, ref);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'Notifications',
                children: [
                  _SettingsTile(
                    icon: Icons.notifications,
                    title: 'Notification Settings',
                    subtitle: 'Manage notification preferences',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.volume_up,
                    title: 'Sounds',
                    subtitle: 'Message and call sounds',
                    trailing: Switch(
                      value: true, // TODO: Load from preferences
                      onChanged: (value) {
                        // TODO: Save to preferences
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'Data & Storage',
                children: [
                  _SettingsTile(
                    icon: Icons.storage,
                    title: 'Storage Usage',
                    subtitle: 'View and manage storage',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StorageUsageScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.download,
                    title: 'Media Auto-Download',
                    subtitle: 'Control auto-download settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MediaAutoDownloadScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'App',
                children: [
                  _SettingsTile(
                    icon: Icons.dark_mode,
                    title: 'Theme',
                    subtitle: 'Switch between light and dark mode',
                    trailing: Consumer(
                      builder: (context, ref, child) {
                        final themeMode = ref.watch(themeProvider);
                        final isDark = themeMode == ThemeMode.dark || 
                            (themeMode == ThemeMode.system && 
                             Theme.of(context).brightness == Brightness.dark);
                        return Switch(
                          value: isDark,
                          onChanged: (value) {
                            ref.read(themeProvider.notifier).setTheme(
                              value ? ThemeMode.dark : ThemeMode.light,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.info,
                    title: 'About',
                    subtitle: 'App version and information',
                    onTap: () {
                      _showAboutDialog(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context, WidgetRef ref, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = ['Everyone', 'My Contacts', 'Nobody'];
    String? selectedOption;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          title: Text(
            'Privacy: ${type.replaceAll('_', ' ').toUpperCase()}',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: selectedOption,
                onChanged: (value) => setState(() => selectedOption = value),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedOption == null
                  ? null
                  : () {
                      // TODO: Implement privacy setting update
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Privacy setting updated: $selectedOption')),
                      );
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusPrivacyDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = ['My Contacts', 'My Contacts Except...', 'Only Share With...'];
    String? selectedOption;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          title: Text(
            'Status Privacy',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: selectedOption,
                onChanged: (value) => setState(() => selectedOption = value),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedOption == null
                  ? null
                  : () {
                      // TODO: Implement status privacy update via API
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Status privacy updated: $selectedOption')),
                      );
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          'Delete Account',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement account deletion
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion coming soon')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          'About',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GekyChat Desktop',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'A WhatsApp-style chat application for desktop platforms.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBirthdayDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int? selectedMonth;
    int? selectedDay;
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          title: Text(
            'Set Birthday',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedMonth,
                      items: [
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(
                            value: m,
                            child: Text(m.toString().padLeft(2, '0')),
                          ),
                      ],
                      onChanged: (value) => setState(() => selectedMonth = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Day',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedDay,
                      items: [
                        for (var d = 1; d <= 31; d++)
                          DropdownMenuItem(
                            value: d,
                            child: Text(d.toString().padLeft(2, '0')),
                          ),
                      ],
                      onChanged: (value) => setState(() => selectedDay = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: saving || selectedMonth == null || selectedDay == null
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        final api = ref.read(apiServiceProvider);
                        await api.updateDob(month: selectedMonth, day: selectedDay);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Birthday updated successfully')),
                          );
                        }
                      } catch (e) {
                        setState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}


