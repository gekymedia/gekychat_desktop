import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'media_repository.dart';
import 'models.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

final conversationMediaProvider =
    FutureProvider.family<List<MediaItem>, int>((ref, conversationId) async {
  final repo = ref.read(mediaRepositoryProvider);
  return await repo.getConversationMedia(conversationId);
});

final groupMediaProvider =
    FutureProvider.family<List<MediaItem>, int>((ref, groupId) async {
  final repo = ref.read(mediaRepositoryProvider);
  return await repo.getGroupMedia(groupId);
});

class MediaGalleryScreen extends ConsumerWidget {
  final int? conversationId;
  final int? groupId;
  final String? title;

  const MediaGalleryScreen({
    super.key,
    this.conversationId,
    this.groupId,
    this.title,
  }) : assert(conversationId != null || groupId != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaAsync = conversationId != null
        ? ref.watch(conversationMediaProvider(conversationId!))
        : ref.watch(groupMediaProvider(groupId!));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(title ?? 'Media'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: mediaAsync.when(
        data: (media) {
          if (media.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No media found',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group by date
          final grouped = _groupByDate(media);

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final entry = grouped[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      entry['date'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: (entry['items'] as List<MediaItem>).length,
                    itemBuilder: (context, idx) {
                      final item = (entry['items'] as List<MediaItem>)[idx];
                      return _MediaThumbnail(
                        media: item,
                        isDark: isDark,
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading media: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  if (conversationId != null) {
                    ref.invalidate(conversationMediaProvider(conversationId!));
                  } else {
                    ref.invalidate(groupMediaProvider(groupId!));
                  }
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupByDate(List<MediaItem> media) {
    final grouped = <String, List<MediaItem>>{};
    for (final item in media) {
      final date = DateFormat('MMMM yyyy').format(item.createdAt);
      grouped.putIfAbsent(date, () => []).add(item);
    }
    return grouped.entries
        .map((e) => {'date': e.key, 'items': e.value})
        .toList();
  }
}

class _MediaThumbnail extends StatefulWidget {
  final MediaItem media;
  final bool isDark;

  const _MediaThumbnail({required this.media, required this.isDark});

  @override
  State<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<_MediaThumbnail> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.media.type == 'video') {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.media.url),
      );
      _videoController!.initialize();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _MediaViewerScreen(media: widget.media),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF202C33) : Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.media.type == 'image')
              CachedNetworkImage(
                imageUrl: widget.media.thumbnailUrl ?? widget.media.url,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              )
            else
              _videoController != null && _videoController!.value.isInitialized
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_videoController!),
                        const Icon(Icons.play_circle_filled,
                            color: Colors.white, size: 40),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            if (widget.media.type == 'video')
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaViewerScreen extends StatefulWidget {
  final MediaItem media;

  const _MediaViewerScreen({required this.media});

  @override
  State<_MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<_MediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.media.type == 'video') {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.media.url),
      );
      _videoController!.initialize().then((_) {
        setState(() {});
      });
      _videoController!.addListener(() {
        if (_videoController!.value.position >= _videoController!.value.duration) {
          setState(() => _isPlaying = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(widget.media.sender.name),
      ),
      body: Center(
        child: widget.media.type == 'image'
            ? InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: widget.media.url,
                  fit: BoxFit.contain,
                ),
              )
            : _videoController != null && _videoController!.value.isInitialized
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                      VideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              setState(() {
                                if (_isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                }
                                _isPlaying = !_isPlaying;
                              });
                            },
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}

