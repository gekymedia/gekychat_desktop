import 'package:flutter/material.dart';
import '../../../widgets/desktop_typography.dart';

/// WhatsApp Web–style floating composer bar.
class DesktopMessageComposerPill extends StatelessWidget {
  const DesktopMessageComposerPill({
    super.key,
    required this.isDark,
    required this.textField,
    required this.trailing,
    this.onEmoji,
    this.onAttach,
  });

  final bool isDark;
  final Widget textField;
  final Widget trailing;
  final void Function(BuildContext anchorContext)? onEmoji;
  final void Function(BuildContext anchorContext)? onAttach;

  static const double barHeight = 52;

  /// Half the bar height — true stadium / pill ends on a single-line composer.
  static double get barRadius => barHeight / 2;

  static BorderRadius get composerBorderRadius =>
      BorderRadius.circular(barRadius);

  static InputDecoration fieldDecoration(bool isDark) {
    return InputDecoration(
      hintText: 'Type a message',
      hintStyle: TextStyle(
        fontFamily: DesktopTypography.fontFamily,
        color: isDark ? Colors.white38 : const Color(0xFF667781),
        fontSize: DesktopTypography.messageBodySize,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? const Color(0xFF2A3942) : Colors.white;
    final iconColor = isDark ? Colors.white70 : const Color(0xFF54656F);

    return ClipRRect(
      borderRadius: composerBorderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: composerBorderRadius,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: barHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (onEmoji != null)
                Builder(
                  builder: (emojiContext) => _ComposerIconButton(
                    icon: Icons.emoji_emotions_outlined,
                    color: iconColor,
                    tooltip: 'Emoji',
                    onPressed: () => onEmoji!(emojiContext),
                  ),
                ),
              if (onAttach != null)
                Builder(
                  builder: (attachContext) => _ComposerIconButton(
                    icon: Icons.attach_file,
                    color: iconColor,
                    tooltip: 'Attach',
                    onPressed: () => onAttach!(attachContext),
                  ),
                ),
              Expanded(child: textField),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: DesktopMessageComposerPill.barHeight,
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}
