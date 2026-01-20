import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../auth/auth_provider.dart';
import '../multi_account/account_repository.dart' show accountRepositoryProvider, accountsProvider;
import 'profile_edit_screen.dart';
import '../quick_replies/quick_replies_screen.dart';
import '../auto_reply/auto_reply_screen.dart';
import '../labels/labels_screen.dart';
import '../two_factor/two_factor_screen.dart';
import '../linked_devices/linked_devices_screen.dart';
import '../privacy/privacy_settings_screen.dart';
import '../storage/storage_usage_screen.dart';
import '../media_auto_download/media_auto_download_screen.dart';
import '../notifications/notification_settings_screen.dart';
import '../../core/theme/theme_provider.dart' as custom_theme;
import '../../core/theme/app_theme_mode.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false, // Remove back button since side nav handles navigation
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
                  _SettingsTile(
                    icon: Icons.label,
                    title: 'Labels',
                    subtitle: 'Organize conversations with labels',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LabelsScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.smart_toy,
                    title: 'Auto-Reply Rules',
                    subtitle: 'Automatically reply to messages with keywords',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AutoReplyScreen(),
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
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out from your account',
                    onTap: () {
                      _showLogoutDialog(context, ref);
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
                      value: ref.watch(soundsEnabledProvider),
                      onChanged: (value) {
                        ref.read(soundsEnabledProvider.notifier).setEnabled(value);
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
                  Consumer(
                    builder: (context, ref, child) {
                      final customThemeMode = ref.watch(custom_theme.themeModeProvider);
                      return _SettingsTile(
                        icon: Icons.palette,
                        title: 'Theme',
                        subtitle: customThemeMode.displayName,
                        onTap: () {
                          _showThemeSelector(context, ref);
                        },
                      );
                    },
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
                  : () async {
                      Navigator.pop(context);
                      try {
                        final apiService = ref.read(apiServiceProvider);
                        // Map UI option to API key
                        String apiKey = 'last_seen';
                        if (selectedOption == 'My Contacts') {
                          apiKey = 'last_seen';
                        } else if (selectedOption == 'Nobody') {
                          apiKey = 'last_seen';
                        } else if (selectedOption == 'Everyone') {
                          apiKey = 'last_seen';
                        }
                        
                        await apiService.updatePrivacySettings({apiKey: selectedOption});
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Privacy setting updated'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update privacy: $e')),
                          );
                        }
                      }
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
                  : () async {
                      Navigator.pop(context);
                      try {
                        final apiService = ref.read(apiServiceProvider);
                        // Map UI option to API value
                        String apiValue = 'contacts';
                        if (selectedOption == 'My Contacts') {
                          apiValue = 'contacts';
                        } else if (selectedOption == 'My Contacts Except...') {
                          apiValue = 'contacts_except';
                        } else if (selectedOption == 'Only Share With...') {
                          apiValue = 'only_share_with';
                        }
                        
                        await apiService.put('/statuses/privacy', data: {'status_privacy': apiValue});
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Status privacy updated'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update status privacy: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Check if there are multiple accounts logged in
    final accountRepo = ref.read(accountRepositoryProvider);
    final accounts = await accountRepo.getAccounts();
    final prefs = await SharedPreferences.getInstance();
    final currentAccountId = prefs.getInt('current_account_id');
    
    // If there are multiple accounts, only remove the current account (not full logout)
    final isMultiAccount = accounts.length > 1;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          isMultiAccount ? 'Remove Account' : 'Logout',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          isMultiAccount 
            ? 'Are you sure you want to remove this account? You will be switched to another account if available.'
            : 'Are you sure you want to logout?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF008069)),
            child: Text(isMultiAccount ? 'Remove' : 'Logout', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (isMultiAccount && currentAccountId != null) {
          // Multi-account scenario: Remove current account only
          debugPrint('🔐 [LOGOUT] Removing account $currentAccountId (${accounts.length} accounts total)');
          
          // Find another account to switch to
          final otherAccount = accounts.firstWhere(
            (account) => account['id'] != currentAccountId,
            orElse: () => accounts.first,
          );
          final otherAccountId = otherAccount['id'] as int;
          
          // Remove the current account from the server
          try {
            await accountRepo.removeAccount(currentAccountId);
            debugPrint('✅ [LOGOUT] Removed account $currentAccountId from server');
          } catch (e) {
            debugPrint('⚠️ [LOGOUT] Failed to remove account from server: $e');
            // Continue anyway to switch accounts
          }
          
          // Switch to another account
          try {
            await accountRepo.switchAccount(otherAccountId);
            debugPrint('✅ [LOGOUT] Switched to account $otherAccountId');
            
            // Invalidate providers to refresh data
            ref.invalidate(currentUserProvider);
            ref.invalidate(accountsProvider); // Refresh account switcher
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Account removed. Switched to ${otherAccount['user']?['name'] ?? 'another account'}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            debugPrint('❌ [LOGOUT] Failed to switch to other account: $e');
            // If switching fails, do full logout
            await _performFullLogout(context, ref);
          }
        } else {
          // Single account scenario: Full logout
          await _performFullLogout(context, ref);
        }
      } catch (e) {
        debugPrint('❌ [LOGOUT] Error during logout: $e');
        // Fallback to full logout if anything fails
        await _performFullLogout(context, ref);
      }
    }
  }
  
  Future<void> _performFullLogout(BuildContext context, WidgetRef ref) async {
    debugPrint('🔐 [LOGOUT] Performing full logout');
    try {
      // Try to call logout API first (but don't block if it fails)
      try {
        final apiService = ref.read(apiServiceProvider);
        await apiService.logout();
      } catch (e) {
        // Ignore API errors - we'll clear local state anyway
        debugPrint('Logout API call failed (continuing anyway): $e');
      }
      
      // Clear auth state via provider
      ref.read(authProvider.notifier).logout();
      
      if (context.mounted) {
        // Navigate to login
        context.go('/login');
      }
    } catch (e) {
      // Even if there's an error, clear local state and navigate
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('current_account_id');
      ref.read(authProvider.notifier).logout();
      
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          'Delete Account',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Enter your password to confirm',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your password')),
                );
                return;
              }

              Navigator.pop(context);
              
              // Show confirmation dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
                  title: Text(
                    'Final Confirmation',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  content: Text(
                    'This is your last chance. Your account and all data will be permanently deleted. This cannot be undone.',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete Forever'),
                    ),
                  ],
                ),
              );

              if (confirmed != true) return;

              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.deleteAccount({'password': password});
                
                // Clear local storage
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                
                if (context.mounted) {
                  // Navigate to login
                  context.go('/login');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete account: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = ref.read(custom_theme.themeModeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          'Choose Theme',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((theme) {
            final isSelected = theme == currentTheme;
            return RadioListTile<AppThemeMode>(
              title: Text(
                theme.displayName,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                theme.isDark ? 'Dark mode' : 'Light mode',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              value: theme,
              groupValue: currentTheme,
              activeColor: const Color(0xFF008069),
              onChanged: (value) async {
                if (value != null) {
                  await ref.read(custom_theme.themeModeProvider.notifier).setThemeMode(value);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Theme changed to ${value.displayName}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
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
              'A modern chat application for desktop platforms.',
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

  Future<void> _showBirthdayDialog(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Load current birthday first
    int? currentMonth;
    int? currentDay;
    
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.getProfile();
      if (response.data != null) {
        currentMonth = response.data['dob_month'];
        currentDay = response.data['dob_day'];
      }
    } catch (e) {
      debugPrint('Failed to load birthday: $e');
    }
    
    if (!context.mounted) return;
    
    int? selectedMonth = currentMonth;
    int? selectedDay = currentDay;
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


