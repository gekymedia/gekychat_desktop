import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';

class VideoTrimmerWidget extends StatefulWidget {
  final File videoFile;
  final int maxDuration; // in seconds
  final Function(File trimmedVideo) onTrimComplete;
  final Function() onCancel;

  const VideoTrimmerWidget({
    super.key,
    required this.videoFile,
    required this.maxDuration,
    required this.onTrimComplete,
    required this.onCancel,
  });

  @override
  State<VideoTrimmerWidget> createState() => _VideoTrimmerWidgetState();
}

class _VideoTrimmerWidgetState extends State<VideoTrimmerWidget> {
  late final VideoEditorController _controller;
  VideoPlayerController? _previewController;
  bool _isInitialized = false;
  bool _isTrimming = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoEditorController.file(
        widget.videoFile,
        maxDuration: Duration(seconds: widget.maxDuration),
      );
      
      await _controller.initialize();
      
      // Initialize preview player
      _previewController = VideoPlayerController.file(widget.videoFile);
      await _previewController!.initialize();
      await _previewController!.setLooping(true);
      await _previewController!.play();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load video: $e')),
        );
        widget.onCancel();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _trimVideo() async {
    if (_isTrimming) return;
    
    setState(() {
      _isTrimming = true;
    });

    try {
      // Use exportVideo with callback
      _controller.exportVideo(
        onCompleted: (file) async {
          if (mounted && file.path.isNotEmpty) {
            widget.onTrimComplete(File(file.path));
          }
          if (mounted) {
            setState(() {
              _isTrimming = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to trim video: $e')),
        );
        setState(() {
          _isTrimming = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isInitialized) {
      return Container(
        height: 400,
        color: isDark ? const Color(0xFF202C33) : Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ],
          ),
        ),
      );
    }

    final trimmedStartMs = _controller.startTrim.inMilliseconds;
    final trimmedEndMs = _controller.endTrim.inMilliseconds;
    final selectedDuration = ((trimmedEndMs - trimmedStartMs) / 1000).round();
    final exceedsLimit = selectedDuration > widget.maxDuration;

    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF111B21) : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel,
                color: isDark ? Colors.white : Colors.black,
              ),
              Expanded(
                child: Text(
                  'Trim Video',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          
          // Video preview
          SizedBox(
            height: 300,
            child: _previewController != null && _previewController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _previewController!.value.aspectRatio,
                    child: VideoPlayer(_previewController!),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          
          const SizedBox(height: 16),
          
          // Trim slider
          TrimSlider(
            controller: _controller,
            height: 60,
            child: TrimTimeline(
              controller: _controller,
              margin: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Duration info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: exceedsLimit
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: exceedsLimit ? Colors.red : Colors.green,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Duration:',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    Text(
                      _formatDuration(selectedDuration),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: exceedsLimit ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Max allowed: ${_formatDuration(widget.maxDuration)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
                if (exceedsLimit)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please adjust trim range to ${_formatDuration(widget.maxDuration)} or less',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isTrimming ? null : widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isTrimming || exceedsLimit ? null : _trimVideo,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF008069),
                  ),
                  child: _isTrimming
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          exceedsLimit ? 'Duration too long' : 'Trim & Continue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
