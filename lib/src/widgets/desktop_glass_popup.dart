import 'package:flutter/material.dart';

import 'desktop_glass_panel.dart';

class DesktopGlassMenuItem {
  const DesktopGlassMenuItem({
    this.icon,
    this.leading,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.accentColor,
    this.isDivider = false,
  }) : assert(isDivider || icon != null || leading != null);

  const DesktopGlassMenuItem.divider()
      : icon = Icons.remove,
        leading = null,
        label = '',
        onTap = _noop,
        isDestructive = false,
        accentColor = null,
        isDivider = true;

  static void _noop() {}

  final IconData? icon;
  final Widget? leading;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? accentColor;
  final bool isDivider;
}

/// Frosted-glass anchored popup menu (iOS-style) for desktop dropdowns.
class DesktopGlassPopup {
  static const double _menuWidth = 248;
  static const double _gap = 6;
  static const double _menuRadius = 18;

  static Future<void> show({
    required BuildContext context,
    required BuildContext anchorContext,
    required List<DesktopGlassMenuItem> items,
    bool alignRight = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.sizeOf(context);

    double left = 12;
    double top = 72;

    if (anchorBox != null && anchorBox.hasSize) {
      final anchorTopLeft = anchorBox.localToGlobal(Offset.zero);
      final anchorSize = anchorBox.size;
      top = anchorTopLeft.dy + anchorSize.height + _gap;
      if (alignRight) {
        left = anchorTopLeft.dx + anchorSize.width - _menuWidth;
      } else {
        left = anchorTopLeft.dx;
      }
      left = left.clamp(8.0, screenSize.width - _menuWidth - 8);
      top = top.clamp(8.0, screenSize.height - 8);
    }

    final menuItems = items;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, _, __) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => Navigator.pop(dialogContext),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: _menuWidth,
                  child: GestureDetector(
                    onTap: () {},
                    child: DesktopGlassPanel(
                      isDark: isDark,
                      prominentShadow: true,
                      solid: true,
                      borderRadius: _menuRadius,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final item in menuItems)
                              if (item.isDivider)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: isDark
                                        ? const Color(0xFF2A3942)
                                        : const Color(0xFFE9EDEF),
                                  ),
                                )
                              else
                                DesktopGlassMenuRow(
                                  icon: item.icon,
                                  leading: item.leading,
                                  label: item.label,
                                  isDark: isDark,
                                  isDestructive: item.isDestructive,
                                  accentColor: item.accentColor,
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    item.onTap();
                                  },
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }
}
