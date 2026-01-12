import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/side_nav.dart';
import 'settings_screen.dart';

/// Wrapper for settings screen that includes the side nav
class SettingsWrapper extends ConsumerWidget {
  const SettingsWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      body: Row(
        children: [
          // Side Nav - keep visible
          RepaintBoundary(
            child: SideNav(currentRoute: '/settings'),
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
