import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/desktop_shell_colors.dart';
import '../../widgets/side_nav.dart';
import 'settings_screen.dart';

/// Wrapper for settings screen that includes the side nav
class SettingsWrapper extends ConsumerWidget {
  const SettingsWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellBackground =
        DesktopShellColors.shellChromeBackground(context, isDark: isDark);
    
    return Scaffold(
      backgroundColor: shellBackground,
      body: Row(
        children: [
          // Side Nav - keep visible
          RepaintBoundary(
            child: SideNav(
              currentRoute: '/settings',
              backgroundColor: shellBackground,
            ),
          ),
          // Settings content
          const Expanded(
            child: SettingsScreen(),
          ),
        ],
      ),
    );
  }
}
