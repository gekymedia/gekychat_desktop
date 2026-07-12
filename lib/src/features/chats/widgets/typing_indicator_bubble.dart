import 'package:flutter/material.dart';

/// WhatsApp-style typing indicator: a small message bubble with three
/// animated dots that bounce in sequence.
class TypingIndicatorBubble extends StatefulWidget {
  const TypingIndicatorBubble({
    super.key,
    this.backgroundColor,
    this.dotColor,
    this.size = 40,
    this.dotRadius = 3,
  });

  final Color? backgroundColor;
  final Color? dotColor;
  final double size;
  final double dotRadius;

  @override
  State<TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg =
        widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final dot = widget.dotColor ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.size * 0.35,
        vertical: widget.size * 0.25,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.size * 0.4),
          topRight: Radius.circular(widget.size * 0.4),
          bottomLeft: Radius.circular(widget.dotRadius),
          bottomRight: Radius.circular(widget.size * 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final phase = i / 3;
              final t = (_controller.value + phase) % 1.0;
              final scale = 0.6 + 0.4 * _bounce(t);
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.dotRadius * 0.6,
                ),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.dotRadius * 2,
                    height: widget.dotRadius * 2,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  double _bounce(double t) {
    if (t < 0.2) return t / 0.2;
    if (t < 0.5) return 1.0;
    if (t < 0.7) return 1.0 - (t - 0.5) / 0.2;
    return 0.0;
  }
}
