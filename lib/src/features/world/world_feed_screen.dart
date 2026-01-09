import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/feature_flags.dart';
import '../../core/session.dart';
import '../../core/providers.dart';
import 'world_feed_repository.dart';
import 'create_post_screen.dart';
import 'widgets/comments_dialog.dart';
import 'widgets/fullscreen_video_player.dart';
import 'widgets/fullscreen_media_viewer.dart';

/// PHASE 2: World Feed Screen - Instagram-like grid layout for desktop
class WorldFeedScreen extends ConsumerStatefulWidget {
  const WorldFeedScreen({super.key});

  @override
  ConsumerState<WorldFeedScreen> createState() => _WorldFeedScreenState();
}

class _WorldFeedScreenState extends ConsumerState<WorldFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (_hasMore && !_isLoading) {
        _loadPosts();
      }
    }
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
        _posts.addAll(postsData.map((p) => Map<String, dynamic>.from(p)));
        _currentPage = (pagination['current_page'] ?? _currentPage) + 1;
        _hasMore = pagination['current_page'] != null && 
                   pagination['current_page'] < (pagination['last_page'] ?? 1);
      });
    } catch (e) {
      debugPrint('Error loading posts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sharePost(Map<String, dynamic> post, int index) async {
    try {
      final repo = ref.read(worldFeedRepositoryProvider);
      final shareUrl = await repo.getShareUrl(post['id']);
      final caption = post['caption'] ?? '';
      final creator = post['creator'] as Map<String, dynamic>? ?? {};
      final creatorName = creator['name'] ?? 'Someone';
      
      final shareText = caption.isNotEmpty
          ? '$creatorName: $caption\n\n$shareUrl'
          : 'Check out this post by $creatorName\n\n$shareUrl';
      
      await Share.share(shareText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProfileAsync = ref.watch(currentUserProvider);
    final worldFeedEnabled = featureEnabled(ref, 'world_feed');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('World'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreatePostScreen(),
                ),
              );
            },
            tooltip: 'Create Post',
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (userProfile) {
          if (!userProfile.hasUsername) {
            return _buildLockedState(context, isDark, false);
          }

          if (!worldFeedEnabled) {
            return _buildFeatureDisabledState(context, isDark);
          }

          if (_posts.isEmpty && _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_posts.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          return _buildGridFeed(context, isDark);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, isDark, error.toString()),
      ),
    );
  }

  Widget _buildGridFeed(BuildContext context, bool isDark) {
    // Calculate number of columns based on screen width (Instagram-like)
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200 ? 4 : screenWidth > 800 ? 3 : 2;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _posts = [];
          _currentPage = 1;
          _hasMore = true;
        });
        await _loadPosts();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8, // Portrait aspect ratio
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _posts.length) {
                    return _hasMore && _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : const SizedBox.shrink();
                  }
                  return _buildGridItem(context, _posts[index], index, isDark);
                },
                childCount: _posts.length + (_hasMore ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    Map<String, dynamic> post,
    int index,
    bool isDark,
  ) {
    final mediaUrl = post['media_url'] as String?;
    final thumbnailUrl = post['thumbnail_url'] as String?;
    final caption = post['caption'] as String?;
    final creator = post['creator'] as Map<String, dynamic>?;
    final likesCount = post['likes_count'] ?? 0;
    final commentsCount = post['comments_count'] ?? 0;
    final isVideo = post['type'] == 'video';
    final isLiked = post['is_liked'] ?? false;
    final apiService = ref.read(apiServiceProvider);
    final baseUrl = apiService.baseUrl;
    
    String? fullMediaUrl;
    if (mediaUrl != null) {
      fullMediaUrl = mediaUrl.startsWith('http') 
          ? mediaUrl 
          : '$baseUrl/storage/$mediaUrl';
    }

    String? fullThumbnailUrl;
    if (thumbnailUrl != null) {
      fullThumbnailUrl = thumbnailUrl.startsWith('http') 
          ? thumbnailUrl 
          : '$baseUrl/storage/$thumbnailUrl';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      color: isDark ? const Color(0xFF202C33) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with creator info
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: creator != null && creator['avatar_url'] != null
                      ? NetworkImage(
                          creator['avatar_url']?.toString().startsWith('http') == true
                              ? creator['avatar_url'] as String
                              : '$baseUrl/storage/${creator['avatar_url']}',
                        )
                      : null,
                  child: creator == null || creator['avatar_url'] == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        creator?['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (creator != null && creator['username'] != null)
                        Text(
                          '@${creator['username']}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Media
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (fullMediaUrl != null)
                  CachedNetworkImage(
                    imageUrl: fullMediaUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => fullThumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: fullThumbnailUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      child: Icon(
                        Icons.error_outline,
                        color: isDark ? Colors.white38 : Colors.grey[400],
                      ),
                    ),
                  )
                else
                  Container(
                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                    child: Icon(
                      Icons.broken_image,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                  ),

                // Video indicator and click handler
                if (isVideo)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // Find all video posts from current feed
                          final videoPosts = _posts
                              .where((p) => p['type'] == 'video')
                              .toList();
                          final videoIndex = videoPosts.indexWhere((p) => p['id'] == post['id']);
                          
                          if (videoIndex >= 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullscreenVideoPlayer(
                                  posts: videoPosts,
                                  initialIndex: videoIndex,
                                  baseUrl: baseUrl,
                                ),
                                fullscreenDialog: true,
                              ),
                            );
                          }
                        },
                        child: Stack(
                          children: [
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'VIDEO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
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

                // Click handler for images (videos handled separately above)
                if (!isVideo)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // Find all image posts from current feed
                          final imagePosts = _posts
                              .where((p) => p['type'] != 'video')
                              .toList();
                          final imageIndex = imagePosts.indexWhere((p) => p['id'] == post['id']);
                          
                          if (imageIndex >= 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullscreenMediaViewer(
                                  posts: imagePosts,
                                  initialIndex: imageIndex,
                                  baseUrl: baseUrl,
                                ),
                                fullscreenDialog: true,
                              ),
                            );
                          }
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Footer with actions and caption
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action buttons
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      onPressed: () => _toggleLike(post['id'], index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.comment_outlined,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      onPressed: () async {
                        final result = await showDialog<int>(
                          context: context,
                          builder: (context) => CommentsDialog(
                            postId: post['id'],
                            initialCommentsCount: commentsCount,
                          ),
                        );
                        if (result != null && mounted) {
                          setState(() {
                            _posts[index]['comments_count'] = result;
                          });
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.share_outlined,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      onPressed: () async {
                        await _sharePost(post, index);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Like count
                if (likesCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),

                // Caption
                if (caption != null && caption.isNotEmpty)
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                      children: [
                        if (creator != null)
                          TextSpan(
                            text: '${creator['username'] ?? creator['name'] ?? 'Unknown'} ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        TextSpan(text: caption),
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

  Widget _buildLockedState(BuildContext context, bool isDark, bool isOptIn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isOptIn ? 'World is locked' : 'Set a username to enable this feature.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[800],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Set a username to share and discover public content.',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to profile settings to set username
                Navigator.of(context).pushNamed('/profile');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008069),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'Set Username',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureDisabledState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'World is unavailable right now',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[800],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is limited based on server capacity.',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing here yet',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[800],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to post or follow creators to see content.',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreatePostScreen(),
                      ),
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
                    // TODO: Navigate to find creators
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

  Widget _buildErrorState(BuildContext context, bool isDark, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading World',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[800],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
