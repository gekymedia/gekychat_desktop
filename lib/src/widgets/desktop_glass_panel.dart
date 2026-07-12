import 'dart:ui';

import 'package:flutter/material.dart';

import 'desktop_typography.dart';

/// Frosted acrylic panel used for desktop popovers and context menus.
class DesktopGlassPanel extends StatelessWidget {
  const DesktopGlassPanel({
    super.key,
    required this.isDark,
    required this.child,
    this.borderRadius = 14,
    this.prominentShadow = false,
    this.solid = false,
  });

  final bool isDark;
  final Widget child;
  final double borderRadius;
  final bool prominentShadow;
  /// Opaque panel (no blur) — for menus that should read as flat white/dark.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final solidFill =
        isDark ? const Color(0xFF202C33) : Colors.white;
    final solidBorder = isDark
        ? const Color(0xFF2A3942)
        : const Color(0xFFE9EDEF);
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.82);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.65);

    final shadows = prominentShadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.20),
              blurRadius: 36,
              offset: const Offset(0, 12),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ];

    final decoration = BoxDecoration(
      color: solid ? solidFill : fill,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: solid ? solidBorder : border),
      boxShadow: shadows,
    );

    if (solid) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: DecoratedBox(decoration: decoration, child: child),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}

class DesktopGlassMenuRow extends StatelessWidget {
  const DesktopGlassMenuRow({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.isDestructive = false,
    this.accentColor,
  }) : assert(icon != null || leading != null);

  final IconData? icon;
  final Widget? leading;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final fg = accentColor ??
        (isDestructive
            ? const Color(0xFFEA4335)
            : (isDark ? Colors.white : const Color(0xFF111B21)));
    final iconColor = isDark ? Colors.white70 : const Color(0xFF54656F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              leading ??
                  Icon(
                    icon,
                    size: 20,
                    color: accentColor ?? iconColor,
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: DesktopTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
