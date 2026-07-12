import 'package:flutter/material.dart';

import 'desktop_shell_colors.dart';

/// WhatsApp-style chat wallpaper — tiles the doodle asset instead of stretching it.
///
/// Mobile chat uses [BoxFit.cover] on a small screen; on desktop the same asset is
/// repeated at native scale so patterns stay crisp on wide panes.
class GekyChatDoodleBackground extends StatelessWidget {
  final bool isDark;

  const GekyChatDoodleBackground({super.key, required this.isDark});

  static const String assetPath = 'assets/images/gekychat_doodle_bg.png';

  /// Doodle tile opacity — 30% softer than the mobile-aligned default.
  static double opacityForTheme(bool isDark) =>
      isDark ? 0.123 * 0.8 * 0.7 : 0.156 * 0.8 * 0.7;

  /// Warm cream tint — matches classic [ThemeData.scaffoldBackgroundColor].
  static const Color chatLightTint = Color(0xFFECE5DD);

  /// Semi-transparent cream wash over the doodle (1:1 / group threads only).
  static Color chatMessageAreaOverlay(
    BuildContext context, {
    required bool isDark,
    bool isDragging = false,
  }) {
    if (isDark) {
      final base = Theme.of(context).colorScheme.surface;
      return base.withValues(alpha: isDragging ? 0.70 : 0.30);
    }

    final cream = DesktopShellColors.chatThreadBackground(
      context,
      isDark: false,
    );
    final tinted = Color.lerp(
      Theme.of(context).colorScheme.surface,
      cream,
      0.42,
    )!;
    return tinted.withValues(alpha: isDragging ? 0.36 : 0.28);
  }

  @override
  Widget build(BuildContext context) {
    final opacity = opacityForTheme(isDark);

    Widget tiled = Image.asset(
      assetPath,
      repeat: ImageRepeat.repeat,
      fit: BoxFit.none,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => CustomPaint(
        painter: _ProceduralDoodlePainter(isDark: isDark),
        child: const SizedBox.expand(),
      ),
    );

    if (isDark) {
      tiled = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.31),
          BlendMode.darken,
        ),
        child: tiled,
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(opacity: opacity, child: tiled),
      ),
    );
  }
}

/// Procedural fallback — same tile grid as mobile incoming-call ring painter.
class _ProceduralDoodlePainter extends CustomPainter {
  final bool isDark;

  const _ProceduralDoodlePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.056 : 0.042)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const step = 80.0;
    for (double y = -20; y < size.height + step; y += step) {
      for (double x = -20; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x + 16, y + 16), 22, paint);
        canvas.drawCircle(Offset(x + 56, y + 8), 10, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProceduralDoodlePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
