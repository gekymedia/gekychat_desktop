import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../utils/storage_url.dart';
import '../models.dart';

/// Chat-bubble video poster: network thumbnail when available, otherwise a
/// paused first frame from [video_player] so shared videos aren't a black box.
class VideoMessagePoster extends StatefulWidget {
  const VideoMessagePoster({
    super.key,
    required this.attachment,
  });

  final MessageAttachment attachment;

  @override
  State<VideoMessagePoster> createState() => _VideoMessagePosterState();
}

class _VideoMessagePosterState extends State<VideoMessagePoster> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _disposed = false;
  bool _useFirstFrame = false;
  bool _loadingFrame = false;

  String? get _thumbnailUrl =>
      resolveStorageUrl(widget.attachment.thumbnailUrl);

  String get _videoUrl {
    final raw = widget.attachment.displayUrl;
    return resolveStorageUrl(raw) ?? raw;
  }

  bool get _hasNetworkThumb =>
      !_useFirstFrame &&
      _thumbnailUrl != null &&
      _thumbnailUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_hasNetworkThumb) {
      _loadFirstFrame();
    }
  }

  @override
  void didUpdateWidget(covariant VideoMessagePoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    final thumbChanged =
        oldWidget.attachment.thumbnailUrl != widget.attachment.thumbnailUrl;
    final urlChanged =
        oldWidget.attachment.displayUrl != widget.attachment.displayUrl;
    if (thumbChanged || urlChanged) {
      _disposeController();
      _ready = false;
      _failed = false;
      _useFirstFrame = false;
      _loadingFrame = false;
      if (_thumbnailUrl == null || _thumbnailUrl!.trim().isEmpty) {
        _loadFirstFrame();
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadFirstFrame() async {
    if (_loadingFrame || _disposed) return;
    _loadingFrame = true;
    _useFirstFrame = true;

    final url = _videoUrl.trim();
    if (url.isEmpty) {
      _loadingFrame = false;
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (_disposed || !mounted) {
        await _safeDispose(controller);
        return;
      }
      await controller.setVolume(0);
      await controller.pause();
      // Nudge slightly past 0 so some Windows decoders paint a real frame.
      final duration = controller.value.duration;
      if (duration > const Duration(milliseconds: 200)) {
        await controller.seekTo(const Duration(milliseconds: 100));
      }
      if (_disposed || !mounted) {
        await _safeDispose(controller);
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
        _loadingFrame = false;
      });
    } catch (e) {
      debugPrint('VideoMessagePoster first-frame error: $e');
      await _safeDispose(controller);
      _loadingFrame = false;
      if (mounted && !_disposed) {
        setState(() => _failed = true);
      }
    }
  }

  Future<void> _safeDispose(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (_) {}
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    _ready = false;
    if (c != null) {
      _safeDispose(c);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasNetworkThumb)
            CachedNetworkImage(
              imageUrl: _thumbnailUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_disposed && !_ready && !_loadingFrame) {
                    _loadFirstFrame();
                  }
                });
                return _buildPlayerOrPlaceholder();
              },
            )
          else
            _buildPlayerOrPlaceholder(),
        ],
      ),
    );
  }

  Widget _buildPlayerOrPlaceholder() {
    final controller = _controller;
    if (_ready && controller != null && controller.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }
    if (_failed) {
      return const ColoredBox(
        color: Color(0xFF111B21),
        child: Center(
          child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 48),
        ),
      );
    }
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}
