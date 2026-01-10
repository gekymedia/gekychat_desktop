import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/theme_provider.dart';
import '../core/theme/app_theme_mode.dart';

/// Quick toggle widget for theme switching
class ThemeQuickToggle extends ConsumerWidget {
  const ThemeQuickToggle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color scheme toggle
        IconButton(
          icon: Icon(
            currentTheme.isGolden ? Icons.star : Icons.chat_bubble,
            color: Color(currentTheme.primaryColorValue),
          ),
          tooltip: currentTheme.isGolden ? 'Switch to Classic' : 'Switch to Golden',
          onPressed: () {
            ref.read(themeModeProvider.notifier).toggleColorScheme();
          },
        ),
        // Brightness toggle
        IconButton(
          icon: Icon(
            currentTheme.isDark ? Icons.light_mode : Icons.dark_mode,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          tooltip: currentTheme.isDark ? 'Switch to Light' : 'Switch to Dark',
          onPressed: () {
            ref.read(themeModeProvider.notifier).toggleBrightness();
          },
        ),
      ],
    );
  }
}

/// Floating theme toggle button
class FloatingThemeToggle extends ConsumerWidget {
  const FloatingThemeToggle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);

    return FloatingActionButton.small(
      heroTag: 'theme_toggle',
      backgroundColor: Color(currentTheme.primaryColorValue),
      onPressed: () {
        _showThemeMenu(context, ref);
      },
      child: Icon(
        currentTheme.isGolden ? Icons.star : Icons.palette,
        color: Colors.white,
      ),
    );
  }

  void _showThemeMenu(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quick Theme Switch',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            // Color scheme buttons
            Row(
              children: [
                Expanded(
                  child: _buildThemeButton(
                    context: context,
                    ref: ref,
                    label: 'Golden',
                    icon: Icons.star,
                    color: const Color(0xFFD4AF37),
                    isSelected: currentTheme.isGolden,
                    onTap: () {
                      if (!currentTheme.isGolden) {
                        ref.read(themeModeProvider.notifier).toggleColorScheme();
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeButton(
                    context: context,
                    ref: ref,
                    label: 'Classic',
                    icon: Icons.chat_bubble,
                    color: const Color(0xFF008069),
                    isSelected: !currentTheme.isGolden,
                    onTap: () {
                      if (currentTheme.isGolden) {
                        ref.read(themeModeProvider.notifier).toggleColorScheme();
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Brightness buttons
            Row(
              children: [
                Expanded(
                  child: _buildThemeButton(
                    context: context,
                    ref: ref,
                    label: 'Light',
                    icon: Icons.light_mode,
                    color: Color(currentTheme.primaryColorValue),
                    isSelected: currentTheme.isLight,
                    onTap: () {
                      if (currentTheme.isDark) {
                        ref.read(themeModeProvider.notifier).toggleBrightness();
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeButton(
                    context: context,
                    ref: ref,
                    label: 'Dark',
                    icon: Icons.dark_mode,
                    color: Color(currentTheme.primaryColorValue),
                    isSelected: currentTheme.isDark,
                    onTap: () {
                      if (currentTheme.isLight) {
                        ref.read(themeModeProvider.notifier).toggleBrightness();
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeButton({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : (isDark ? const Color(0xFF3B4A54) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
