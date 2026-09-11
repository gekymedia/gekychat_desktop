import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Thrown when a video is still over the upload cap after compression.
class VideoTooLargeException implements Exception {
  VideoTooLargeException(this.maxBytes);

  final int maxBytes;

  int get maxMB => (maxBytes / (1024 * 1024)).round().clamp(1, 999);

  @override
  String toString() =>
      'This video is still too large to post (max $maxMB MB). Try a shorter clip.';
}

/// Thrown when the file is over the cap and FFmpeg is not installed.
class FfmpegNotFoundException implements Exception {
  @override
  String toString() =>
      "Can't compress this video (FFmpeg not found). Install FFmpeg or try a shorter clip.";
}

/// Parse `/upload-limits` JSON whether the map is wrapped in `data` or not.
Map<String, dynamic>? parseUploadLimitsPayload(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final inner = map['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return map;
}

int uploadLimitBytes(
  Map<String, dynamic>? limits,
  String section, {
  required int fallback,
}) {
  final block = limits?[section];
  if (block is Map) {
    final v = block['max_size'];
    if (v is int && v > 0) return v;
    if (v is num && v > 0) return v.toInt();
  }
  return fallback;
}

int uploadLimitDurationSeconds(
  Map<String, dynamic>? limits,
  String section, {
  required int fallback,
}) {
  final block = limits?[section];
  if (block is Map) {
    final v = block['max_duration'];
    if (v is int && v > 0) return v;
    if (v is num && v > 0) return v.toInt();
  }
  return fallback;
}

String friendlyVideoUploadError(Object error, {String kind = 'video'}) {
  if (error is VideoTooLargeException || error is FfmpegNotFoundException) {
    return error.toString();
  }
  final s = error.toString().toLowerCase();
  if (s.contains('ffmpeg not found') || s.contains('ffmpeg')) {
    return FfmpegNotFoundException().toString();
  }
  if (s.contains('too large') ||
      s.contains('exceeds your upload') ||
      s.contains('413')) {
    return 'This $kind is too large to post. Try a shorter clip.';
  }
  if (s.contains('timed out') ||
      s.contains('timeout') ||
      s.contains('socketexception') ||
      s.contains('connection')) {
    return "Couldn't post this $kind. Check your connection and try again.";
  }
  return "Couldn't post this $kind. Please try again.";
}

String unwrapExceptionMessage(Object error) {
  if (error is VideoTooLargeException || error is FfmpegNotFoundException) {
    return error.toString();
  }
  return error.toString().replaceAll('Exception: ', '');
}

/// Desktop H.264 re-encode via the system `ffmpeg` binary (not ffmpeg_kit).
class VideoCompressionService {
  static final VideoCompressionService _instance =
      VideoCompressionService._internal();
  factory VideoCompressionService() => _instance;
  VideoCompressionService._internal();

  static const int statusMaxBytesDefault = 100 * 1024 * 1024;
  static const int worldFeedMaxBytesDefault = 200 * 1024 * 1024;
  static const int chatMaxBytesDefault = 10 * 1024 * 1024;

  static const _videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.m4v',
    '.hevc',
  };

  static bool isVideoPath(String path) {
    final ext = p.extension(path).toLowerCase();
    return _videoExtensions.contains(ext);
  }

  Future<void> _queue = Future.value();
  String? _ffmpegPath;
  bool _ffmpegLookupDone = false;

  Future<File> compressVideo(
    File videoFile, {
    int maxHeight = 720,
    int skipIfUnderBytes = 8 * 1024 * 1024,
    int? maxBytes,
  }) async {
    final previous = _queue;
    final gate = Completer<void>();
    _queue = gate.future;
    try {
      await previous;
      return await _compressVideoUnlocked(
        videoFile,
        maxHeight: maxHeight,
        skipIfUnderBytes: skipIfUnderBytes,
        maxBytes: maxBytes,
      );
    } finally {
      gate.complete();
    }
  }

  Future<File> _compressVideoUnlocked(
    File videoFile, {
    required int maxHeight,
    required int skipIfUnderBytes,
    int? maxBytes,
  }) async {
    if (!await videoFile.exists()) {
      return videoFile;
    }

    final originalSize = await videoFile.length();
    debugPrint(
      '🎥 Compress video: ${(originalSize / 1024 / 1024).toStringAsFixed(1)}MB',
    );

    if (originalSize > 0 && originalSize <= skipIfUnderBytes) {
      if (maxBytes != null && originalSize > maxBytes) {
        throw VideoTooLargeException(maxBytes);
      }
      return videoFile;
    }

    final ffmpeg = await _resolveFfmpeg();
    if (ffmpeg == null) {
      if (maxBytes != null && originalSize > maxBytes) {
        throw FfmpegNotFoundException();
      }
      debugPrint('⚠️ FFmpeg not found — uploading original');
      return videoFile;
    }

    var working = await _ffmpegCompress(
      ffmpeg,
      videoFile,
      maxHeight,
      maxBytes: maxBytes,
    );
    var workingSize = await working.length();

    if (maxBytes != null && workingSize > maxBytes && maxHeight > 480) {
      debugPrint('🎥 Still ${workingSize / 1024 / 1024}MB — retrying at 480p');
      final retry = await _ffmpegCompress(
        ffmpeg,
        videoFile,
        480,
        maxBytes: maxBytes,
      );
      final retrySize = await retry.length();
      if (retrySize > 0 && retrySize < workingSize) {
        if (working.path != videoFile.path) {
          try {
            await working.delete();
          } catch (_) {}
        }
        working = retry;
        workingSize = retrySize;
      } else if (retry.path != videoFile.path) {
        try {
          await retry.delete();
        } catch (_) {}
      }
    }

    if (maxBytes != null && workingSize > maxBytes) {
      throw VideoTooLargeException(maxBytes);
    }

    return working;
  }

  Future<File> _ffmpegCompress(
    String ffmpeg,
    File videoFile,
    int maxHeight, {
    int? maxBytes,
  }) async {
    final originalSize = await videoFile.length();
    final tempDir = await getTemporaryDirectory();
    final outPath = p.join(
      tempDir.path,
      'gc${maxHeight}_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final maxRate = maxHeight > 480 ? '2000k' : '800k';
    final bufSize = maxHeight > 480 ? '4000k' : '1600k';
    final vf =
        'scale=-2:$maxHeight:force_original_aspect_ratio=decrease:force_divisible_by=2';

    final args = <String>[
      '-hide_banner',
      '-loglevel',
      'error',
      '-nostdin',
      '-y',
      '-i',
      videoFile.path,
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-crf',
      '23',
      '-maxrate',
      maxRate,
      '-bufsize',
      bufSize,
      '-vf',
      vf,
      '-c:a',
      'aac',
      '-b:a',
      '96k',
      '-ac',
      '2',
      '-movflags',
      '+faststart',
      outPath,
    ];

    try {
      final process = await Process.start(ffmpeg, args, runInShell: false);
      unawaited(process.stdout.drain<void>());
      final stderrBuf = StringBuffer();
      process.stderr.transform(systemEncoding.decoder).listen(stderrBuf.write);

      var timedOut = false;
      final killer = Timer(const Duration(minutes: 12), () {
        timedOut = true;
        process.kill();
      });
      final code = await process.exitCode;
      killer.cancel();

      if (timedOut || code != 0) {
        debugPrint(
          '⚠️ FFmpeg ${timedOut ? 'timed out' : 'exit $code'}: ${stderrBuf.toString()}',
        );
        try {
          await File(outPath).delete();
        } catch (_) {}
        if (maxBytes != null && originalSize > maxBytes) {
          throw VideoTooLargeException(maxBytes);
        }
        return videoFile;
      }

      final out = File(outPath);
      if (!await out.exists()) {
        return videoFile;
      }
      final compressedSize = await out.length();
      if (compressedSize < 1024) {
        try {
          await out.delete();
        } catch (_) {}
        return videoFile;
      }

      final saved = originalSize > 0
          ? ((1 - compressedSize / originalSize) * 100).toStringAsFixed(0)
          : '?';
      debugPrint(
        '✅ Video compressed: ${(originalSize / 1024 / 1024).toStringAsFixed(1)}MB → ${(compressedSize / 1024 / 1024).toStringAsFixed(1)}MB ($saved%)',
      );

      final ext = p.extension(videoFile.path).toLowerCase();
      final preferMp4 = ext == '.mov' || ext == '.hevc' || ext == '.m4v';
      final keepBecauseOverCap = maxBytes != null &&
          originalSize > maxBytes &&
          compressedSize <= maxBytes;
      if (compressedSize < originalSize || preferMp4 || keepBecauseOverCap) {
        return out;
      }

      try {
        await out.delete();
      } catch (_) {}
      return videoFile;
    } catch (e) {
      if (e is VideoTooLargeException || e is FfmpegNotFoundException) {
        rethrow;
      }
      debugPrint('❌ FFmpeg compress error: $e');
      try {
        await File(outPath).delete();
      } catch (_) {}
      if (maxBytes != null && originalSize > maxBytes) {
        throw VideoTooLargeException(maxBytes);
      }
      return videoFile;
    }
  }

  Future<String?> _resolveFfmpeg() async {
    if (_ffmpegLookupDone) return _ffmpegPath;
    _ffmpegLookupDone = true;
    _ffmpegPath = await _findFfmpeg();
    return _ffmpegPath;
  }

  Future<String?> _findFfmpeg() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      // Bundled next to the app (installer / Release folder)
      '$exeDir${Platform.pathSeparator}ffmpeg.exe',
      '$exeDir${Platform.pathSeparator}ffmpeg${Platform.pathSeparator}ffmpeg.exe',
      if (Platform.isMacOS) '$exeDir/../Resources/ffmpeg',
      'ffmpeg',
      if (Platform.isWindows) 'ffmpeg.exe',
      if (Platform.isWindows && localAppData != null)
        '$localAppData\\Microsoft\\WinGet\\Links\\ffmpeg.exe',
      if (Platform.isWindows) r'C:\ffmpeg\bin\ffmpeg.exe',
      if (Platform.isWindows) r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
      if (Platform.isWindows) r'C:\Program Files\GekyChat\ffmpeg.exe',
      if (Platform.isMacOS) '/opt/homebrew/bin/ffmpeg',
      if (Platform.isMacOS) '/usr/local/bin/ffmpeg',
    ];

    for (final c in candidates) {
      if (await _ffmpegWorks(c)) return c;
    }

    try {
      if (Platform.isWindows) {
        final r = await Process.run('where', ['ffmpeg.exe'])
            .timeout(const Duration(seconds: 5));
        if (r.exitCode == 0) {
          final line =
              (r.stdout as String).split(RegExp(r'\r?\n')).first.trim();
          if (line.isNotEmpty && await _ffmpegWorks(line)) return line;
        }
      } else {
        final r = await Process.run('which', ['ffmpeg'])
            .timeout(const Duration(seconds: 5));
        if (r.exitCode == 0) {
          final line = (r.stdout as String).trim().split('\n').first.trim();
          if (line.isNotEmpty && await _ffmpegWorks(line)) return line;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<bool> _ffmpegWorks(String bin) async {
    try {
      if (bin.contains('\\') || bin.contains('/')) {
        if (!await File(bin).exists()) return false;
      }
      final r = await Process.run(bin, ['-version'])
          .timeout(const Duration(seconds: 8));
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
