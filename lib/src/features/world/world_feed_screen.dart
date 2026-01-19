import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../features/contacts/contact_info_screen.dart';
import '../../features/chats/models.dart';
import '../../features/search/search_screen.dart';
import '../../widgets/constrained_slide_route.dart';

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
              showDialog(
                context: context,
                builder: (context) => const CreatePostScreen(),
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
    // Instagram-style vertical scrolling feed (one post per row, centered)
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 1200 ? 614.0 : screenWidth * 0.8;

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
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    ...(_posts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final post = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: _buildPostCard(context, post, index, isDark),
                      );
                    }).toList()),
                    if (_hasMore && _isLoading)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
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

    // Instagram-style post card (full-width, vertical scrolling)
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? const Color(0xFF2B3A43) : const Color(0xFFDBDBDB),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      color: isDark ? const Color(0xFF202C33) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with creator info (Instagram-style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(creator),
                  child: _buildAvatar(
                    avatarUrl: creator != null && creator['avatar_url'] != null
                        ? (creator['avatar_url']?.toString().startsWith('http') == true
                            ? creator['avatar_url'] as String
                            : '$baseUrl/storage/${creator['avatar_url']}')
                        : null,
                    name: creator?['name'] ?? 'Unknown',
                    radius: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToProfile(creator),
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
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  onSelected: (value) => _handleMenuAction(value, post, index),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 12),
                          const Text('Share'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy_link',
                      child: Row(
                        children: [
                          Icon(Icons.link, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 12),
                          const Text('Copy Link'),
                        ],
                      ),
                    ),
                    if (creator != null && creator['id'] != null)
                      PopupMenuItem(
                        value: 'view_profile',
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                            const SizedBox(width: 12),
                            const Text('View Profile'),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 20, color: Colors.red[300]),
                          const SizedBox(width: 12),
                          Text('Report', style: TextStyle(color: Colors.red[300])),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Media (Instagram-style square aspect ratio)
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isVideo && fullMediaUrl != null)
                    GestureDetector(
                      onTap: () {
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
                      child: CachedNetworkImage(
                        imageUrl: fullThumbnailUrl ?? fullMediaUrl ?? '',
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          color: Colors.black,
                          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.black,
                          child: const Icon(Icons.error_outline, color: Colors.white38),
                        ),
                      ),
                    )
                  else if (fullMediaUrl != null)
                    GestureDetector(
                      onTap: () {
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
                      child: CachedNetworkImage(
                        imageUrl: fullMediaUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => fullThumbnailUrl != null
                            ? CachedNetworkImage(
                                imageUrl: fullThumbnailUrl,
                                fit: BoxFit.contain,
                              )
                            : Container(
                                color: Colors.black,
                                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                              ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.black,
                          child: const Icon(Icons.error_outline, color: Colors.white38),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: const Icon(Icons.broken_image, color: Colors.white38),
                    ),

                  // Video play indicator
                  if (isVideo)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Actions and Caption (Instagram-style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action buttons row
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : (isDark ? Colors.white : Colors.black),
                        size: 28,
                      ),
                      onPressed: () => _toggleLike(post['id'], index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(
                        Icons.comment_outlined,
                        color: isDark ? Colors.white : Colors.black,
                        size: 28,
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
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(
                        Icons.send_outlined,
                        color: isDark ? Colors.white : Colors.black,
                        size: 28,
                      ),
                      onPressed: () async {
                        await _sharePost(post, index);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.bookmark_border,
                        color: isDark ? Colors.white : Colors.black,
                        size: 28,
                      ),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Like count
                Text(
                  '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                // Caption with username
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: '${creator?['name'] ?? 'Unknown'} ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: caption),
                      ],
                    ),
                  ),
                ],

                // View all comments
                if (commentsCount > 0) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
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
                    child: Text(
                      'View all $commentsCount ${commentsCount == 1 ? 'comment' : 'comments'}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],

                // Time ago
                const SizedBox(height: 8),
                Text(
                  _getTimeAgo(DateTime.parse(post['created_at'] ?? DateTime.now().toIso8601String())),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required String? avatarUrl, required String name, required double radius}) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: radius * 0.8)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image(
          image: CachedNetworkImageProvider(avatarUrl),
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showReportDialog(Map<String, dynamic> post) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creator = post['creator'] as Map<String, dynamic>?;
    final creatorName = creator?['name'] ?? 'this user';
    final creatorId = creator?['id'] as int?;
    
    if (creatorId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to report: user information not available')),
        );
      }
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
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                    DropdownMenuItem(value: 'harassment', child: Text('Harassment')),
                    DropdownMenuItem(value: 'inappropriate', child: Text('Inappropriate content')),
                    DropdownMenuItem(value: 'fake', child: Text('Fake account')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => selectedReason = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: InputDecoration(
                    labelText: 'Additional details (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Block this user after reporting'),
                  value: blockAfterReport,
                  onChanged: (value) => setState(() => blockAfterReport = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedReason != null
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedReason != null) {
      try {
        final apiService = ref.read(apiServiceProvider);
        await apiService.reportUser(
          creatorId,
          selectedReason!,
          details: detailsController.text.trim().isEmpty
              ? null
              : detailsController.text.trim(),
          block: blockAfterReport,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User reported successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to report user: $e')),
          );
        }
      }
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
          leftOffset: 400.0, // Sidebar width
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open profile: $e')),
        );
      }
    }
  }

  void _handleMenuAction(String action, Map<String, dynamic> post, int index) async {
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copied to clipboard')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to copy link: $e')),
            );
          }
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'JUST NOW';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}M AGO';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}H AGO';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}D AGO';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}W AGO';
    } else {
      final months = (difference.inDays / 30).floor();
      return '${months}MO AGO';
    }
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
