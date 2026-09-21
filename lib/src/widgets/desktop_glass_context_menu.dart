import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'desktop_glass_panel.dart';
import 'desktop_glass_popup.dart';
import 'desktop_typography.dart';

/// Telegram-style context menu at a screen position (e.g. right-click on a message).
class DesktopGlassContextMenu {
  static const double _reactionBarWidth = 328;
  static const double _reactionBarHeight = 48;
  static const double _rowHeight = 44;
  static const double _padding = 6;
  static const double _menuMinWidth = 148;

  static double _computeMenuWidth(List<DesktopGlassMenuItem> items) {
    // Match DesktopGlassMenuRow compact padding: 16 left + 14 right.
    const horizontalPad = 30.0;
    const iconWidth = DesktopGlassMenuRow.iconSlot;
    const gap = 12.0;

    final style = TextStyle(
      fontFamily: DesktopTypography.fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    var maxLabel = 0.0;
    for (final item in items) {
      final tp = TextPainter(
        text: TextSpan(text: item.label, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      maxLabel = math.max(maxLabel, tp.width);
    }

    return (horizontalPad + iconWidth + gap + maxLabel + 4)
        .clamp(_menuMinWidth, _reactionBarWidth);
  }

  static Future<void> showAtPosition({
    required BuildContext context,
    required Offset globalPosition,
    required List<DesktopGlassMenuItem> items,
    List<String>? quickReactions,
    void Function(String emoji)? onQuickReaction,
    void Function()? onMoreReactions,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);

    final hasReactions =
        quickReactions != null &&
        quickReactions.isNotEmpty &&
        onQuickReaction != null;

    final menuItems = items.where((item) => !item.isDivider).toList();
    final actionMenuWidth = _computeMenuWidth(menuItems);
    final stackWidth =
        hasReactions ? _reactionBarWidth : actionMenuWidth;
    var menuHeight = _padding * 2 + menuItems.length * _rowHeight;
    if (hasReactions) {
      menuHeight += _reactionBarHeight + 8;
    }

    var left = globalPosition.dx;
    var top = globalPosition.dy;

    if (left + stackWidth > screenSize.width - 8) {
      left = screenSize.width - stackWidth - 8;
    }
    left = left.clamp(8.0, screenSize.width - stackWidth - 8);

    if (top + menuHeight > screenSize.height - 8) {
      top = globalPosition.dy - menuHeight;
    }
    top = top.clamp(8.0, screenSize.height - menuHeight - 8);

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 130),
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
                  width: stackWidth,
                  child: GestureDetector(
                    onTap: () {},
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasReactions)
                          SizedBox(
                            width: _reactionBarWidth,
                            child: _ReactionBar(
                              isDark: isDark,
                              emojis: quickReactions,
                              onReaction: (emoji) {
                                Navigator.pop(dialogContext);
                                onQuickReaction(emoji);
                              },
                              onMore: onMoreReactions == null
                                  ? null
                                  : () {
                                      Navigator.pop(dialogContext);
                                      onMoreReactions();
                                    },
                            ),
                          ),
                        if (hasReactions) const SizedBox(height: 8),
                        SizedBox(
                          width: actionMenuWidth,
                          child: DesktopGlassPanel(
                            isDark: isDark,
                            borderRadius: 14,
                            prominentShadow: true,
                            solid: true,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: _padding),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final item in menuItems)
                                    DesktopGlassMenuRow(
                                      icon: item.icon,
                                      leading: item.leading,
                                      label: item.label,
                                      isDark: isDark,
                                      isDestructive: item.isDestructive,
                                      accentColor: item.accentColor,
                                      compact: true,
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
                      ],
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
            scale: Tween<double>(begin: 0.94, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    required this.isDark,
    required this.emojis,
    required this.onReaction,
    this.onMore,
  });

  final bool isDark;
  final List<String> emojis;
  final void Function(String emoji) onReaction;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return DesktopGlassPanel(
      isDark: isDark,
      borderRadius: 24,
      prominentShadow: true,
      solid: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final emoji in emojis)
              _ReactionButton(emoji: emoji, onTap: () => onReaction(emoji)),
            if (onMore != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onMore,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: isDark ? Colors.white70 : const Color(0xFF54656F),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  const _ReactionButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(widget.emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }
}
