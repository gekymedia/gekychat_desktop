import 'package:flutter/material.dart';

import '../../../widgets/desktop_glass_panel.dart';
import 'emoji_picker_widget.dart';

/// WhatsApp-style emoji picker popup anchored above the composer emoji button.
class DesktopEmojiPickerPopup {
  static const double _panelWidth = 380;
  static const double _panelHeight = 400;
  static const double _gapAboveAnchor = 8;

  static Future<void> show(
    BuildContext context, {
    required BuildContext anchorContext,
    required void Function(String emoji) onEmojiSelected,
    required VoidCallback onBackspace,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.sizeOf(context);

    double left = 12;
    double bottom = 76;

    if (anchorBox != null && anchorBox.hasSize) {
      final anchorTopLeft = anchorBox.localToGlobal(Offset.zero);
      final anchorSize = anchorBox.size;
      final anchorCenterX = anchorTopLeft.dx + anchorSize.width / 2;

      left = (anchorCenterX - _panelWidth / 2)
          .clamp(8.0, screenSize.width - _panelWidth - 8);
      bottom = screenSize.height - anchorTopLeft.dy + _gapAboveAnchor;
    }

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss emoji picker',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
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
                  bottom: bottom,
                  width: _panelWidth,
                  height: _panelHeight,
                  child: GestureDetector(
                    onTap: () {},
                    child: DesktopGlassPanel(
                      isDark: isDark,
                      borderRadius: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: EmojiPickerWidget(
                          height: _panelHeight,
                          popupStyle: true,
                          onEmojiSelected: onEmojiSelected,
                          onBackspace: onBackspace,
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
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
