import 'package:flutter/material.dart';
import 'dart:math' as math;

class StatusRing extends StatelessWidget {
  final Widget child;
  final double size;
  final double strokeWidth;
  final bool hasViewed;
  final int totalSegments;
  final int viewedSegments;
  final VoidCallback? onTap;
  
  const StatusRing({
    super.key,
    required this.child,
    this.size = 60,
    this.strokeWidth = 3,
    this.hasViewed = false,
    this.totalSegments = 1,
    this.viewedSegments = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (totalSegments > 0)
              CustomPaint(
                size: Size(size, size),
                painter: _StatusRingPainter(
                  totalSegments: totalSegments,
                  viewedSegments: viewedSegments,
                  strokeWidth: strokeWidth,
                  hasViewed: hasViewed,
                ),
              ),
            Container(
              width: size - (strokeWidth * 2 + 4),
              height: size - (strokeWidth * 2 + 4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRingPainter extends CustomPainter {
  final int totalSegments;
  final int viewedSegments;
  final double strokeWidth;
  final bool hasViewed;

  _StatusRingPainter({
    required this.totalSegments,
    required this.viewedSegments,
    required this.strokeWidth,
    required this.hasViewed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const gapAngle = math.pi / 180 * 4;
    final segmentAngle = (2 * math.pi - (gapAngle * totalSegments)) / totalSegments;

    for (int i = 0; i < totalSegments; i++) {
      final startAngle = -math.pi / 2 + (segmentAngle + gapAngle) * i;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      if (i < viewedSegments || hasViewed) {
        paint.color = Colors.grey.shade400;
      } else {
        paint.color = const Color(0xFF00D856);
      }

      canvas.drawArc(
        rect,
        startAngle,
        segmentAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StatusRingPainter oldDelegate) {
    return oldDelegate.totalSegments != totalSegments ||
        oldDelegate.viewedSegments != viewedSegments ||
        oldDelegate.hasViewed != hasViewed;
  }
}

class AddStatusButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  
  const AddStatusButton({
    super.key,
    required this.onTap,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade300,
              ),
              child: Icon(
                Icons.person,
                size: size * 0.5,
                color: Colors.grey.shade600,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.35,
                height: size * 0.35,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00A884),
                ),
                child: Icon(
                  Icons.add,
                  size: size * 0.25,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


