import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Helper class to generate badge icons for Windows taskbar
class BadgeIconGenerator {
  static final Map<String, String> _iconCache = {};

  /// Generate a badge icon with the given number
  /// Returns the path to the generated .ico file
  static Future<String> generateBadgeIcon(int count) async {
    final badgeText = count > 99 ? '99+' : count.toString();
    
    // Check cache
    if (_iconCache.containsKey(badgeText)) {
      return _iconCache[badgeText]!;
    }

    try {
      // Create a 32x32 icon (better visibility on Windows taskbar)
      const size = 32.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      // Draw red circle background
      paint.color = const Color(0xFFE53935); // Material red
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 2,
        paint,
      );

      // Draw white text
      final fontSize = badgeText.length <= 2 ? 16.0 : 12.0;
      final textPainter = TextPainter(
        text: TextSpan(
          text: badgeText,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'Arial',
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2 - 1,
        ),
      );

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to generate badge icon bytes');
      }

      // Save as temporary file
      final tempDir = await getTemporaryDirectory();
      final iconPath = path.join(
        tempDir.path,
        'badge_$badgeText.ico',
      );

      // For simplicity, we'll save as PNG and rename to .ico
      // Windows will accept PNG data in an ICO container
      final file = File(iconPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // Cache the path
      _iconCache[badgeText] = iconPath;

      return iconPath;
    } catch (e) {
      debugPrint('Error generating badge icon: $e');
      rethrow;
    }
  }

  /// Clear the badge icon cache
  static void clearCache() {
    _iconCache.clear();
  }
}
