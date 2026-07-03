import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// WhatsApp-style inline bar shown while recording a voice note.
class DesktopVoiceRecordingBar extends StatelessWidget {
  const DesktopVoiceRecordingBar({
    super.key,
    required this.duration,
    required this.waveform,
    required this.onCancel,
    required this.onDone,
  });

  final Duration duration;
  final Widget waveform;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2A3942) : const Color(0xFFF0F2F5);
    final border = isDark ? const Color(0xFF3B4A54) : const Color(0xFFD1D7DB);

    return Material(
      color: bg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Discard recording',
              onPressed: onCancel,
              icon: Icon(Icons.delete_outline, color: isDark ? Colors.red[300] : Colors.red[700]),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _format(duration),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Center(child: waveform)),
            IconButton(
              tooltip: 'Finish recording',
              onPressed: onDone,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF008069),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}

/// Themed preview sheet after recording — listen, then send or discard.
Future<bool?> showDesktopVoicePreviewSheet({
  required BuildContext context,
  required String audioPath,
  required Duration duration,
  required AudioPlayer audioPlayer,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final scheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: isDark ? const Color(0xFF202C33) : scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.mic, color: scheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice message',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DesktopAudioPreviewWidget(
                audioPath: audioPath,
                duration: duration,
                audioPlayer: audioPlayer,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        audioPlayer.stop();
                        Navigator.pop(ctx, false);
                      },
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        audioPlayer.stop();
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Normalize recorder output path/extension for upload.
Future<String> normalizeRecordedAudioPath(String path) async {
  var audioPath = path;
  final file = File(audioPath);
  if (!await file.exists()) return audioPath;

  final pathLower = audioPath.toLowerCase();
  if (pathLower.endsWith('.mp4')) {
    final newPath =
        audioPath.replaceAll(RegExp(r'\.mp4$', caseSensitive: false), '.m4a');
    audioPath = (await file.rename(newPath)).path;
  } else if (!pathLower.endsWith('.m4a') &&
      !pathLower.endsWith('.aac') &&
      !pathLower.endsWith('.mp3') &&
      !pathLower.endsWith('.wav') &&
      !pathLower.endsWith('.ogg')) {
    audioPath = (await file.rename('$audioPath.m4a')).path;
  }
  return audioPath;
}

RecordEncoderConfig recordConfigForPlatform() {
  if (Platform.isWindows) {
    return (
      config: const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      extension: 'wav',
    );
  }
  return (
    config: const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    ),
    extension: 'm4a',
  );
}

typedef RecordEncoderConfig = ({RecordConfig config, String extension});

class DesktopAudioPreviewWidget extends StatefulWidget {
  final String audioPath;
  final Duration duration;
  final AudioPlayer audioPlayer;

  const DesktopAudioPreviewWidget({
    super.key,
    required this.audioPath,
    required this.duration,
    required this.audioPlayer,
  });

  @override
  State<DesktopAudioPreviewWidget> createState() =>
      DesktopAudioPreviewWidgetState();
}

class DesktopAudioPreviewWidgetState extends State<DesktopAudioPreviewWidget> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _totalDuration = widget.duration;
    _setupListeners();
  }

  void _setupListeners() {
    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    widget.audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    widget.audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await widget.audioPlayer.pause();
    } else {
      await widget.audioPlayer.play(DeviceFileSource(widget.audioPath));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 40,
                color: const Color(0xFF008069),
              ),
              onPressed: _togglePlayback,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  Slider(
                    value: _position.inMilliseconds.toDouble(),
                    min: 0,
                    max: _totalDuration.inMilliseconds > 0
                        ? _totalDuration.inMilliseconds.toDouble()
                        : widget.duration.inMilliseconds.toDouble(),
                    activeColor: const Color(0xFF008069),
                    onChanged: (value) async {
                      await widget.audioPlayer
                          .seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Text(
                        _formatDuration(_totalDuration > Duration.zero
                            ? _totalDuration
                            : widget.duration),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.audioPlayer.stop();
    super.dispose();
  }
}
