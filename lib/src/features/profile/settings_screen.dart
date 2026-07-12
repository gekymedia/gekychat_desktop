import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../auth/auth_provider.dart';
import '../multi_account/account_repository.dart' show accountRepositoryProvider, accountsProvider;
import '../multi_account/account_switcher_screen.dart';
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
import '../contacts/contacts_screen.dart';
import '../settings/language_settings_screen.dart';
import '../settings/realtime_metrics_screen.dart';
import '../support/issue_report_flow.dart';
import '../live/live_analytics_screen.dart';
import '../../core/theme/theme_provider.dart' as custom_theme;
import '../../core/theme/app_theme_mode.dart';
import '../../widgets/keyboard_shortcuts_dialog.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/settings_detail_modal.dart';
import '../../widgets/app_about_dialog.dart';

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
              Consumer(
                builder: (context, ref, _) {
                  final userAsync = ref.watch(currentUserProvider);
                  return userAsync.when(
                    data: (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: user.avatarUrl != null &&
                                    user.avatarUrl!.isNotEmpty
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: user.avatarUrl == null ||
                                    user.avatarUrl!.isEmpty
                                ? Text(
                                    (user.name.isNotEmpty
                                            ? user.name[0]
                                            : '?')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name.isNotEmpty ? user.name : 'Profile',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                if (user.username != null &&
                                    user.username!.isNotEmpty)
                                  Text(
                                    '@${user.username}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
              _SettingsSection(
                title: 'Account',
                children: [
                  _SettingsTile(
                    icon: Icons.person,
                    title: 'Profile',
                    subtitle: 'Update your name, avatar, and about',
                    onTap: () => ProfileEditScreen.showModal(context),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final userAsync = ref.watch(currentUserProvider);
                      final subtitle =
                          userAsync.valueOrNull?.birthdayFormatted ??
                          'Set your birth month, day, and year';
                      return _SettingsTile(
                        icon: Icons.cake,
                        title: 'Birthday',
                        subtitle: subtitle,
                        onTap: () {
                          _showBirthdayDialog(context, ref);
                        },
                      );
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
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Quick replies',
                      child: const QuickRepliesScreen(),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.label,
                    title: 'Labels',
                    subtitle: 'Organize conversations with labels',
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Labels',
                      child: const LabelsScreen(),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.smart_toy,
                    title: 'Auto-Reply Rules',
                    subtitle: 'Automatically reply to messages with keywords',
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Auto replies',
                      child: const AutoReplyScreen(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'Contacts',
                children: [
                  _SettingsTile(
                    icon: Icons.contacts,
                    title: 'Manage Contacts',
                    subtitle: 'View and manage your contacts',
                    onTap: () => ContactsScreen.showModal(context),
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
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Privacy',
                      child: const PrivacySettingsScreen(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'Help and feedback',
                children: [
                  _SettingsTile(
                    icon: Icons.report_problem_outlined,
                    title: 'Report a problem',
                    subtitle: 'Bugs, crashes, and technical issues',
                    onTap: () => IssueReportFlow.openFromSettings(context),
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline,
                    title: 'Help center',
                    subtitle: 'FAQs and how-to guides',
                    onTap: () => _openUrl(context, 'https://gekychat.com/help'),
                  ),
                  _SettingsTile(
                    icon: Icons.mail_outline,
                    title: 'Contact us',
                    subtitle: 'Get in touch with support',
                    onTap: () =>
                        _openUrl(context, 'https://gekychat.com/contact'),
                  ),
                  _SettingsTile(
                    icon: Icons.policy_outlined,
                    title: 'Privacy policy',
                    subtitle: 'How we handle your data',
                    onTap: () => _openUrl(
                      context,
                      'https://gekychat.com/privacy-policy',
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.delete_outline,
                    title: 'Request account deletion',
                    subtitle: 'Delete your account and data via web',
                    onTap: () => _openUrl(
                      context,
                      'https://gekychat.com/request-account-deletion',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'Creator',
                children: [
                  _SettingsTile(
                    icon: Icons.analytics_outlined,
                    title: 'Live analytics',
                    subtitle: 'Dashboard for your live broadcasts',
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Live analytics',
                      maxWidth: 720,
                      child: const LiveAnalyticsScreen(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'Security',
                children: [
                  _SettingsTile(
                    icon: Icons.security,
                    title: 'Two-Step Verification',
                    subtitle: 'Add extra security to your account',
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Two-step verification',
                      child: const TwoFactorScreen(),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.devices,
                    title: 'Linked Devices',
                    subtitle: 'View and manage devices',
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Linked devices',
                      child: const LinkedDevicesScreen(),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.swap_horiz,
                    title: 'Switch Account',
                    subtitle: 'Switch between multiple accounts',
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Switch account',
                      child: const AccountSwitcherScreen(),
                      maxWidth: 480,
                    ),
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
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Notification settings',
                      child: const NotificationSettingsScreen(),
                    ),
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
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Storage usage',
                      child: const StorageUsageScreen(),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.download,
                    title: 'Media Auto-Download',
                    subtitle: 'Control auto-download settings',
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Media auto-download',
                      child: const MediaAutoDownloadScreen(),
                    ),
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
                        subtitle: 'Choose theme color and brightness',
                        onTap: () {
                          _showThemeSelector(context, ref);
                        },
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.keyboard,
                    title: 'Keyboard Shortcuts',
                    subtitle: 'View all available shortcuts',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => const KeyboardShortcutsDialog(),
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final selectedLanguage = ref.watch(appLanguageProvider);
                      return _SettingsTile(
                        icon: Icons.language,
                        title: 'App Language',
                        subtitle: _languageDisplayName(selectedLanguage),
                        onTap: () => showSettingsDetailModal(
                          context,
                          title: 'App language',
                          child: const LanguageSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.monitor_heart_outlined,
                    title: 'Realtime Health',
                    subtitle: 'WebSocket delivery metrics',
                    onTap: () => showSettingsDetailModal(
                      context,
                      title: 'Realtime health',
                      child: const RealtimeMetricsScreen(),
                      maxWidth: 720,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.info,
                    title: 'About',
                    subtitle: 'App version and information',
                    onTap: () {
                      showAppAboutDialog(
                        context,
                        appName: 'GekyChat Desktop',
                        description:
                            'A modern chat application for desktop platforms.',
                      );
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

  static String _languageDisplayName(AppLanguage language) {
    if (language.code == 'system') return 'System default';
    return language.name;
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
                context.showErrorToast('Could not open $url');      }
    } catch (e) {
      if (context.mounted) {
                context.showErrorToast('Could not open link: $e');      }
    }
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
                        final api = ref.read(apiServiceProvider);
                        // Map UI option to API value (same as mobile)
                        String apiValue;
                        switch (selectedOption!) {
                          case 'Everyone':
                            apiValue = 'everyone';
                            break;
                          case 'My Contacts':
                            apiValue = 'contacts';
                            break;
                          case 'Nobody':
                            apiValue = 'nobody';
                            break;
                          default:
                            apiValue = 'contacts';
                        }
                        await api.updatePrivacySettings({type: apiValue});
                        if (context.mounted) {
                                                    context.showSuccessToast('Privacy setting updated successfully');                        }
                      } catch (e) {
                        if (context.mounted) {
                                                    context.showErrorToast('Failed to update privacy setting: $e');                        }
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
                                                    context.showSuccessToast('Status privacy updated');                        }
                      } catch (e) {
                        if (context.mounted) {
                                                    context.showErrorToast('Failed to update status privacy: $e');                        }
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
                            context.showSuccessToast('Account removed. Switched to ${otherAccount['user']?['name'] ?? 'another account'}');            }
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
                                context.showInfoToast('Please enter your password');                return;
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
                                    context.showSuccessToast('Account deleted successfully');                }
              } catch (e) {
                if (context.mounted) {
                                    context.showErrorToast('Failed to delete account: $e');                }
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
    final currentTheme = ref.watch(custom_theme.themeModeProvider);

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          title: Text(
            'Theme Settings',
            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Colors',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: [
                      _buildThemeGridOption(context, isDark, 'Classic', Icons.chat_bubble,
                          const Color(0xFF008069), currentTheme.themeColor == ThemeColor.classic, () {
                        ref.read(custom_theme.themeModeProvider.notifier).setColorScheme(ThemeColor.classic, context);
                        Navigator.pop(context);
                      }),
                      _buildThemeGridOption(context, isDark, 'Golden', Icons.star,
                          const Color(0xFFD4AF37), currentTheme.themeColor == ThemeColor.golden, () {
                        ref.read(custom_theme.themeModeProvider.notifier).setColorScheme(ThemeColor.golden, context);
                        Navigator.pop(context);
                      }),
                      _buildThemeGridOption(context, isDark, 'Telegram', Icons.send,
                          const Color(0xFF3390EC), currentTheme.themeColor == ThemeColor.telegram, () {
                        ref.read(custom_theme.themeModeProvider.notifier).setColorScheme(ThemeColor.telegram, context);
                        Navigator.pop(context);
                      }),
                      _buildThemeGridOption(context, isDark, 'Blue', Icons.palette,
                          const Color(0xFF2196F3), currentTheme.themeColor == ThemeColor.blue, () {
                        ref.read(custom_theme.themeModeProvider.notifier).setColorScheme(ThemeColor.blue, context);
                        Navigator.pop(context);
                      }),
                      _buildThemeGridOption(context, isDark, 'Pink', Icons.favorite,
                          const Color(0xFFE91E63), currentTheme.themeColor == ThemeColor.pink, () {
                        ref.read(custom_theme.themeModeProvider.notifier).setColorScheme(ThemeColor.pink, context);
                        Navigator.pop(context);
                      }),
                      _buildThemeGridOption(context, isDark, 'AMOLED', Icons.brightness_2, Colors.black,
                          currentTheme.themeColor == ThemeColor.amoled, () {
                        ref.read(custom_theme.themeModeProvider.notifier).setColorScheme(ThemeColor.amoled, context);
                        Navigator.pop(context);
                      }),
                      _buildThemeGridOption(context, isDark, 'iOS', Icons.phone_iphone,
                          const Color(0xFF007AFF), currentTheme.themeColor == ThemeColor.ios, () {
                        ref.read(custom_theme.themeModeProvider.notifier).setColorScheme(ThemeColor.ios, context);
                        Navigator.pop(context);
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Brightness',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBrightnessOption(context, isDark, 'Light', Icons.light_mode, !currentTheme.isDark, () {
                    ref.read(custom_theme.themeModeProvider.notifier).setBrightness(false);
                    Navigator.pop(context);
                  }),
                  const SizedBox(height: 8),
                  _buildBrightnessOption(context, isDark, 'Dark', Icons.dark_mode, currentTheme.isDark, () {
                    ref.read(custom_theme.themeModeProvider.notifier).setBrightness(true);
                    Navigator.pop(context);
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeGridOption(
    BuildContext context,
    bool isDark,
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, color: color, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessOption(
    BuildContext context,
    bool isDark,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surfaceContainerHighest : Colors.transparent,
          border: Border.all(
            color: isSelected ? theme.colorScheme.outline : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurface, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check, color: theme.colorScheme.onSurface, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showBirthdayDialog(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Load current birthday first
    int? currentMonth;
    int? currentDay;
    int? currentYear;

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.getProfile();
      final raw = response.data;
      final Map<String, dynamic>? profile = raw is Map
          ? (raw['data'] is Map
                ? Map<String, dynamic>.from(raw['data'] as Map)
                : Map<String, dynamic>.from(raw))
          : null;
      if (profile != null) {
        final user = UserProfile.fromJson(profile);
        currentMonth = user.dobMonth;
        currentDay = user.dobDay;
        currentYear = user.dobYear;
      }
    } catch (e) {
      debugPrint('Failed to load birthday: $e');
    }

    if (!context.mounted) return;

    int? selectedMonth = currentMonth;
    int? selectedDay = currentDay;
    int? selectedYear = currentYear;
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          title: Text(
            'Set Birthday',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: selectedMonth,
                        items: [
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(
                              value: m,
                              child: Text(_monthName(m)),
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
                        initialValue: selectedDay,
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
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: selectedYear,
                  items: [
                    for (var y = now.year; y >= now.year - 120; y--)
                      DropdownMenuItem(value: y, child: Text(y.toString())),
                  ],
                  onChanged: (value) => setState(() => selectedYear = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: saving || selectedMonth == null || selectedDay == null
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        final api = ref.read(apiServiceProvider);
                        await api.updateDob(
                          month: selectedMonth,
                          day: selectedDay,
                          year: selectedYear,
                        );
                        if (dialogContext.mounted) {
                          ref.invalidate(currentUserProvider);
                          Navigator.pop(dialogContext);
                          context.showSuccessToast('Birthday updated successfully');
                        }
                      } catch (e) {
                        setState(() => saving = false);
                        if (dialogContext.mounted) {
                          context.showErrorToast('Failed: $e');
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

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _monthName(int month) => _monthNames[month - 1];
