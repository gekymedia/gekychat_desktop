import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../chats/models.dart';
import 'media_gallery_parser.dart';
import 'media_repository.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
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
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _invalidate() {
    if (widget.conversationId != null) {
      ref.invalidate(conversationMediaGalleryProvider(widget.conversationId!));
    } else {
      ref.invalidate(groupMediaGalleryProvider(widget.groupId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final galleryAsync = widget.conversationId != null
        ? ref.watch(conversationMediaGalleryProvider(widget.conversationId!))
        : ref.watch(groupMediaGalleryProvider(widget.groupId!));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.title ?? 'Media'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor:
              isDark ? Colors.white60 : Colors.grey[600],
          tabs: const [
            Tab(text: 'Photos'),
            Tab(text: 'Videos'),
            Tab(text: 'Docs'),
            Tab(text: 'Links'),
          ],
        ),
      ),
      body: galleryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading media: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _invalidate,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No shared media yet',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _PhotoGrid(items: data.images, isDark: isDark),
              _VideoGrid(items: data.videos, isDark: isDark),
              _DocumentList(items: data.documents, isDark: isDark),
              _LinkList(items: data.links, isDark: isDark),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _EmptyTab({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: isDark ? Colors.white38 : Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<MessageAttachment> items;
  final bool isDark;

  const _PhotoGrid({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyTab(
        icon: Icons.image_outlined,
        label: 'No photos',
        isDark: isDark,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final att = items[i];
        return GestureDetector(
          onTap: () => _openViewer(context, att, isDark),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: att.displayUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => ColoredBox(
                color: isDark ? const Color(0xFF202C33) : Colors.grey[200]!,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => ColoredBox(
                color: isDark ? const Color(0xFF202C33) : Colors.grey[200]!,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VideoGrid extends StatelessWidget {
  final List<MessageAttachment> items;
  final bool isDark;

  const _VideoGrid({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyTab(
        icon: Icons.videocam_outlined,
        label: 'No videos',
        isDark: isDark,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final att = items[i];
        return GestureDetector(
          onTap: () => _openViewer(context, att, isDark),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: att.thumbnailUrl != null && att.thumbnailUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: att.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _videoPlaceholder(isDark),
                      )
                    : _videoPlaceholder(isDark),
              ),
              const Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white70, size: 36),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _videoPlaceholder(bool isDark) {
    return ColoredBox(
      color: isDark ? const Color(0xFF202C33) : Colors.grey[800]!,
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white54),
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  final List<MessageAttachment> items;
  final bool isDark;

  const _DocumentList({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyTab(
        icon: Icons.description_outlined,
        label: 'No documents',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? const Color(0xFF2A3942) : Colors.grey[300],
      ),
      itemBuilder: (context, i) {
        final att = items[i];
        final name = att.originalName ??
            att.url.split('/').last.split('?').first;
        return ListTile(
          leading: Icon(
            _docIcon(att.mimeType),
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Text(
            att.mimeType,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share',
                onPressed: () => Share.share(att.url),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Open',
                onPressed: () async {
                  final uri = Uri.tryParse(att.url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LinkList extends StatelessWidget {
  final List<MediaGalleryLink> items;
  final bool isDark;

  const _LinkList({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyTab(
        icon: Icons.link_outlined,
        label: 'No links',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? const Color(0xFF2A3942) : Colors.grey[300],
      ),
      itemBuilder: (context, i) {
        final link = items[i];
        return ListTile(
          leading: Icon(
            Icons.link_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            link.title ?? link.url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          subtitle: link.title != null
              ? Text(
                  link.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                )
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share link',
            onPressed: () => Share.share(link.url),
          ),
          onTap: () async {
            final uri = Uri.tryParse(link.url);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        );
      },
    );
  }
}

IconData _docIcon(String mime) {
  if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
  if (mime.contains('word') || mime.contains('document')) {
    return Icons.description_outlined;
  }
  if (mime.contains('sheet') || mime.contains('excel')) {
    return Icons.table_chart_outlined;
  }
  if (mime.contains('presentation') || mime.contains('powerpoint')) {
    return Icons.slideshow_outlined;
  }
  if (mime.startsWith('text/')) return Icons.article_outlined;
  return Icons.insert_drive_file_outlined;
}

void _openViewer(BuildContext context, MessageAttachment att, bool isDark) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _MediaViewerScreen(attachment: att, isDark: isDark),
    ),
  );
}

class _MediaViewerScreen extends StatefulWidget {
  final MessageAttachment attachment;
  final bool isDark;

  const _MediaViewerScreen({
    required this.attachment,
    required this.isDark,
  });

  @override
  State<_MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<_MediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.isVideo) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.attachment.displayUrl));
      _videoController!.initialize().then((_) {
        if (mounted) setState(() {});
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
    final att = widget.attachment;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(att.originalName ?? 'Media'),
      ),
      body: Center(
        child: att.isImage
            ? InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: att.displayUrl,
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
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
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
                      ),
                    ],
                  )
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
