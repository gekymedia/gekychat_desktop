import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'world_feed_repository.dart';
import '../../utils/world_feed_link_navigation.dart';
import '../contacts/contact_info_screen.dart';
import '../chats/models.dart';
import '../live/live_broadcast_repository.dart';
import '../live/broadcast_viewer_screen.dart';
import '../live/live_broadcast_screen.dart' show liveBroadcastsProvider;
import '../../utils/snackbar_helper.dart';

String _formatTimeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
  return '${(diff.inDays / 30).floor()}mo';
}

/// TikTok Activity tab dropdown filters (excludes New followers tab).
enum _ActivityFilter {
  all,
  likes,
  comments,
  mentions,
}

extension on _ActivityFilter {
  String get apiValue => switch (this) {
    _ActivityFilter.all => 'all',
    _ActivityFilter.likes => 'likes',
    _ActivityFilter.comments => 'comments',
    _ActivityFilter.mentions => 'mentions',
  };

  String get label => switch (this) {
    _ActivityFilter.all => 'Activity',
    _ActivityFilter.likes => 'Likes and saves',
    _ActivityFilter.comments => 'Comments',
    _ActivityFilter.mentions => 'Mentions',
  };

  IconData get icon => switch (this) {
    _ActivityFilter.all => Icons.chat_bubble_outline,
    _ActivityFilter.likes => Icons.favorite_border,
    _ActivityFilter.comments => Icons.mode_comment_outlined,
    _ActivityFilter.mentions => Icons.alternate_email,
  };
}

/// TikTok-style activity: main Activity feed + New followers tab with Follow back.
class WorldActivityScreen extends ConsumerStatefulWidget {
  const WorldActivityScreen({super.key});

  @override
  ConsumerState<WorldActivityScreen> createState() =>
      _WorldActivityScreenState();
}

