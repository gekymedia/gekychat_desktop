import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../core/feature_flags.dart';
import '../../core/session.dart';
import '../../core/providers.dart';
import 'world_feed_repository.dart';
import 'create_post_screen.dart';
import 'widgets/comments_dialog.dart';
import 'widgets/world_feed_image_carousel.dart';
import 'widgets/video_progress_bar.dart';
import '../../features/contacts/contact_info_screen.dart';
import '../../features/chats/models.dart';
import '../../features/search/search_screen.dart';
import '../../widgets/constrained_slide_route.dart';
import '../../utils/external_share.dart';
import '../chats/widgets/share_text_to_chats_screen.dart';
import 'widgets/world_feed_share_dialog.dart';
import '../../utils/snackbar_helper.dart';

/// World Feed — TikTok-style vertical full-screen feed for desktop.
class WorldFeedScreen extends ConsumerStatefulWidget {
  const WorldFeedScreen({super.key});

  @override
  ConsumerState<WorldFeedScreen> createState() => _WorldFeedScreenState();
}

class _WorldFeedScreenState extends ConsumerState<WorldFeedScreen> {
  final PageController _pageController = PageController();
  final Map<int, VideoPlayerController> _videoControllers = {};
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;
  int _currentIndex = 0;
  int? _fetchingNavigatePostId;
  bool _headerExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(worldFeedRepositoryProvider);
      final response = await repo.getFeed(page: _currentPage);

      final List<dynamic> postsData = response['data'] ?? [];
      final pagination = response['pagination'] ?? {};

