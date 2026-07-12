import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_typography.dart';
import 'keyboard_shortcuts_dialog.dart';

/// One-time dismissible banner prompting users to discover keyboard shortcuts.
class DesktopShortcutsHint extends StatefulWidget {
  const DesktopShortcutsHint({super.key});

  static const _prefKey = 'desktop_shortcuts_hint_dismissed_v1';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKey) ?? false);
  }

  static Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  State<DesktopShortcutsHint> createState() => _DesktopShortcutsHintState();
}

class _DesktopShortcutsHintState extends State<DesktopShortcutsHint> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final show = await DesktopShortcutsHint.shouldShow();
    if (mounted) setState(() => _visible = show);
  }

  Future<void> _dismiss() async {
    await DesktopShortcutsHint.dismiss();
    if (mounted) setState(() => _visible = false);
  }

  void _openShortcuts() {
    showDialog<void>(
      context: context,
      builder: (context) => const KeyboardShortcutsDialog(),
    );
    unawaited(_dismiss());
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF202C33) : Colors.white;
    final border = isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        elevation: isDark ? 0 : 4,
        shadowColor: Colors.black26,
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                Icon(
                  Icons.keyboard_outlined,
                  size: 20,
                  color: isDark ? Colors.white70 : const Color(0xFF667781),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: Press Ctrl+Shift+/ for keyboard shortcuts',
                    style: TextStyle(
                      fontFamily: DesktopTypography.fontFamily,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF54656F),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openShortcuts,
                  child: const Text('View'),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: _dismiss,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