class _WorldActivityScreenState extends ConsumerState<WorldActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<Map<String, dynamic>> _activityItems = [];
  final List<Map<String, dynamic>> _followerItems = [];
  int _activityPage = 1;
  int _followerPage = 1;
  bool _activityHasMore = true;
  bool _followerHasMore = true;
  bool _activityLoading = false;
  bool _followerLoading = false;
  bool _markingRead = false;
  int _newFollowersUnread = 0;
  _ActivityFilter _activityFilter = _ActivityFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActivity(refresh: true);
      _loadFollowers(refresh: true);
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
    if (_tabController.index == 1) {
      _markFollowersRead();
    }
  }

  Future<void> _markFollowersRead() async {
    if (_newFollowersUnread <= 0) return;
    try {
      await ref.read(worldFeedRepositoryProvider).markActivityRead(
            all: true,
            type: 'new_follower',
          );
      ref.invalidate(worldFeedActivityUnreadCountProvider);
      if (mounted) {
        setState(() {
          _newFollowersUnread = 0;
          for (final item in _followerItems) {
            item['read_at'] ??= DateTime.now().toIso8601String();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _setActivityFilter(_ActivityFilter filter) async {
    if (_activityFilter == filter) return;
    setState(() {
      _activityFilter = filter;
      _activityItems.clear();
      _activityPage = 1;
      _activityHasMore = true;
    });
    await _loadActivity(refresh: true);
  }

  Future<void> _showActivityFilterMenu() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = await showGeneralDialog<_ActivityFilter>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, secondary) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              elevation: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final filter in _ActivityFilter.values)
                    ListTile(
                      leading: Icon(
                        filter.icon,
                        color: theme.colorScheme.onSurface,
                      ),
                      title: Text(
                        filter.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: filter == _activityFilter
                          ? const Icon(
                              Icons.check,
                              color: Color(0xFFFE2C55),
                            )
                          : null,
                      onTap: () => Navigator.pop(ctx, filter),
                    ),
                  SizedBox(height: MediaQuery.paddingOf(ctx).bottom > 0 ? 0 : 8),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
    if (selected != null && mounted) {
      await _setActivityFilter(selected);
    }
  }

  Future<void> _loadActivity({bool refresh = false}) async {
    if (_activityLoading) return;
    final page = refresh ? 1 : _activityPage;
    if (!refresh && !_activityHasMore) return;
    setState(() => _activityLoading = true);
    try {
      final repo = ref.read(worldFeedRepositoryProvider);
      final data = await repo.getActivity(
        page: page,
        filter: _activityFilter.apiValue,
      );
      final list =
          (data['data'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
      final lastPage = pagination['last_page'] as int? ?? 1;
      final currentPage = pagination['current_page'] as int? ?? 1;
      final nfUnread = data['new_followers_unread_count'];
      if (mounted) {
        setState(() {
          if (refresh) {
            _activityItems.clear();
            _activityPage = 1;
          }
          _activityItems.addAll(list);
          _activityPage = currentPage + 1;
          _activityHasMore = currentPage < lastPage;
          _activityLoading = false;
          if (nfUnread is int) {
            _newFollowersUnread = nfUnread;
          } else if (nfUnread != null) {
            _newFollowersUnread = int.tryParse(nfUnread.toString()) ??
                _newFollowersUnread;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadFollowers({bool refresh = false}) async {
    if (_followerLoading) return;
    final page = refresh ? 1 : _followerPage;
    if (!refresh && !_followerHasMore) return;
    setState(() => _followerLoading = true);
    try {
      final repo = ref.read(worldFeedRepositoryProvider);
      final data = await repo.getActivity(page: page, type: 'new_follower');
      final list =
          (data['data'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
      final lastPage = pagination['last_page'] as int? ?? 1;
      final currentPage = pagination['current_page'] as int? ?? 1;
      final nfUnread = data['new_followers_unread_count'];
      if (mounted) {
        setState(() {
          if (refresh) {
            _followerItems.clear();
            _followerPage = 1;
          }
          _followerItems.addAll(list);
          _followerPage = currentPage + 1;
          _followerHasMore = currentPage < lastPage;
          _followerLoading = false;
          if (nfUnread is int) {
            _newFollowersUnread = nfUnread;
          } else if (nfUnread != null) {
            _newFollowersUnread = int.tryParse(nfUnread.toString()) ??
                _newFollowersUnread;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _followerLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingRead) return;
    setState(() => _markingRead = true);
    try {
      await ref.read(worldFeedRepositoryProvider).markActivityRead(all: true);
      ref.invalidate(worldFeedActivityUnreadCountProvider);
      if (mounted) setState(() => _newFollowersUnread = 0);
    } catch (_) {}
    if (mounted) setState(() => _markingRead = false);
  }

  void _onTapActivity(BuildContext context, Map<String, dynamic> activity) {
    final type = activity['type'] as String? ?? '';
    final postId = activity['post_id'];
    final broadcastId = activity['broadcast_id'];
    final actor = activity['actor'] as Map<String, dynamic>?;
    final actorId = actor != null
        ? (actor['id'] is int
              ? actor['id'] as int
              : int.tryParse(actor['id']?.toString() ?? ''))
        : null;

    if (broadcastId != null && (broadcastId is int || broadcastId is String)) {
      final id = broadcastId is int
          ? broadcastId
          : int.tryParse(broadcastId.toString());
      if (id != null) _openLive(context, id);
      return;
    }
    if (postId != null && (postId is int || postId is String)) {
      final id = postId is int ? postId : int.tryParse(postId.toString());
      if (id != null) _openPost(context, id);
      return;
    }
    if (actorId != null &&
        (type == 'new_follower' ||
            type == 'profile_view' ||
            actorId > 0)) {
      _openProfile(context, actorId, actor);
      return;
    }
  }

  void _openPost(BuildContext context, int postId) {
    openWorldFeedInApp(ref, context, postId: postId);
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  void _openProfile(
    BuildContext context,
    int userId,
    Map<String, dynamic>? actor,
  ) {
    final user = User(
      id: userId,
      name: actor?['name']?.toString() ?? 'Unknown',
      phone: actor?['phone']?.toString(),
      avatarUrl: actor?['avatar_url']?.toString(),
      isPremiumVerified: actor?['is_premium_verified'] == true ||
          actor?['verification_status']?.toString() == 'verified',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(user: user),
      ),
    );
  }

  Future<void> _openLive(BuildContext context, int broadcastId) async {
    try {
      final repo = ref.read(liveBroadcastRepositoryProvider);
      final joinData = await repo.joinBroadcast(broadcastId);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BroadcastViewerScreen(
            broadcastId: broadcastId,
            joinData: joinData,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e is LiveBroadcastJoinException
          ? e.message
          : 'Could not join the live.';
      if (e is LiveBroadcastJoinException && e.errorCode == 'BROADCAST_ENDED') {
        ref.invalidate(liveBroadcastsProvider);
      }
      context.showErrorToast(msg);
    }
  }

  Future<void> _followBack(Map<String, dynamic> activity) async {
    final actor = activity['actor'] as Map<String, dynamic>?;
    if (actor == null) return;
    final actorId = actor['id'] is int
        ? actor['id'] as int
        : int.tryParse(actor['id']?.toString() ?? '') ?? 0;
    if (actorId <= 0) return;
    final already = actor['is_following'] == true;
    try {
      final repo = ref.read(worldFeedRepositoryProvider);
      if (already) {
        await repo.unfollowUser(actorId);
      } else {
        await repo.followUser(actorId);
      }
      if (!mounted) return;
      setState(() {
        actor['is_following'] = !already;
      });
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast(
        'Failed to ${already ? 'unfollow' : 'follow'}: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: onSurface,
          indicatorWeight: 3,
          labelColor: onSurface,
          unselectedLabelColor: theme.colorScheme.outline,
          labelStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          onTap: (index) {
            // TikTok: tapping Activity again (or the caret) opens the filter menu.
            if (index == 0 && _tabController.index == 0) {
              _showActivityFilterMenu();
            }
          },
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _activityFilter == _ActivityFilter.all
                        ? 'Activity'
                        : _activityFilter.label,
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: _tabController.index == 0
                        ? onSurface
                        : theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('New followers'),
                  if (_newFollowersUnread > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE2C55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _newFollowersUnread > 99
                            ? '99+'
                            : '$_newFollowersUnread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            TextButton(
              onPressed: _markingRead
                  ? null
                  : () async {
                      await _markAllRead();
                    },
              child: _markingRead
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Mark all read', style: TextStyle(color: accent)),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityList(theme, isDark),
          _buildFollowersList(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildActivityList(ThemeData theme, bool isDark) {
    if (_activityItems.isEmpty && !_activityLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _activityFilter == _ActivityFilter.all
                  ? 'No activity yet'
                  : 'No ${_activityFilter.label.toLowerCase()} yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _activityFilter == _ActivityFilter.all
                  ? 'Likes, comments, profile views and live will show here'
                  : 'Try another filter from the Activity menu',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadActivity(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _activityItems.length + (_activityHasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _activityItems.length) {
            if (!_activityLoading) _loadActivity();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final activity = _activityItems[index];
          return _ActivityTile(
            activity: activity,
            isDark: isDark,
            onTap: () => _onTapActivity(context, activity),
            onPostTap: (postId) => _openPost(context, postId),
          );
        },
      ),
    );
  }

  Widget _buildFollowersList(ThemeData theme, bool isDark) {
    if (_followerItems.isEmpty && !_followerLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_alt_1_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No new followers yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When someone follows you, they show up here',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadFollowers(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _followerItems.length + (_followerHasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _followerItems.length) {
            if (!_followerLoading) _loadFollowers();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final activity = _followerItems[index];
          return _NewFollowerTile(
            activity: activity,
            isDark: isDark,
            onTap: () => _onTapActivity(context, activity),
            onFollowBack: () => _followBack(activity),
          );
        },
      ),
    );
  }
}

int? _parseActivityPostId(Map<String, dynamic> activity) {
  final v = activity['post_id'];
  if (v is int) return v;
  if (v != null) return int.tryParse(v.toString());
  return null;
}

bool _activityTypeShowsPostPreview(String type) {
  return type == 'post_like' ||
      type == 'post_comment' ||
      type == 'comment_reply' ||
      type == 'post_tip' ||
      type == 'post_mention';
}

class _NewFollowerTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onFollowBack;

  const _NewFollowerTile({
    required this.activity,
    required this.isDark,
    required this.onTap,
    required this.onFollowBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actor = activity['actor'] as Map<String, dynamic>?;
    final actorName = actor?['name'] as String? ?? 'Someone';
    final avatarUrl = actor?['avatar_url'] as String?;
    final isFollowing = actor?['is_following'] == true;
    final isUnread = activity['read_at'] == null;
    final createdAt = activity['created_at'] as String?;
    String timeStr = '';
    if (createdAt != null) {
      try {
        timeStr = _formatTimeAgo(DateTime.parse(createdAt));
      } catch (_) {
        timeStr = createdAt;
      }
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF20D5EC),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 16),
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage:
                  avatarUrl != null && avatarUrl.toString().isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl.toString())
                      : null,
              child: avatarUrl == null || avatarUrl.toString().isEmpty
                  ? Text(
                      (actorName.isNotEmpty ? actorName[0] : '?').toUpperCase(),
                      style: theme.textTheme.titleMedium,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      children: [
                        const TextSpan(text: 'started following you.'),
                        if (timeStr.isNotEmpty) ...[
                          const TextSpan(text: '  '),
                          TextSpan(text: timeStr),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onFollowBack,
              style: TextButton.styleFrom(
                backgroundColor: isFollowing
                    ? (isDark ? Colors.grey[800] : const Color(0xFFF1F1F1))
                    : const Color(0xFFFE2C55),
                foregroundColor: isFollowing
                    ? (isDark ? Colors.white70 : Colors.black87)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isFollowing ? 'Following' : 'Follow back',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isDark;
  final VoidCallback onTap;
  final void Function(int postId) onPostTap;

  const _ActivityTile({
    required this.activity,
    required this.isDark,
    required this.onTap,
    required this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actor = activity['actor'] as Map<String, dynamic>?;
    final actorName = actor?['name'] as String? ?? 'Someone';
    final avatarUrl = actor?['avatar_url'] as String?;
    final summary = activity['summary'] as String? ?? '';
    final createdAt = activity['created_at'] as String?;
    final type = activity['type'] as String? ?? '';
    final postThumbnailUrl = activity['post_thumbnail_url'] as String?;
    final postId = _parseActivityPostId(activity);
    final showPostThumb = postId != null && _activityTypeShowsPostPreview(type);
    final isLive = type == 'live_started';
    String timeStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        timeStr = _formatTimeAgo(dt);
      } catch (_) {
        timeStr = createdAt;
      }
    }

    final thumbUrl =
        postThumbnailUrl != null && postThumbnailUrl.toString().isNotEmpty
            ? postThumbnailUrl.toString()
            : null;

    Widget? trailing;
    if (isLive) {
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'LIVE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (showPostThumb) {
      trailing = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onPostTap(postId),
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: 'View post',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: thumbUrl != null
                    ? CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) =>
                            _postThumbPlaceholder(theme),
                      )
                    : _postThumbPlaceholder(theme),
              ),
            ),
          ),
        ),
      );
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
            ? CachedNetworkImageProvider(avatarUrl.toString())
            : null,
        child: avatarUrl == null || avatarUrl.toString().isEmpty
            ? Text(
                (actorName.isNotEmpty ? actorName[0] : '?').toUpperCase(),
                style: theme.textTheme.titleMedium,
              )
            : null,
      ),
      title: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          children: [
            TextSpan(
              text: actorName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' $summary'),
          ],
        ),
      ),
      subtitle: timeStr.isNotEmpty
          ? Text(
              timeStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}

Widget _postThumbPlaceholder(ThemeData theme) {
  return ColoredBox(
    color: theme.colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.image_outlined,
      color: theme.colorScheme.outline,
      size: 28,
    ),
  );
}
