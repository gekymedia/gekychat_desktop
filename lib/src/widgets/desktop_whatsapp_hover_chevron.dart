import 'package:flutter/material.dart';

/// WhatsApp Web–style downward chevron shown on hover (message bubbles & chat list).
class DesktopWhatsappHoverChevron extends StatelessWidget {
  const DesktopWhatsappHoverChevron({
    super.key,
    required this.visible,
    required this.onTap,
    required this.isDark,
    this.tooltip = 'Menu',
    this.size = 18,
    this.embedded = false,
  });

  final bool visible;
  final VoidCallback onTap;
  final bool isDark;
  final String tooltip;
  final double size;
  /// When true, renders flush inside a message bubble (no card elevation).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final iconColor = embedded
        ? (isDark ? Colors.white70 : const Color(0xFF667781))
        : (isDark ? Colors.white70 : const Color(0xFF8696A0));

    final chevron = Icon(
      Icons.keyboard_arrow_down_rounded,
      size: size,
      color: iconColor,
    );

    final child = embedded
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: chevron,
            ),
          )
        : InkWell(
            onTap: onTap,
            splashColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            child: SizedBox(
              width: size + 6,
              height: size + 4,
              child: chevron,
            ),
          );

    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: !visible,
        child: Semantics(
          label: tooltip,
          button: true,
          child: embedded
              ? child
              : Material(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  elevation: visible ? 1 : 0,
                  shadowColor: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  clipBehavior: Clip.antiAlias,
                  child: child,
                ),
        ),
      ),
    );
  }
}

/// Date + hover chevron column for chat list rows (chevron sits below the time).
class DesktopChatListTimeMenuColumn extends StatelessWidget {
  const DesktopChatListTimeMenuColumn({
    super.key,
    required this.time,
    required this.timeStyle,
    required this.isHovered,
    required this.isDark,
    required this.onMenuTap,
    this.showMenu = true,
  });

  final String time;
  final TextStyle timeStyle;
  final bool isHovered;
  final bool isDark;
  final void Function(Offset globalPosition)? onMenuTap;
  final bool showMenu;

  void _openMenu(BuildContext chevronContext) {
    final onMenu = onMenuTap;
    if (onMenu == null) return;

    final renderObject = chevronContext.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final anchor = renderObject.localToGlobal(
        Offset(renderObject.size.width, renderObject.size.height),
      );
      onMenu(anchor);
      return;
    }

    onMenu(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(time, style: timeStyle),
        if (showMenu && onMenuTap != null && isHovered) ...[
          const SizedBox(height: 1),
          Builder(
            builder: (chevronContext) => DesktopWhatsappHoverChevron(
              visible: true,
              isDark: isDark,
              onTap: () => _openMenu(chevronContext),
              size: 16,
            ),
          ),
        ],
      ],
    );
  }
}
