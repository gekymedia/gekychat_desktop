import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Fullscreen media viewer for images and videos
class FullscreenMediaViewer extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;
  final String baseUrl;

  const FullscreenMediaViewer({
    super.key,
    required this.posts,
    required this.initialIndex,
    required this.baseUrl,
  });

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startHideControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  void _navigateToNext() {
    if (_currentIndex < widget.posts.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getMediaUrl(Map<String, dynamic> post) {
    final mediaUrl = post['media_url'] as String?;
    if (mediaUrl == null) return '';
    
    return mediaUrl.startsWith('http')
        ? mediaUrl
        : '${widget.baseUrl}/storage/$mediaUrl';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
          if (_showControls) {
            _startHideControlsTimer();
          }
        },
        child: Stack(
          children: [
            // Media viewer
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.posts.length,
              itemBuilder: (context, index) {
                final post = widget.posts[index];
                final isVideo = post['type'] == 'video';
                final mediaUrl = _getMediaUrl(post);
                
                if (mediaUrl.isEmpty) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.white38, size: 64),
                  );
                }

                if (isVideo) {
                  // For videos, show thumbnail with play icon
                  final thumbnailUrl = post['thumbnail_url'] as String?;
                  final fullThumbnailUrl = thumbnailUrl != null
                      ? (thumbnailUrl.startsWith('http')
                          ? thumbnailUrl
                          : '${widget.baseUrl}/storage/$thumbnailUrl')
                      : null;
                  
                  return Stack(
                    children: [
                      if (fullThumbnailUrl != null)
                        Center(
                          child: CachedNetworkImage(
                            imageUrl: fullThumbnailUrl,
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        Center(
                          child: CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
                    ],
                  );
                } else {
                  // For images, show full image
                  return Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.error_outline, color: Colors.white38, size: 64),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),

            // Top controls
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} / ${widget.posts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Navigation buttons
            if (_showControls) ...[
              // Previous button
              if (_currentIndex > 0)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                      onPressed: _navigateToPrevious,
                    ),
                  ),
                ),

              // Next button
              if (_currentIndex < widget.posts.length - 1)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                      onPressed: _navigateToNext,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
