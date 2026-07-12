import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

/// Desktop helpers for clipboard copy and revealing downloaded files.
class DesktopFileActions {
  DesktopFileActions._();

  /// Opens the parent folder and selects [filePath] (Explorer / Finder).
  static Future<bool> revealInFileManager(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    try {
      if (Platform.isWindows) {
        // explorer /select,"C:\path\to\file.ext"
        await Process.run('explorer.exe', ['/select,${file.path}']);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', file.path]);
        return true;
      }
      await Process.run('xdg-open', [file.parent.path]);
      return true;
    } catch (e) {
      debugPrint('revealInFileManager failed: $e');
      return false;
    }
  }

  /// Downloads [imageUrl] and copies it to the system clipboard as an image.
  static Future<bool> copyNetworkImageToClipboard(String imageUrl) async {
    if (imageUrl.isEmpty) return false;
    try {
      final response = await Dio().get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return false;

      final data = Uint8List.fromList(bytes);
      await Pasteboard.writeImage(data);

      // Also put a temp file on the clipboard so paste-into-folder works.
      final dir = await getTemporaryDirectory();
      final ext = _guessImageExtension(imageUrl, response.headers.value('content-type'));
      final temp = File(
        '${dir.path}${Platform.pathSeparator}gekychat_clipboard_'
        '${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await temp.writeAsBytes(data, flush: true);
      await Pasteboard.writeFiles([temp.path]);
      return true;
    } catch (e) {
      debugPrint('copyNetworkImageToClipboard failed: $e');
      return false;
    }
  }

  /// Copies an existing local image file to the clipboard.
  static Future<bool> copyLocalImageToClipboard(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    try {
      final bytes = await file.readAsBytes();
      await Pasteboard.writeImage(bytes);
      await Pasteboard.writeFiles([file.path]);
      return true;
    } catch (e) {
      debugPrint('copyLocalImageToClipboard failed: $e');
      return false;
    }
  }

  static String _guessImageExtension(String url, String? contentType) {
    final mime = (contentType ?? '').toLowerCase();
    if (mime.contains('png')) return '.png';
    if (mime.contains('webp')) return '.webp';
    if (mime.contains('gif')) return '.gif';
    if (mime.contains('jpeg') || mime.contains('jpg')) return '.jpg';
    final lower = url.toLowerCase().split('?').first;
    for (final e in ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp']) {
      if (lower.endsWith(e)) return e == '.jpeg' ? '.jpg' : e;
    }
    return '.png';
  }
}
