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
  ///
  /// On Windows this uses `explorer /select,"path"` so the file is highlighted,
  /// matching Telegram / typical desktop chat apps.
  static Future<bool> revealInFileManager(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final absolute = file.absolute.path;

    try {
      if (Platform.isWindows) {
        final winPath = absolute.replaceAll('/', r'\');
        // cmd.exe so quoting + /select work with spaces; explorer often exits 1 on success.
        await Process.run(
          'cmd.exe',
          ['/c', 'start', '', 'explorer.exe', '/select,"$winPath"'],
          runInShell: false,
        );
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', absolute]);
        return true;
      }
      // Prefer selecting the file via D-Bus when available (Nautilus, etc.).
      final uri = Uri.file(absolute).toString();
      final dbus = await Process.run(
        'dbus-send',
        [
          '--session',
          '--dest=org.freedesktop.FileManager1',
          '--type=method_call',
          '/org/freedesktop/FileManager1',
          'org.freedesktop.FileManager1.ShowItems',
          'array:string:$uri',
          'string:',
        ],
      );
      if (dbus.exitCode == 0) return true;
      await Process.run('xdg-open', [file.parent.path]);
      return true;
    } catch (e) {
      debugPrint('revealInFileManager failed: $e');
      try {
        if (Platform.isWindows) {
          await Process.run('explorer.exe', [file.parent.path]);
          return true;
        }
      } catch (_) {}
      return false;
    }
  }

  /// Returns [desiredPath] if free; otherwise `name (1).ext`, `name (2).ext`, …
  static Future<String> uniqueDownloadPath(String desiredPath) async {
    final file = File(desiredPath);
    if (!await file.exists()) return desiredPath;

    final separator = Platform.pathSeparator;
    final parent = file.parent.path;
    final fullName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path.split(RegExp(r'[/\\]')).last;
    final dot = fullName.lastIndexOf('.');
    final stem = dot > 0 ? fullName.substring(0, dot) : fullName;
    final ext = dot > 0 ? fullName.substring(dot) : '';

    for (var i = 1; i < 1000; i++) {
      final candidate = '$parent$separator$stem ($i)$ext';
      if (!await File(candidate).exists()) return candidate;
    }
    return '$parent$separator$stem (${DateTime.now().millisecondsSinceEpoch})$ext';
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
