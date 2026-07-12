import 'package:flutter/material.dart';

import 'desktop_typography.dart';

/// Modern chat-list row chrome: inset pill selection, hover, unread accent.
class DesktopChatListItemShell extends StatefulWidget {
  const DesktopChatListItemShell({
    super.key,
    required this.isSelected,
    required this.hasUnread,
    required this.onTap,
    this.child,
    this.builder,
    this.onLongPress,
    this.onSecondaryTapDown,
  }) : assert(child != null || builder != null,
            'Provide child or builder');

  final bool isSelected;
  final bool hasUnread;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails details)? onSecondaryTapDown;
  final Widget? child;
  final Widget Function(bool isHovered)? builder;

  static const double rowRadius = 10;
  static const EdgeInsets listOuterPadding =
      EdgeInsets.symmetric(horizontal: 8, vertical: 2);

  @override
  State<DesktopChatListItemShell> createState() =>
      _DesktopChatListItemShellState();
}

class _DesktopChatListItemShellState extends State<DesktopChatListItemShell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedFill =
        isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF);
    final hoverFill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final fill = widget.isSelected
        ? selectedFill
        : (_hovered ? hoverFill : Colors.transparent);

    return Padding(
      padding: DesktopChatListItemShell.listOuterPadding,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onSecondaryTapDown: widget.onSecondaryTapDown,
            borderRadius: BorderRadius.circular(
              DesktopChatListItemShell.rowRadius,
            ),
            hoverColor: Colors.transparent,
            splashColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(
                  DesktopChatListItemShell.rowRadius,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (widget.hasUnread && !widget.isSelected)
                    Positioned(
                      left: 0,
                      top: 12,
                      bottom: 12,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: widget.builder != null
                        ? widget.builder!(_hovered)
                        : widget.child!,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar with optional selection ring.
class DesktopListAvatar extends StatelessWidget {
  const DesktopListAvatar({
    super.key,
    required this.isSelected,
    required this.child,
    this.size = DesktopTypography.listAvatarSize,
  });

  final bool isSelected;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringColor = isSelected
        ? const Color(0xFF008069)
        : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor,
          width: isSelected ? 2 : 0,
        ),
        boxShadow: isSelected && !isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF008069).withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ClipOval(child: child),
    );
  }
}
