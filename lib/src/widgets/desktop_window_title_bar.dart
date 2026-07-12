import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/desktop_window_service.dart';
import 'desktop_shell_colors.dart';
import 'desktop_typography.dart';

/// Custom cream title bar (Windows) — replaces native chrome when hidden.
class DesktopWindowTitleBar extends StatefulWidget {
  const DesktopWindowTitleBar({super.key});

  static bool get isSupported => Platform.isWindows;

  @override
  State<DesktopWindowTitleBar> createState() => _DesktopWindowTitleBarState();
}

class _DesktopWindowTitleBarState extends State<DesktopWindowTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _refreshMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _refreshMaximized() async {
    final value = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = value);
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    if (!DesktopWindowTitleBar.isSupported) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = DesktopShellColors.shellChromeBackground(context, isDark: isDark);
    final fg = isDark ? Colors.white70 : const Color(0xFF54656F);
    final border = isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/gold_no_text/32x32.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.chat_bubble,
                          size: 16,
                          color: fg,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'GekyChat',
                        style: TextStyle(
                          fontFamily: DesktopTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: fg,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _ChromeButton(
              icon: Icons.remove,
              tooltip: 'Minimize',
              foreground: fg,
              hover: isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF),
              onPressed: () => windowManager.minimize(),
            ),
            _ChromeButton(
              icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
              tooltip: _isMaximized ? 'Restore' : 'Maximize',
              foreground: fg,
              hover: isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF),
              onPressed: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
                await _refreshMaximized();
              },
            ),
            _ChromeButton(
              icon: Icons.close,
              tooltip: 'Close',
              foreground: fg,
              hover: const Color(0xFFE81123),
              hoverForeground: Colors.white,
              onPressed: DesktopWindowService.hideToTray,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChromeButton extends StatefulWidget {
  const _ChromeButton({
    required this.icon,
    required this.tooltip,
    required this.foreground,
    required this.hover,
    required this.onPressed,
    this.hoverForeground,
  });

  final IconData icon;
  final String tooltip;
  final Color foreground;
  final Color hover;
  final Color? hoverForeground;
  final Future<void> Function() onPressed;

  @override
  State<_ChromeButton> createState() => _ChromeButtonState();
}

class _ChromeButtonState extends State<_ChromeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = _hovered
        ? (widget.hoverForeground ?? widget.foreground)
        : widget.foreground;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onPressed(),
          child: Container(
            width: 46,
            height: 36,
            color: _hovered ? widget.hover : Colors.transparent,
            child: Icon(widget.icon, size: 14, color: iconColor),
          ),
        ),
      ),
    );
  }
}
