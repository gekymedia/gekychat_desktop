import 'package:flutter/material.dart';
import 'desktop_shell_colors.dart';

/// Chat list column with a draggable right edge (Telegram / WhatsApp desktop).
class ResizableSidebarPanel extends StatefulWidget {
  const ResizableSidebarPanel({
    super.key,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.isDark,
    required this.onWidthChanged,
    required this.child,
  });

  final double width;
  final double minWidth;
  final double maxWidth;
  final bool isDark;
  final ValueChanged<double> onWidthChanged;
  final Widget child;

  @override
  State<ResizableSidebarPanel> createState() => _ResizableSidebarPanelState();
}

class _ResizableSidebarPanelState extends State<ResizableSidebarPanel> {
  double? _dragWidth;
  bool _isDragging = false;

  double get _effectiveWidth => _dragWidth ?? widget.width;

  @override
  void didUpdateWidget(ResizableSidebarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && oldWidget.width != widget.width) {
      _dragWidth = null;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final next = (_effectiveWidth + details.delta.dx)
        .clamp(widget.minWidth, widget.maxWidth);
    setState(() {
      _isDragging = true;
      _dragWidth = next;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final finalWidth = _effectiveWidth;
    setState(() {
      _isDragging = false;
      _dragWidth = null;
    });
    widget.onWidthChanged(finalWidth);
  }

  @override
  Widget build(BuildContext context) {
    final panelRadius = DesktopShellColors.listPanelTopLeftBorderRadius;

    return SizedBox(
      width: _effectiveWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: panelRadius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DesktopShellColors.listPanelBackground(widget.isDark),
                  borderRadius: panelRadius,
                  border: Border(
                    right: BorderSide(
                      color: DesktopShellColors.listPanelBorder(widget.isDark),
                      width: 1,
                    ),
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: -3,
            width: 6,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: Align(
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: _isDragging ? 3 : 1,
                    height: double.infinity,
                    color: _isDragging
                        ? const Color(0xFF008069).withValues(alpha: 0.55)
                        : DesktopShellColors.listPanelBorder(widget.isDark)
                            .withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
