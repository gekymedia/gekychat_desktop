import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme_mode.dart';
import '../../core/theme/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
      ),
      body: ListView(
        children: [
          // Color Scheme Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Color Scheme',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          _buildThemeCard(
            context: context,
            ref: ref,
            mode: currentTheme.isDark ? AppThemeMode.goldenDark : AppThemeMode.goldenLight,
            title: 'Golden',
            subtitle: 'Elegant gold theme',
            icon: Icons.star,
            iconColor: const Color(0xFFD4AF37),
            isSelected: currentTheme.isGolden,
          ),
          _buildThemeCard(
            context: context,
            ref: ref,
            mode: currentTheme.isDark ? AppThemeMode.whiteDark : AppThemeMode.whiteLight,
            title: 'Classic',
            subtitle: 'WhatsApp-style green theme',
            icon: Icons.chat_bubble,
            iconColor: const Color(0xFF008069),
            isSelected: !currentTheme.isGolden,
          ),

          const Divider(height: 32),

          // Brightness Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Brightness',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          _buildBrightnessCard(
            context: context,
            ref: ref,
            isLight: true,
            title: 'Light Mode',
            subtitle: 'Bright and clean interface',
            icon: Icons.light_mode,
            isSelected: currentTheme.isLight,
          ),
          _buildBrightnessCard(
            context: context,
            ref: ref,
            isLight: false,
            title: 'Dark Mode',
            subtitle: 'Easy on the eyes',
            icon: Icons.dark_mode,
            isSelected: currentTheme.isDark,
          ),

          const Divider(height: 32),

          // Preview Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Preview',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          _buildPreviewCard(context, currentTheme),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required WidgetRef ref,
    required AppThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: iconColor)
            : Icon(Icons.circle_outlined, color: isDark ? Colors.white38 : Colors.black38),
        onTap: () {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
      ),
    );
  }

  Widget _buildBrightnessCard({
    required BuildContext context,
    required WidgetRef ref,
    required bool isLight,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = ref.watch(themeModeProvider);
    final primaryColor = Color(currentTheme.primaryColorValue);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: primaryColor)
            : Icon(Icons.circle_outlined, color: isDark ? Colors.white38 : Colors.black38),
        onTap: () {
          final newMode = isLight
              ? (currentTheme.isGolden ? AppThemeMode.goldenLight : AppThemeMode.whiteLight)
              : (currentTheme.isGolden ? AppThemeMode.goldenDark : AppThemeMode.whiteDark);
          ref.read(themeModeProvider.notifier).setThemeMode(newMode);
        },
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, AppThemeMode currentTheme) {
    final isDark = currentTheme.isDark;
    final isGolden = currentTheme.isGolden;
    final primaryColor = Color(currentTheme.primaryColorValue);

    final backgroundColor = isDark
        ? (isGolden ? const Color(0xFF1A1410) : const Color(0xFF202C33))
        : (isGolden ? const Color(0xFFFFF8DC) : Colors.white);

    final textColor = isDark
        ? (isGolden ? const Color(0xFFD4AF37) : Colors.white)
        : (isGolden ? const Color(0xFF8B7500) : Colors.black87);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'John Doe',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Online',
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This is how your messages will look with the ${currentTheme.displayName} theme!',
                style: TextStyle(color: textColor),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.done_all, size: 16, color: primaryColor),
                const SizedBox(width: 4),
                Text(
                  '12:30 PM',
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
