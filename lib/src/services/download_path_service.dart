import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Service to store and retrieve local download paths for attachments
class DownloadPathService {
  static const String _downloadPathsKey = 'download_paths';
  final SharedPreferences _prefs;

  DownloadPathService(this._prefs);

  /// Get the local path for a downloaded file by attachment URL
  Future<String?> getDownloadPath(String attachmentUrl) async {
    final pathsJson = _prefs.getString(_downloadPathsKey);
    if (pathsJson == null || pathsJson.isEmpty) {
      return null;
    }
    try {
      final paths = Map<String, dynamic>.from(jsonDecode(pathsJson));
      return paths[attachmentUrl] as String?;
    } catch (e) {
      debugPrint('Error parsing download paths: $e');
      return null;
    }
  }

  /// Save the local path for a downloaded file
  Future<void> saveDownloadPath(String attachmentUrl, String localPath) async {
    final pathsJson = _prefs.getString(_downloadPathsKey);
    final paths = pathsJson != null && pathsJson.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(pathsJson))
        : <String, dynamic>{};
    paths[attachmentUrl] = localPath;
    await _prefs.setString(_downloadPathsKey, jsonEncode(paths));
    debugPrint('💾 [DOWNLOAD PATH] Saved path for $attachmentUrl: $localPath');
  }

  /// Remove the stored path for an attachment (if file was deleted)
  Future<void> removeDownloadPath(String attachmentUrl) async {
    final pathsJson = _prefs.getString(_downloadPathsKey);
    if (pathsJson == null || pathsJson.isEmpty) {
      return;
    }
    try {
      final paths = Map<String, dynamic>.from(jsonDecode(pathsJson));
      paths.remove(attachmentUrl);
      await _prefs.setString(_downloadPathsKey, jsonEncode(paths));
      debugPrint('💾 [DOWNLOAD PATH] Removed path for $attachmentUrl');
    } catch (e) {
      debugPrint('Error removing download path: $e');
    }
  }

  /// Clear all download paths
  Future<void> clearAllPaths() async {
    await _prefs.remove(_downloadPathsKey);
    debugPrint('💾 [DOWNLOAD PATH] Cleared all download paths');
  }
}
