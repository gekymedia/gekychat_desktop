import 'package:flutter/material.dart';
import 'desktop_typography.dart';

/// WhatsApp-style perfect-pill filter chip for the chat list.
class DesktopFilterPill extends StatefulWidget {
  const DesktopFilterPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  State<DesktopFilterPill> createState() => _DesktopFilterPillState();
}

class _DesktopFilterPillState extends State<DesktopFilterPill> {
  static const _accent = Color(0xFF008069);
  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    final selectedBg = _accent;
    final unselectedBg =
        widget.isDark ? const Color(0xFF2A3942) : const Color(0xFFF0F2F5);
    final fg = widget.isSelected
        ? Colors.white
        : (widget.isDark ? Colors.white60 : const Color(0xFF667781));

    return AnimatedScale(
      scale: widget.isSelected ? 1.0 : 0.98,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        height: _height,
        child: Material(
          color: widget.isSelected ? selectedBg : unselectedBg,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: AnimatedOpacity(
              opacity: widget.isSelected ? 1 : 0.92,
              duration: const Duration(milliseconds: 150),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: DesktopTypography.fontFamily,
                        color: fg,
                        fontSize: DesktopTypography.filterChipSize,
                        fontWeight:
                            widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    if (widget.badgeCount != null && widget.badgeCount! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : (widget.isDark
                                  ? Colors.white24
                                  : Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.badgeCount! > 99
                              ? '99+'
                              : widget.badgeCount.toString(),
                          style: TextStyle(
                            fontFamily: DesktopTypography.fontFamily,
                            color: widget.isSelected ? Colors.white : fg,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
