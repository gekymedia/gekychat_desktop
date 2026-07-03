import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/avatar_utils.dart';

/// Builds a WhatsApp-style notification large icon: circular avatar (or initial)
/// with a small app-logo badge at the bottom-right.
class NotificationLargeIconComposer {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  static const _size = 128;
  static const _logoSize = 36.0;
  static const _logoAsset = 'assets/icons/gold_no_text/256x256.png';

  static Future<String?> compose({
    String? avatarUrl,
    String? avatarLocalPath,
    required String displayName,
  }) async {
    try {
      ui.Image? avatarImage;
      if (avatarLocalPath != null &&
          avatarLocalPath.isNotEmpty &&
          File(avatarLocalPath).existsSync()) {
        avatarImage = await _loadImageFromFile(avatarLocalPath);
      } else if (avatarUrl != null &&
          avatarUrl.isNotEmpty &&
          avatarUrl.startsWith('http')) {
        avatarImage = await _loadImageFromUrl(avatarUrl);
      }

      final logoBytes = await rootBundle.load(_logoAsset);
      final logoImage = await decodeImageFromList(
        logoBytes.buffer.asUint8List(),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = _size.toDouble();
      final center = Offset(size / 2, size / 2);
      final radius = size / 2;

      if (avatarImage != null) {
        canvas.save();
        canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        );
        paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(0, 0, size, size),
          image: avatarImage,
          fit: BoxFit.cover,
        );
        canvas.restore();
      } else {
        final initial = displayName.trim().isNotEmpty
            ? displayName.trim()[0].toUpperCase()
            : '?';
        final gradient = AvatarUtils.getGradientForName(displayName);
        final rect = Rect.fromLTWH(0, 0, size, size);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = gradient.createShader(rect),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
        );
      }

      final badgeRect = Rect.fromLTWH(
        size - _logoSize - 4,
        size - _logoSize - 4,
        _logoSize,
        _logoSize,
      );
      canvas.drawCircle(
        badgeRect.center,
        _logoSize / 2 + 2,
        Paint()..color = Colors.white,
      );
      canvas.save();
      canvas.clipPath(Path()..addOval(badgeRect));
      paintImage(
        canvas: canvas,
        rect: badgeRect,
        image: logoImage,
        fit: BoxFit.cover,
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(_size, _size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final cacheDir = await getTemporaryDirectory();
      final dir = Directory('${cacheDir.path}/notif_large_icons');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final key =
          '${displayName.hashCode}_${avatarUrl?.hashCode ?? avatarLocalPath?.hashCode ?? 0}';
      final file = File('${dir.path}/large_icon_$key.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (e) {
      debugPrint('NotificationLargeIconComposer: $e');
      return null;
    }
  }

  static Future<ui.Image> _loadImageFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return decodeImageFromList(bytes);
  }

  static Future<ui.Image?> _loadImageFromUrl(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return decodeImageFromList(Uint8List.fromList(data));
    } catch (_) {
      return null;
    }
  }
}
