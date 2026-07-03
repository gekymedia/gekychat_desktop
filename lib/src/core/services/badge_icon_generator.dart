import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Helper class to generate badge icons for Windows taskbar
class BadgeIconGenerator {
  static final Map<String, String> _iconCache = {};

  /// Generate a badge icon with the given number.
  /// Returns the path to a `.ico` file (required by [windows_taskbar]).
  static Future<String> generateBadgeIcon(int count) async {
    final badgeText = count > 99 ? '99+' : count.toString();

    if (_iconCache.containsKey(badgeText)) {
      final cached = _iconCache[badgeText]!;
      if (await File(cached).exists()) return cached;
      _iconCache.remove(badgeText);
    }

    try {
      const size = 32.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      paint.color = const Color(0xFFE53935);
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 2,
        paint,
      );

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

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to generate badge icon bytes');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final icoBytes = _wrapPngAsIco(pngBytes, size.toInt());

      final tempDir = await getTemporaryDirectory();
      final iconPath = path.join(tempDir.path, 'badge_$badgeText.ico');

      await File(iconPath).writeAsBytes(icoBytes);
      _iconCache[badgeText] = iconPath;

      return iconPath;
    } catch (e) {
      debugPrint('Error generating badge icon: $e');
      rethrow;
    }
  }

  /// Windows Vista+ ICO container with embedded PNG payload.
  static Uint8List _wrapPngAsIco(Uint8List pngBytes, int dimension) {
    const headerSize = 6;
    const entrySize = 16;
    const imageOffset = headerSize + entrySize;

    final header = ByteData(headerSize);
    header.setUint16(0, 0, Endian.little);
    header.setUint16(2, 1, Endian.little);
    header.setUint16(4, 1, Endian.little);

    final entry = ByteData(entrySize);
    entry.setUint8(0, dimension >= 256 ? 0 : dimension);
    entry.setUint8(1, dimension >= 256 ? 0 : dimension);
    entry.setUint8(2, 0);
    entry.setUint8(3, 0);
    entry.setUint16(4, 1, Endian.little);
    entry.setUint16(6, 32, Endian.little);
    entry.setUint32(8, pngBytes.length, Endian.little);
    entry.setUint32(12, imageOffset, Endian.little);

    return Uint8List.fromList([
      ...header.buffer.asUint8List(),
      ...entry.buffer.asUint8List(),
      ...pngBytes,
    ]);
  }

  static void clearCache() {
    _iconCache.clear();
  }
}
