import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullscreenVideoPlayer extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;
  final String baseUrl;

  const FullscreenVideoPlayer({
    super.key,
    required this.posts,
    required this.initialIndex,
    required this.baseUrl,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadVideo(_currentIndex);
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startHideControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onPageChanged(int index) {
    if (index != _currentIndex) {
      _videoController?.dispose();
      setState(() {
        _currentIndex = index;
        _videoController = null;
        _isPlaying = false;
        _showControls = true;
      });
      _loadVideo(index);
    }
  }

  Future<void> _loadVideo(int index) async {
    if (index < 0 || index >= widget.posts.length) return;

    final post = widget.posts[index];
    if (post['type'] != 'video') return;

    final mediaUrl = post['media_url'] as String?;
    if (mediaUrl == null) return;

    final fullUrl = mediaUrl.startsWith('http')
        ? mediaUrl
        : '${widget.baseUrl}/storage/$mediaUrl';

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      
      // Add error listener before initialization
      controller.addListener(() {
        if (controller.value.hasError) {
          debugPrint('Video player error: ${controller.value.errorDescription}');
          if (mounted) {
            setState(() {
              _videoController = null;
              _isPlaying = false;
            });
          }
        }
      });
      
      await controller.initialize();
      
      if (mounted && _currentIndex == index) {
        setState(() {
          _videoController = controller;
          _isPlaying = true;
        });
        
        try {
          await controller.play();
          controller.setLooping(true);
        } catch (playError) {
          debugPrint('Error playing video: $playError');
        }
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint('Error loading video: $e');
      // Dispose controller on error to prevent memory leaks
      if (_videoController != null && _videoController!.value.hasError) {
        _videoController?.dispose();
        if (mounted) {
          setState(() {
            _videoController = null;
            _isPlaying = false;
          });
        }
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate portrait dimensions (9:16 aspect ratio)
    final portraitWidth = screenSize.height * (9 / 16);
    final portraitHeight = screenSize.height * 0.9;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _navigateToNext();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _navigateToPrevious();
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              _togglePlayPause();
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
            }
          }
        },
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
            if (_showControls) {
              _startHideControlsTimer();
            }
          },
          child: Center(
            child: Container(
              width: portraitWidth,
              height: portraitHeight,
              child: Stack(
                children: [
                  // Video player
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: widget.posts.length,
                    itemBuilder: (context, index) {
                      final post = widget.posts[index];
                      final isVideo = post['type'] == 'video';
                      
                      if (isVideo && index == _currentIndex && _videoController != null) {
                        return Center(
                          child: AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                        );
                      } else {
                        // Show thumbnail or placeholder
                        final mediaUrl = post['media_url'] as String?;
                        final thumbnailUrl = post['thumbnail_url'] as String?;
                        
                        String? imageUrl;
                        if (thumbnailUrl != null) {
                          imageUrl = thumbnailUrl.startsWith('http')
                              ? thumbnailUrl
                              : '${widget.baseUrl}/storage/$thumbnailUrl';
                        } else if (mediaUrl != null) {
                          imageUrl = mediaUrl.startsWith('http')
                              ? mediaUrl
                              : '${widget.baseUrl}/storage/$mediaUrl';
                        }
                        
                        return Center(
                          child: imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.contain,
                                )
                              : Container(
                                  color: Colors.grey[900],
                                  child: const Center(
                                    child: Icon(Icons.videocam, size: 64, color: Colors.white38),
                                  ),
                                ),
                        );
                      }
                    },
                  ),
                  
                  // Navigation buttons
                  if (_showControls) ...[
                    // Previous button (top)
                    if (_currentIndex > 0)
                      Positioned(
                        top: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.keyboard_arrow_up,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            onPressed: _navigateToPrevious,
                          ),
                        ),
                      ),
                    
                    // Next button (bottom)
                    if (_currentIndex < widget.posts.length - 1)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            onPressed: _navigateToNext,
                          ),
                        ),
                      ),
                  ],
                  
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
                            if (_videoController != null)
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Bottom info
                  if (_showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black87,
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.posts[_currentIndex]['caption'] != null)
                              Text(
                                widget.posts[_currentIndex]['caption'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 8),
                            Text(
                              '${_currentIndex + 1} / ${widget.posts.length}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

