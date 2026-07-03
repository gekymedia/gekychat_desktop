import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';

/// A media item in the gallery, tied to its parent message for actions.
class GalleryMediaItem {
  final MessageAttachment attachment;
  final Message message;
  final bool isSent;

  const GalleryMediaItem({
    required this.attachment,
    required this.message,
    required this.isSent,
  });
}

/// Full-screen media viewer with swipe/keyboard navigation between chat media.
class MediaGalleryViewer extends StatefulWidget {
  final List<GalleryMediaItem> items;
  final int initialIndex;
  final bool isViewOnce;
  final void Function(Message message)? onReply;
  final Future<void> Function(Message message)? onForward;
  final Future<void> Function(Message message)? onDelete;

  const MediaGalleryViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    this.isViewOnce = false,
    this.onReply,
    this.onForward,
    this.onDelete,
  });

  @override
  State<MediaGalleryViewer> createState() => _MediaGalleryViewerState();
}

class _MediaGalleryViewerState extends State<MediaGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController?> _videoControllers = {};
  bool _showControls = true;

  GalleryMediaItem get _currentItem => widget.items[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    _videoControllers[_currentIndex]?.pause();
    setState(() => _currentIndex = index);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.items.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goPrevious() => _goToPage(_currentIndex - 1);

  void _goNext() => _goToPage(_currentIndex + 1);

  bool _isVideo(MessageAttachment attachment) {
    if (attachment.isVideo) return true;
    final mimeType = attachment.mimeType.toLowerCase();
    if (mimeType.startsWith('video/')) return true;
    final url = attachment.url.toLowerCase();
    return url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.avi') ||
        url.endsWith('.mkv') ||
        url.endsWith('.webm');
  }

  Future<void> _shareCurrentMedia() async {
    final attachment = _currentItem.attachment;

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName =
          attachment.originalName?.trim().isNotEmpty == true
              ? attachment.originalName!
              : 'share_${attachment.id}${_extensionFor(attachment)}';
      final downloadPath = '${tempDir.path}/$fileName';

      final dio = Dio();
      await dio.download(attachment.displayUrl, downloadPath);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(downloadPath, mimeType: attachment.mimeType)],
        text: attachment.originalName,
      );
    } catch (e) {
      if (!mounted) return;
      if (attachment.url.isNotEmpty) {
        try {
          await Share.share(attachment.url);
          return;
        } catch (_) {}
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }

  String _extensionFor(MessageAttachment attachment) {
    final mimeMap = {
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/gif': '.gif',
      'image/webp': '.webp',
      'video/mp4': '.mp4',
      'video/quicktime': '.mov',
    };
    return mimeMap[attachment.mimeType] ?? '.bin';
  }

  void _runReply() {
    final callback = widget.onReply;
    if (callback == null) return;
    final message = _currentItem.message;
    Navigator.pop(context);
    callback(message);
  }

  void _runForward() {
    final callback = widget.onForward;
    if (callback == null) return;
    final message = _currentItem.message;
    Navigator.pop(context);
    callback(message);
  }

  void _runDelete() {
    final callback = widget.onDelete;
    if (callback == null) return;
    final message = _currentItem.message;
    Navigator.pop(context);
    callback(message);
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.items.length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (!widget.isViewOnce) _goPrevious();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!widget.isViewOnce) _goNext();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: _showControls
              ? AppBar(
                  backgroundColor: Colors.black54,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Text(
                    '${_currentIndex + 1} / $totalCount',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  centerTitle: true,
                  actions: [
                    if (!widget.isViewOnce) ...[
                      if (widget.onReply != null)
                        IconButton(
                          icon: const Icon(Icons.reply, color: Colors.white),
                          tooltip: 'Reply',
                          onPressed: _runReply,
                        ),
                      if (widget.onForward != null)
                        IconButton(
                          icon: Transform.flip(
                            flipX: true,
                            child: const Icon(Icons.reply, color: Colors.white),
                          ),
                          tooltip: 'Forward',
                          onPressed: _runForward,
                        ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        tooltip: 'Share',
                        onPressed: _shareCurrentMedia,
                      ),
                      if (widget.onDelete != null)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          color: Colors.grey[900],
                          onSelected: (value) {
                            if (value == 'delete') _runDelete();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.redAccent),
                                  SizedBox(width: 12),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                )
              : null,
          body: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  physics: widget.isViewOnce
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    if (_isVideo(item.attachment)) {
                      return _buildVideoPlayer(index, item.attachment);
                    }
                    return _buildImageViewer(item.attachment);
                  },
                ),
                if (_showControls && totalCount > 1 && totalCount <= 10)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        totalCount,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_showControls && totalCount > 1 && !widget.isViewOnce) ...[
                  if (_currentIndex > 0)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          onPressed: _goPrevious,
                        ),
                      ),
                    ),
                  if (_currentIndex < totalCount - 1)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          onPressed: _goNext,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageViewer(MessageAttachment attachment) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: attachment.displayUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (context, url, error) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white54, size: 48),
                SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(int index, MessageAttachment attachment) {
    return _VideoPlayerWidget(
      attachment: attachment,
      onControllerCreated: (controller) {
        _videoControllers[index] = controller;
      },
      isCurrentPage: index == _currentIndex,
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final MessageAttachment attachment;
  final Function(VideoPlayerController) onControllerCreated;
  final bool isCurrentPage;

  const _VideoPlayerWidget({
    required this.attachment,
    required this.onControllerCreated,
    required this.isCurrentPage,
  });

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(_VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage != oldWidget.isCurrentPage && !widget.isCurrentPage) {
      _controller?.pause();
      setState(() => _isPlaying = false);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeVideo() async {
    final url = widget.attachment.displayUrl;
    if (url.isEmpty) {
      setState(() => _error = 'No video source available');
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onVideoTick);
      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
      widget.onControllerCreated(controller);
    } catch (e) {
      debugPrint('Video initialization error: $e');
      if (mounted) {
        setState(() => _error = 'Failed to load video');
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (_controller!.value.isBuffering)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (!_isPlaying)
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 60,
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF00A884),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
