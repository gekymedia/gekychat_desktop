import 'package:flutter/material.dart';

import 'desktop_typography.dart';

/// Centered modal dialog for desktop — WhatsApp/Telegram-style overlays.
Future<T?> showDesktopCenterModal<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  List<Widget>? headerActions,
  double maxWidth = 560,
  double maxHeightFraction = 0.85,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          child: Material(
            color: isDark ? const Color(0xFF111B21) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: DesktopTypography.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (headerActions != null) ...headerActions,
                      IconButton(
                        tooltip: 'Close',
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white70 : const Color(0xFF54656F),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE9EDEF),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      );
    },
  );
}
