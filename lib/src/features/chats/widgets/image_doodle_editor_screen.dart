import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Show pen markup as a transparent overlay on top of the current screen
/// (same image stays visible underneath — WhatsApp/Tt-style), then bake strokes
/// into a new image file on Done.
Future<File?> showImageDoodleOverlay(
  BuildContext context, {
  required File imageFile,
}) {
  return showGeneralDialog<File>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Doodle',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _ImageDoodleOverlay(imageFile: imageFile);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// @deprecated Prefer [showImageDoodleOverlay]. Kept for any leftover push routes.
class ImageDoodleEditorScreen extends StatelessWidget {
  const ImageDoodleEditorScreen({super.key, required this.imageFile});

  final File imageFile;

  @override
  Widget build(BuildContext context) {
    // Immediately present as overlay, then pop this route shell.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      final out = await showImageDoodleOverlay(context, imageFile: imageFile);
      if (context.mounted) Navigator.of(context).pop<File?>(out);
    });
    return const SizedBox.shrink();
  }
}

class _ImageDoodleOverlay extends StatefulWidget {
  const _ImageDoodleOverlay({required this.imageFile});

  final File imageFile;

  @override
  State<_ImageDoodleOverlay> createState() => _ImageDoodleOverlayState();
}

class _ImageDoodleOverlayState extends State<_ImageDoodleOverlay> {
  final List<_DoodleStroke> _strokes = [];
  List<Offset> _current = [];
  Color _penColor = Colors.redAccent;
  static const double _strokeWidth = 4;
  Size? _canvasSize;
  bool _exporting = false;

  static const List<Color> _palette = [
    Colors.redAccent,
    Colors.white,
    Colors.black,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.amberAccent,
  ];

  Future<void> _export() async {
    if (_exporting) return;
    final canvasSize = _canvasSize;
    if (canvasSize == null || canvasSize.isEmpty) return;

    setState(() => _exporting = true);
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final src = frame.image;
      final srcW = src.width.toDouble();
      final srcH = src.height.toDouble();

      final fitted = _containRect(Size(srcW, srcH), canvasSize);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..filterQuality = FilterQuality.high;

      // Draw original image at full resolution.
      canvas.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, srcW, srcH),
        Rect.fromLTWH(0, 0, srcW, srcH),
        paint,
      );

      final scaleX = srcW / fitted.width;
      final scaleY = srcH / fitted.height;

      void drawStroke(_DoodleStroke stroke) {
        final pts = stroke.points;
        if (pts.length < 2) return;
        final strokePaint = Paint()
          ..color = stroke.color
          ..strokeWidth = _strokeWidth * math.max(scaleX, scaleY)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;

        final path = Path();
        var started = false;
        for (final p in pts) {
          final local = Offset(p.dx - fitted.left, p.dy - fitted.top);
          if (local.dx < -2 ||
              local.dy < -2 ||
              local.dx > fitted.width + 2 ||
              local.dy > fitted.height + 2) {
            continue;
          }
          final imgPt = Offset(local.dx * scaleX, local.dy * scaleY);
          if (!started) {
            path.moveTo(imgPt.dx, imgPt.dy);
            started = true;
          } else {
            path.lineTo(imgPt.dx, imgPt.dy);
          }
        }
        if (started) canvas.drawPath(path, strokePaint);
      }

      for (final s in _strokes) {
        drawStroke(s);
      }
      if (_current.length > 1) {
        drawStroke(_DoodleStroke(color: _penColor, points: List.of(_current)));
      }

      final picture = recorder.endRecording();
      final outImage = await picture.toImage(src.width, src.height);
      final byteData = await outImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      src.dispose();
      outImage.dispose();
      if (byteData == null || !mounted) return;

      final dir = await getTemporaryDirectory();
      final out = File(
        '${dir.path}/doodle_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await out.writeAsBytes(byteData.buffer.asUint8List());
      if (mounted) Navigator.of(context).pop<File>(out);
    } catch (e) {
      debugPrint('Doodle export failed: $e');
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not save drawing')),
        );
      }
    }
  }

  /// Same geometry as [BoxFit.contain] — matches how status/chat preview the image.
  Rect _containRect(Size imageSize, Size boxSize) {
    final scale = math.min(
      boxSize.width / imageSize.width,
      boxSize.height / imageSize.height,
    );
    final w = imageSize.width * scale;
    final h = imageSize.height * scale;
    final left = (boxSize.width - w) / 2;
    final top = (boxSize.height - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Match Scaffold body under a standard AppBar so strokes align with the
    // image already on screen (status / chat preview), without reloading it.
    final bodyTop = media.padding.top + kToolbarHeight;

    return Material(
      type: MaterialType.transparency,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // Drawing layer over the existing on-screen image (no second Image.file).
            Positioned(
              top: bodyTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => setState(() {
                      _current = [d.localPosition];
                    }),
                    onPanUpdate: (d) => setState(() {
                      _current = [..._current, d.localPosition];
                    }),
                    onPanEnd: (_) => setState(() {
                      if (_current.length > 1) {
                        _strokes.add(
                          _DoodleStroke(
                            color: _penColor,
                            points: List<Offset>.from(_current),
                          ),
                        );
                      }
                      _current = [];
                    }),
                    child: CustomPaint(
                      painter: _OverlayDoodlePainter(
                        strokes: _strokes,
                        current: _current,
                        currentColor: _penColor,
                        strokeWidth: _strokeWidth,
                      ),
                      size: Size.infinite,
                    ),
                  );
                },
              ),
            ),

            // Top overlay menus (like Tt) — over the app bar region.
            Positioned(
              top: media.padding.top,
              left: 0,
              right: 0,
              child: SizedBox(
                height: kToolbarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _exporting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _exporting ||
                                (_strokes.isEmpty && _current.isEmpty)
                            ? null
                            : () => setState(() {
                                  _strokes.clear();
                                  _current.clear();
                                }),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: (_strokes.isEmpty && _current.isEmpty)
                                  ? 0.4
                                  : 1,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _exporting ? null : _export,
                        child: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Done',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Color palette overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(bottom: media.padding.bottom),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final col in _palette)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Material(
                              color: col,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => setState(() => _penColor = col),
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: _penColor == col
                                      ? Icon(
                                          Icons.check,
                                          color: ThemeData
                                                      .estimateBrightnessForColor(
                                                    col,
                                                  ) ==
                                                  Brightness.light
                                              ? Colors.black54
                                              : Colors.white70,
                                          size: 22,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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

class _DoodleStroke {
  _DoodleStroke({required this.color, required this.points});

  final Color color;
  final List<Offset> points;
}

class _OverlayDoodlePainter extends CustomPainter {
  _OverlayDoodlePainter({
    required this.strokes,
    required this.current,
    required this.currentColor,
    required this.strokeWidth,
  });

  final List<_DoodleStroke> strokes;
  final List<Offset> current;
  final Color currentColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    void drawStroke(List<Offset> pts, Color color) {
      if (pts.length < 2) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      drawStroke(s.points, s.color);
    }
    drawStroke(current, currentColor);
  }

  @override
  bool shouldRepaint(covariant _OverlayDoodlePainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length ||
        oldDelegate.current.length != current.length ||
        oldDelegate.currentColor != currentColor;
  }
}
