import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

/// Read images / media file paths from the system clipboard (desktop).
class ClipboardMediaHelper {
  ClipboardMediaHelper._();

  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
  };

  static const _videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.m4v',
  };

  static bool isImagePath(String path) {
    final lower = path.toLowerCase();
    return _imageExtensions.any(lower.endsWith);
  }

  static bool isVideoPath(String path) {
    final lower = path.toLowerCase();
    return _videoExtensions.any(lower.endsWith);
  }

  static bool isImageOrVideoPath(String path) =>
      isImagePath(path) || isVideoPath(path);

  /// Clipboard image bytes or copied file paths suitable for chat media preview.
  static Future<List<File>> readMediaFiles() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}${Platform.pathSeparator}gekychat_clipboard_'
          '${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(imageBytes, flush: true);
        return [file];
      }
    } catch (e) {
      debugPrint('Clipboard image read failed: $e');
    }

    try {
      final paths = await Pasteboard.files();
      final files = <File>[];
      for (final path in paths) {
        if (path.isEmpty) continue;
        final file = File(path);
        if (await file.exists() && isImageOrVideoPath(path)) {
          files.add(file);
        }
      }
      if (files.isNotEmpty) return files;
    } catch (e) {
      debugPrint('Clipboard files read failed: $e');
    }

    return const [];
  }
}