      setState(() {
        final existingIds = _posts
            .map((p) => _postIdFromRaw(p['id']))
            .whereType<int>()
            .toSet();
        for (final raw in postsData) {
          final post = Map<String, dynamic>.from(raw);
          final pid = _postIdFromRaw(post['id']);
          if (pid != null && existingIds.contains(pid)) continue;
          if (pid != null) existingIds.add(pid);
          _posts.add(post);
        }
        _currentPage = (pagination['current_page'] ?? _currentPage) + 1;
        _hasMore = pagination['current_page'] != null &&
            pagination['current_page'] < (pagination['last_page'] ?? 1);
      });
    } catch (e) {
      debugPrint('Error loading posts: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkNavigateToPost();
            if (_posts.isNotEmpty) {
              _onPageChanged(_currentIndex);
            }
          }
        });
      }
    }
  }

  int? _postIdFromRaw(dynamic id) {
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  String _resolveStoragePath(String baseUrl, String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    var rel = path;
    if (rel.startsWith('storage/')) rel = rel.substring('storage/'.length);
    return '$baseUrl/storage/$rel';
  }

  void _scheduleScrollToPost(int postId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index =
          _posts.indexWhere((p) => _postIdFromRaw(p['id']) == postId);
      if (index < 0) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
      setState(() => _currentIndex = index);
      _onPageChanged(index);
    });
  }

  void _checkNavigateToPost() {
    if (!mounted) return;
    final postIdToNavigate = ref.read(worldFeedNavigateToPostProvider);
    if (postIdToNavigate == null) return;

    final initialPost = ref.read(worldFeedInitialPostProvider);
    if (initialPost != null) {
      final pid = _postIdFromRaw(initialPost['id']);
      if (pid == postIdToNavigate) {
        final inList =
            _posts.any((p) => _postIdFromRaw(p['id']) == postIdToNavigate);
        if (!inList) {
          setState(() {
            _posts = [Map<String, dynamic>.from(initialPost), ..._posts];
          });
          ref.read(worldFeedInitialPostProvider.notifier).state = null;
          ref.read(worldFeedNavigateToPostProvider.notifier).state = null;
          _scheduleScrollToPost(postIdToNavigate);
          return;
        }
        ref.read(worldFeedInitialPostProvider.notifier).state = null;
      }
    }

    final postIndex =
        _posts.indexWhere((p) => _postIdFromRaw(p['id']) == postIdToNavigate);
    if (postIndex != -1) {
      ref.read(worldFeedNavigateToPostProvider.notifier).state = null;
      _scheduleScrollToPost(postIdToNavigate);
    } else if (_hasMore && !_isLoading) {
      _loadPosts();
    } else if (!_hasMore && !_isLoading) {
      unawaited(_fetchPostAndNavigate(postIdToNavigate));
    }
  }

  Future<void> _fetchPostAndNavigate(int postId) async {
    if (_fetchingNavigatePostId == postId) return;
    _fetchingNavigatePostId = postId;
    try {
      final repo = ref.read(worldFeedRepositoryProvider);
      final post = await repo.getPostById(postId);
      if (!mounted) return;
      ref.read(worldFeedInitialPostProvider.notifier).state =
          Map<String, dynamic>.from(post);
      ref.read(worldFeedNavigateToPostProvider.notifier).state = postId;
      _checkNavigateToPost();
    } catch (e, st) {
      debugPrint('World feed post fetch failed: $e $st');
      if (mounted) {
        ref.read(worldFeedNavigateToPostProvider.notifier).state = null;
                context.showErrorToast('Could not open post');      }
    } finally {
      if (_fetchingNavigatePostId == postId) {
        _fetchingNavigatePostId = null;
      }
    }
  }

  Future<void> _openPostFromShareCode(String code) async {
    try {
      final repo = ref.read(worldFeedRepositoryProvider);
      final post = await repo.getPostByShareCode(code);
      if (!mounted) return;
      final postId = _postIdFromRaw(post['id']);
      if (postId != null && postId > 0) {
        ref.read(worldFeedInitialPostProvider.notifier).state =
            Map<String, dynamic>.from(post);
        ref.read(worldFeedNavigateToPostProvider.notifier).state = postId;
      }
      ref.read(worldFeedNavigateToPostSlugProvider.notifier).state = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkNavigateToPost();
      });
    } catch (e, st) {
      debugPrint('World share code resolve failed: $e $st');
      ref.read(worldFeedNavigateToPostSlugProvider.notifier).state = null;
      if (mounted) {
                context.showErrorToast('Could not open post: $e');      }
    }
  }

  void _pauseAllVideos() {
    for (final controller in _videoControllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  Future<void> _initializeVideoController(int index) async {
    if (_videoControllers.containsKey(index)) return;
    if (index < 0 || index >= _posts.length) return;

    final post = _posts[index];
    if (post['type'] != 'video') return;

    final apiService = ref.read(apiServiceProvider);
    final baseUrl = apiService.baseUrl;
    final mediaUrl = post['media_url'] as String?;
    if (mediaUrl == null || mediaUrl.isEmpty) return;

    final fullUrl = _resolveStoragePath(baseUrl, mediaUrl);
    if (fullUrl.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
    _videoControllers[index] = controller;

    try {
      await controller.initialize();
      controller.setLooping(true);
      if (mounted && _currentIndex == index) {
        setState(() {});
        await controller.play();
      }
    } catch (e) {
      debugPrint('Video init failed: $e');
      _videoControllers.remove(index)?.dispose();
    }
  }

  void _onPageChanged(int index) {
    if (index > _currentIndex && _headerExpanded) {
      setState(() => _headerExpanded = false);
    } else if (index < _currentIndex && !_headerExpanded) {
      setState(() => _headerExpanded = true);
    } else if (index == 0) {
      setState(() => _headerExpanded = true);
    }

    _pauseAllVideos();

    if (index < _posts.length) {
      final post = _posts[index];
      if (post['type'] == 'video') {
        unawaited(_initializeVideoController(index));
      }
    }

    if (index >= _posts.length - 3 && _hasMore && !_isLoading) {
      _loadPosts();
    }
  }

  Future<void> _sharePost(Map<String, dynamic> post, int index) async {
    try {
      final postId = post['id'] as int?;
      if (postId == null) return;

      final repo = ref.read(worldFeedRepositoryProvider);
      final shareUrl = await repo.getShareUrl(postId);
      if (!mounted) return;
      final caption = post['caption'] ?? '';
      final creator = post['creator'] as Map<String, dynamic>? ?? {};
      final creatorName = creator['name'] ?? 'Someone';

      final shareText = caption.toString().trim().isNotEmpty
          ? '$creatorName: $caption\n\n$shareUrl'
          : 'Check out this post by $creatorName\n\n$shareUrl';

      final result = await showWorldFeedShareDialog(
        context,
        shareText: shareText,
        shareUrl: shareUrl,
      );

      if (!mounted || result == null) return;

      Future<void> recordShare() => repo.recordShare(postId);

      if (result == WorldFeedShareResult.quickSent) {
        await recordShare();
        if (mounted) {
                    context.showSuccessToast('Link sent in chat');        }
      } else if (result == WorldFeedShareResult.gekyChat) {
        final sent = await Navigator.push<bool>(
          context,
          ConstrainedSlideRightRoute(
            page: ShareTextToChatsScreen(shareText: shareText),
            leftOffset: 400.0,
          ),
        );
        if (sent == true && mounted) {
          unawaited(recordShare());
        }
      } else if (result == WorldFeedShareResult.copy) {
        await Clipboard.setData(ClipboardData(text: shareText));
        unawaited(recordShare());
        if (mounted) {
                    context.showSuccessToast('Link copied to clipboard');        }
      } else if (result == WorldFeedShareResult.whatsapp) {
        final ok = await shareViaWhatsApp(shareText);
        if (ok) unawaited(recordShare());
        if (mounted && !ok) {
                    context.showErrorToast('Could not open WhatsApp');        }
      } else if (result == WorldFeedShareResult.telegram) {
        final ok = await shareViaTelegram(url: shareUrl, text: shareText);
        if (ok) unawaited(recordShare());
        if (mounted && !ok) {
                    context.showErrorToast('Could not open Telegram');        }
      } else if (result == WorldFeedShareResult.twitter) {
        final ok = await shareViaTwitter(shareText);
        if (ok) unawaited(recordShare());
        if (mounted && !ok) {
                    context.showErrorToast('Could not open X');        }
      } else if (result == WorldFeedShareResult.facebook) {
        final ok = await shareViaFacebook(shareUrl);
        if (ok) unawaited(recordShare());
        if (mounted && !ok) {
                    context.showErrorToast('Could not open Facebook');        }
      } else if (result == WorldFeedShareResult.email) {
        final ok = await shareViaEmail(
          subject: 'Check out this GekyChat post',
          body: shareText,
        );
        if (ok) unawaited(recordShare());
        if (mounted && !ok) {
                    context.showErrorToast('Could not open email app');        }
      } else if (result == WorldFeedShareResult.more) {
        await Share.share(shareText);
        unawaited(recordShare());
      }
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to share: $e');      }
    }
  }

  Future<void> _toggleLike(int postId, int index) async {
    try {
      final repo = ref.read(worldFeedRepositoryProvider);
      await repo.likePost(postId);

      setState(() {
        _posts[index]['is_liked'] = !(_posts[index]['is_liked'] ?? false);
        _posts[index]['likes_count'] = (_posts[index]['likes_count'] ?? 0) +
            (_posts[index]['is_liked'] ? 1 : -1);
      });
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> _openComments(int postId, int index, int commentsCount,
      {String? suggestedSearchQuery}) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => CommentsDialog(
        postId: postId,
        initialCommentsCount: commentsCount,
        suggestedSearchQuery: suggestedSearchQuery,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _posts[index]['comments_count'] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(currentUserProvider);
    final worldFeedEnabled = featureEnabled(ref, 'world_feed');

    ref.listen<int?>(worldFeedNavigateToPostProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkNavigateToPost();
      });
    });
    ref.listen<String?>(worldFeedNavigateToPostSlugProvider, (previous, next) {
      if (next == null || next.isEmpty) return;
      final slug = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPostFromShareCode(slug);
      });
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: userProfileAsync.when(
        data: (userProfile) {
          if (!userProfile.hasUsername) {
            return _buildLockedState(context);
          }

          if (!worldFeedEnabled) {
            return _buildFeatureDisabledState(context);
          }

          if (_posts.isEmpty && _isLoading) {
            return Stack(
              children: [
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildFeedHeader(context),
                ),
              ],
            );
          }

          if (_posts.isEmpty) {
            return Stack(
              children: [
                Positioned.fill(child: _buildEmptyState(context)),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildFeedHeader(context),
                ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: _buildTikTokFeed(context)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _headerExpanded ? 1.0 : 0.35,
                  child: IgnorePointer(
                    ignoring: !_headerExpanded,
                    child: _buildFeedHeader(context),
                  ),
                ),
              ),
              if (!_headerExpanded)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 56,
                  child: GestureDetector(
                    onTap: () => setState(() => _headerExpanded = true),
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (error, _) => _buildErrorState(context, error.toString()),
      ),
    );
  }

  Widget _buildFeedHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.65),
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Text(
                'World',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 8),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                tooltip: 'Find creators',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_box_outlined, color: Colors.white),
                tooltip: 'Create post',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const CreatePostScreen(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTikTokFeed(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          if (!_pageController.hasClients) return;
          final delta = event.scrollDelta.dy;
          if (delta.abs() < 1) return;
          final target = delta > 0
              ? (_currentIndex + 1).clamp(0, _posts.length - 1)
              : (_currentIndex - 1).clamp(0, _posts.length - 1);
          if (target != _currentIndex) {
            _pageController.animateToPage(
              target,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          }
        }
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          _onPageChanged(index);
        },
        itemCount: _posts.length + (_hasMore && _isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            );
          }
          return RepaintBoundary(
            key: ValueKey('world_post_${_posts[index]['id'] ?? 'i$index'}'),
            child: _buildPostItem(context, _posts[index], index),
          );
        },
      ),
    );
  }

  Widget _buildPostItem(
    BuildContext context,
    Map<String, dynamic> post,
    int index,
  ) {
    final creator = post['creator'] as Map<String, dynamic>?;
    final creatorName = creator?['name'] as String? ?? 'Unknown';
    final creatorAvatar = creator?['avatar_url'] as String?;
    final mediaUrl = post['media_url'] as String?;
    final thumbnailUrl = post['thumbnail_url'] as String?;
    final isVideo = post['type'] == 'video';
    final caption = post['caption'] as String?;
    final likesCount = post['likes_count'] as int? ?? 0;
    final commentsCount = post['comments_count'] as int? ?? 0;
    final isLiked = post['is_liked'] as bool? ?? false;
    final postId = _postIdFromRaw(post['id']);
    final apiService = ref.read(apiServiceProvider);
    final baseUrl = apiService.baseUrl;

    final imageUrls = () {
      final raw = post['media_urls'];
      if (raw is List && raw.isNotEmpty) {
        return raw
            .map((e) => _resolveStoragePath(baseUrl, e.toString()))
            .where((u) => u.isNotEmpty)
            .toList();
      }
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        return [_resolveStoragePath(baseUrl, mediaUrl)];
      }
      return <String>[];
    }();

    final fullThumbnailUrl = thumbnailUrl != null
        ? _resolveStoragePath(baseUrl, thumbnailUrl)
        : null;

    final videoController = _videoControllers[index];
    final hasVideoChrome =
        isVideo && videoController != null && videoController.value.isInitialized;
    const chromeGap = 8.0;
    const seekStripHeight = 28.0;
    final captionBottom = hasVideoChrome ? seekStripHeight + chromeGap : 24.0;
    const actionRailBottom = 80.0;

    return GestureDetector(
      onDoubleTap: () {
        if (postId != null) _toggleLike(postId, index);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media
          if (isVideo && hasVideoChrome)
            _buildVideoContent(videoController)
          else if (isVideo)
            Stack(
              fit: StackFit.expand,
              children: [
                if (fullThumbnailUrl != null && fullThumbnailUrl.isNotEmpty)
                  _buildHeightFittedImage(fullThumbnailUrl)
                else
                  Container(color: Colors.black),
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            )
          else if (imageUrls.isNotEmpty)
            WorldFeedImageCarousel(
              imageUrls: imageUrls,
              placeholderUrl: fullThumbnailUrl,
            )
          else
            Container(color: Colors.black),

          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Caption + actions overlay
          Positioned.fill(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (hasVideoChrome)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: VideoProgressBar(controller: videoController),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 80,
                  bottom: captionBottom,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToProfile(creator),
                        child: Text(
                          creatorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                      if (!isVideo && imageUrls.length > 1) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Gallery · ${imageUrls.length} images',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                      if (caption != null && caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          caption,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: actionRailBottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (creator != null) ...[
                        GestureDetector(
                          onTap: () => _navigateToProfile(creator),
                          child: _buildAvatar(
                            avatarUrl: creatorAvatar != null
                                ? _resolveStoragePath(baseUrl, creatorAvatar)
                                : null,
                            name: creatorName,
                            radius: 22,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _WorldFeedActionButton(
                        icon: Icons.favorite,
                        count: likesCount,
                        iconColor: isLiked ? Colors.red : Colors.white,
                        onTap: () {
                          if (postId != null) _toggleLike(postId, index);
                        },
                      ),
                      const SizedBox(height: 14),
                      _WorldFeedActionButton(
                        icon: Icons.chat_bubble,
                        count: commentsCount,
                        onTap: () {
                          if (postId != null) {
                            _openComments(
                              postId,
                              index,
                              commentsCount,
                              suggestedSearchQuery:
                                  _worldFeedSearchQueryFromPost(post),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      _WorldFeedActionButton(
                        icon: Icons.send_rounded,
                        onTap: () => _sharePost(post, index),
                      ),
                      const SizedBox(height: 14),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 28,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                        color: const Color(0xFF202C33),
                        onSelected: (value) =>
                            _handleMenuAction(value, post, index),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, size: 20),
                                SizedBox(width: 12),
                                Text('Share'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'copy_link',
                            child: Row(
                              children: [
                                Icon(Icons.link, size: 20),
                                SizedBox(width: 12),
                                Text('Copy Link'),
                              ],
                            ),
                          ),
                          if (creator != null && creator['id'] != null)
                            const PopupMenuItem(
                              value: 'view_profile',
                              child: Row(
                                children: [
                                  Icon(Icons.person, size: 20),
                                  SizedBox(width: 12),
                                  Text('View Profile'),
                                ],
                              ),
                            ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined,
                                    size: 20, color: Colors.red[300]),
                                const SizedBox(width: 12),
                                Text('Report',
                                    style:
                                        TextStyle(color: Colors.red[300])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeightFittedImage(String imageUrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SizedBox(
            height: constraints.maxHeight,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(color: Colors.black),
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoContent(VideoPlayerController controller) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final videoSize = controller.value.size;
          if (videoSize.width <= 0 || videoSize.height <= 0) {
            return Container(color: Colors.black);
          }

          final aspectRatio = videoSize.width / videoSize.height;
          final height = constraints.maxHeight;
          final width = height * aspectRatio;

          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: VideoPlayer(controller),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar({
    required String? avatarUrl,
    required String name,
    required double radius,
  }) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white24,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.75,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      backgroundImage: CachedNetworkImageProvider(avatarUrl),
    );
  }

  Future<void> _showReportDialog(Map<String, dynamic> post) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creator = post['creator'] as Map<String, dynamic>?;
    final creatorName = creator?['name'] ?? 'this user';
    final creatorId = creator?['id'] as int?;

    if (creatorId == null) {
      if (mounted) {
                context.showErrorToast('Unable to report: user information not available');      }
      return;
    }

    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    String? selectedReason;
    bool blockAfterReport = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          title: Text(
            'Report User',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why are you reporting $creatorName?',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Reason',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  dropdownColor: isDark ? const Color(0xFF202C33) : Colors.white,
                  items: const [
                    DropdownMenuItem(
                      value: 'spam',
                      child: Text('Spam'),
                    ),
                    DropdownMenuItem(
                      value: 'harassment',
                      child: Text('Harassment'),
                    ),
                    DropdownMenuItem(
                      value: 'inappropriate',
                      child: Text('Inappropriate content'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => selectedReason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Additional details (optional)',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: blockAfterReport,
                  onChanged: (value) {
                    setState(() => blockAfterReport = value ?? false);
                  },
                  title: Text(
                    'Block $creatorName',
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedReason != null) {
      final details = detailsController.text.trim();
      reasonController.dispose();
      detailsController.dispose();
      try {
        final apiService = ref.read(apiServiceProvider);
        await apiService.reportUser(
          creatorId,
          selectedReason!,
          details: details.isEmpty ? null : details,
          block: blockAfterReport,
        );

        if (mounted) {
                    context.showSuccessToast('User reported successfully');        }
      } catch (e) {
        if (mounted) {
                    context.showErrorToast('Failed to report user: $e');        }
      }
    } else {
      reasonController.dispose();
      detailsController.dispose();
    }
  }

  void _navigateToProfile(Map<String, dynamic>? creator) {
    if (creator == null || creator['id'] == null) return;

    try {
      final user = User(
        id: creator['id'] as int,
        name: creator['name']?.toString() ?? 'Unknown',
        phone: creator['phone']?.toString(),
        avatarUrl: creator['avatar_url']?.toString(),
        isOnline: creator['online'] as bool?,
        lastSeenAt: creator['last_seen_at'] != null
            ? DateTime.tryParse(creator['last_seen_at'].toString())
            : null,
      );

      Navigator.push(
        context,
        ConstrainedSlideRightRoute(
          page: ContactInfoScreen(user: user),
          leftOffset: 400.0,
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
      if (mounted) {
                context.showErrorToast('Failed to open profile: $e');      }
    }
  }

  void _handleMenuAction(
    String action,
    Map<String, dynamic> post,
    int index,
  ) async {
    switch (action) {
      case 'share':
        await _sharePost(post, index);
        break;
      case 'copy_link':
        try {
          final repo = ref.read(worldFeedRepositoryProvider);
          final shareUrl = await repo.getShareUrl(post['id']);
          await Clipboard.setData(ClipboardData(text: shareUrl));
          if (mounted) {
                        context.showSuccessToast('Link copied to clipboard');          }
        } catch (e) {
          if (mounted) {
                        context.showErrorToast('Failed to copy link: $e');          }
        }
        break;
      case 'view_profile':
        final creator = post['creator'] as Map<String, dynamic>?;
        _navigateToProfile(creator);
        break;
      case 'report':
        _showReportDialog(post);
        break;
    }
  }

  String? _worldFeedSearchQueryFromPost(Map<String, dynamic> post) {
    final tags = post['tags'];
    if (tags is List && tags.isNotEmpty) {
      for (final raw in tags) {
        final s = raw?.toString().trim() ?? '';
        if (s.isEmpty) continue;
        final t = s.replaceAll(RegExp(r'^#+'), '');
        if (t.length >= 2) return '#$t';
      }
    }
    final caption = post['caption'] as String?;
    if (caption != null && caption.trim().isNotEmpty) {
      final m = RegExp(r'#([\w]+)').firstMatch(caption);
      if (m != null) {
        final tag = m.group(1)!;
        if (tag.length >= 2) return '#$tag';
      }
      for (final word in caption.split(RegExp(r'\s+'))) {
        if (word.startsWith('@')) continue;
        final w = word.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');
        if (w.length >= 3 && w.length <= 48) return w;
      }
    }
    return null;
  }

  Widget _buildLockedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'Set a username to enable this feature.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Set a username to share and discover public content.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008069),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'Set Username',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureDisabledState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'World is unavailable right now',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This feature is limited based on server capacity.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'Nothing here yet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to post or follow creators to see content.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const CreatePostScreen(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008069),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('Find Creators'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF008069),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Error loading World',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldFeedActionButton extends StatelessWidget {
  final IconData? icon;
  final int? count;
  final Color iconColor;
  final VoidCallback onTap;

  const _WorldFeedActionButton({
    this.icon,
    this.count,
    this.iconColor = Colors.white,
    required this.onTap,
  });

  static const _shadows = [
    Shadow(color: Colors.black45, blurRadius: 4),
  ];

  String _formatCount(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              color: iconColor,
              size: 32,
              shadows: _shadows,
            ),
          if (count != null && count! > 0) ...[
            const SizedBox(height: 4),
            Text(
              _formatCount(count!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: _shadows,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
