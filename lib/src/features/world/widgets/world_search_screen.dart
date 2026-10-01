import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/snackbar_helper.dart';
import '../../chats/models.dart';
import '../../contacts/contact_info_screen.dart';
import '../services/search_history_service.dart';
import '../world_feed_repository.dart';

/// TikTok-style World search: pill bar, history, You may like, result tabs.
class WorldSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const WorldSearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<WorldSearchScreen> createState() => _WorldSearchScreenState();
}

class _WorldSearchScreenState extends ConsumerState<WorldSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchHistoryService _historyService = SearchHistoryService();
  late TabController _tabController;

  List<String> _history = [];
  List<_DiscoveryItem> _youMayLike = [];
  List<Map<String, dynamic>> _posts = [];
  bool _loadingDiscovery = true;
  bool _searching = false;
  bool _hasQuery = false;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchController.text = initial;
      _hasQuery = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch(initial));
    } else {
      _loadDiscovery();
    }
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscovery() async {
    setState(() => _loadingDiscovery = true);
    try {
      final history = await _historyService.getSearchHistory();
      final localTrending =
          await _historyService.getTrendingSearches(limit: 8);
      final hashtags = await ref
          .read(worldFeedRepositoryProvider)
          .getTrendingHashtags(limit: 8);

      final discovery = <_DiscoveryItem>[];
      void add(String q, {bool hot = false, String? subtitle}) {
        final t = q.trim();
        if (t.isEmpty) return;
        if (discovery.any((e) => e.query.toLowerCase() == t.toLowerCase())) {
          return;
        }
        discovery.add(_DiscoveryItem(query: t, hot: hot, subtitle: subtitle));
      }

      for (var i = 0; i < localTrending.length; i++) {
        add(
          localTrending[i],
          hot: i < 2,
          subtitle: i == 0 ? 'Popular for you' : null,
        );
      }
      for (final tag in hashtags) {
        final name = (tag['tag'] ?? tag['name'] ?? tag['hashtag'] ?? '')
            .toString()
            .trim();
        if (name.isEmpty) continue;
        final q = name.startsWith('#') ? name : '#$name';
        add(q, hot: true, subtitle: 'Trending hashtag');
      }

      if (mounted) {
        setState(() {
          _history = history;
          _youMayLike = discovery;
          _loadingDiscovery = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDiscovery = false);
        context.showErrorToast('Could not load suggestions: $e');
      }
    }
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.length < 2) {
      setState(() {
        _hasQuery = false;
        _posts = [];
        _activeQuery = '';
      });
      return;
    }

    setState(() {
      _searching = true;
      _hasQuery = true;
      _activeQuery = query;
    });

    try {
      await _historyService.saveSearchQuery(query);
      final result =
          await ref.read(worldFeedRepositoryProvider).getFeed(query: query);
      final data = result['data'];
      final list = data is List
          ? data
          : (result['posts'] is List ? result['posts'] as List : const []);
      if (!mounted) return;
      setState(() {
        _posts = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      context.showErrorToast('Search failed: $e');
    }
  }

  void _selectSuggestion(String query) {
    _searchController.text = query;
    _searchFocusNode.unfocus();
    _runSearch(query);
  }

  Future<void> _clearHistory() async {
    await _historyService.clearSearchHistory();
    if (mounted) setState(() => _history = []);
  }

  void _openCreator(Map<String, dynamic>? creator) {
    if (creator == null || creator['id'] == null) return;
    final id = creator['id'] is int
        ? creator['id'] as int
        : int.tryParse(creator['id'].toString()) ?? 0;
    if (id <= 0) return;
    final user = User(
      id: id,
      name: creator['name']?.toString() ?? 'Unknown',
      phone: creator['phone']?.toString(),
      avatarUrl: creator['avatar_url']?.toString(),
      isPremiumVerified: creator['is_premium_verified'] == true ||
          creator['verification_status']?.toString() == 'verified',
    );
    unawaited(
      ref.read(worldFeedRepositoryProvider).recordProfileView(id),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContactInfoScreen(user: user)),
    );
  }

  List<Map<String, dynamic>> get _userResults {
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final post in _posts) {
      final creator = post['creator'];
      if (creator is! Map) continue;
      final id = creator['id'] is int
          ? creator['id'] as int
          : int.tryParse(creator['id']?.toString() ?? '') ?? 0;
      if (id <= 0 || seen.contains(id)) continue;
      seen.add(id);
      out.add(Map<String, dynamic>.from(creator));
    }
    return out;
  }

  List<Map<String, dynamic>> get _videoResults => _posts
      .where((p) {
        final type = (p['media_type'] ?? p['type'] ?? '').toString().toLowerCase();
        return type.contains('video');
      })
      .toList();

  List<String> get _hashtagResults {
    final tags = <String>{};
    for (final post in _posts) {
      final raw = post['tags'];
      if (raw is List) {
        for (final t in raw) {
          final s = t?.toString().trim() ?? '';
          if (s.isEmpty) continue;
          tags.add(s.startsWith('#') ? s : '#$s');
        }
      }
      final caption = post['caption']?.toString() ?? '';
      for (final m in RegExp(r'#(\w+)').allMatches(caption)) {
        tags.add('#${m.group(1)}');
      }
    }
    return tags.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5);
    final surface = isDark ? const Color(0xFF202C33) : Colors.white;
    final onSurface = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: _runSearch,
            onChanged: (v) {
              if (v.trim().isEmpty && _hasQuery) {
                setState(() {
                  _hasQuery = false;
                  _posts = [];
                  _activeQuery = '';
                });
                _loadDiscovery();
              }
            },
            style: TextStyle(color: onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: TextStyle(color: muted),
              prefixIcon: Icon(Icons.search, color: muted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, color: muted, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _hasQuery = false;
                          _posts = [];
                          _activeQuery = '';
                        });
                        _loadDiscovery();
                      },
                    )
                  : null,
              filled: true,
              fillColor: surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        bottom: _hasQuery
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: onSurface,
                unselectedLabelColor: muted,
                indicatorColor: const Color(0xFF008069),
                tabs: const [
                  Tab(text: 'Top'),
                  Tab(text: 'Users'),
                  Tab(text: 'Videos'),
                  Tab(text: 'Hashtags'),
                ],
              )
            : null,
      ),
      body: _hasQuery
          ? (_searching
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostGrid(_posts, muted),
                    _buildUsersList(_userResults, muted),
                    _buildPostGrid(_videoResults, muted),
                    _buildHashtagList(_hashtagResults, muted),
                  ],
                ))
          : _buildDiscovery(surface, onSurface, muted),
    );
  }

  Widget _buildDiscovery(Color surface, Color onSurface, Color muted) {
    if (_loadingDiscovery) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_history.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Recent',
                style: TextStyle(
                  color: onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearHistory,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._history.take(8).map(
                (q) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history, color: muted),
                  title: Text(q, style: TextStyle(color: onSurface)),
                  onTap: () => _selectSuggestion(q),
                  trailing: IconButton(
                    icon: Icon(Icons.close, size: 18, color: muted),
                    onPressed: () async {
                      await _historyService.removeSearchQuery(q);
                      final next = await _historyService.getSearchHistory();
                      if (mounted) setState(() => _history = next);
                    },
                  ),
                ),
              ),
          const SizedBox(height: 12),
        ],
        Text(
          'You may like',
          style: TextStyle(
            color: onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (_youMayLike.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Search creators, sounds, or hashtags',
              style: TextStyle(color: muted),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _youMayLike.map((item) {
              return ActionChip(
                avatar: Icon(
                  item.hot ? Icons.local_fire_department : Icons.search,
                  size: 16,
                  color: item.hot ? Colors.orange : muted,
                ),
                label: Text(item.query),
                backgroundColor: surface,
                onPressed: () => _selectSuggestion(item.query),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildPostGrid(List<Map<String, dynamic>> posts, Color muted) {
    if (posts.isEmpty) {
      return Center(
        child: Text('No results for “$_activeQuery”', style: TextStyle(color: muted)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final media = post['media'];
        final mediaUrl = media is Map ? media['url']?.toString() : null;
        final thumb =
            (post['thumbnail_url'] ?? post['media_url'] ?? mediaUrl)?.toString();
        return GestureDetector(
          onTap: () => _openCreator(post['creator'] as Map<String, dynamic>?),
          child: Container(
            color: Colors.black12,
            child: thumb == null || thumb.isEmpty
                ? Icon(Icons.image, color: muted)
                : CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  Widget _buildUsersList(List<Map<String, dynamic>> users, Color muted) {
    if (users.isEmpty) {
      return Center(
        child: Text('No users for “$_activeQuery”', style: TextStyle(color: muted)),
      );
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final name = user['name']?.toString() ?? 'Unknown';
        final avatar = user['avatar_url']?.toString();
        final verified = user['is_premium_verified'] == true ||
            user['verification_status']?.toString() == 'verified';
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar == null || avatar.isEmpty
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                : null,
          ),
          title: Row(
            children: [
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
              if (verified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, size: 16, color: Color(0xFF008069)),
              ],
            ],
          ),
          subtitle: user['username'] != null
              ? Text('@${user['username']}', style: TextStyle(color: muted))
              : null,
          onTap: () => _openCreator(user),
        );
      },
    );
  }

  Widget _buildHashtagList(List<String> tags, Color muted) {
    if (tags.isEmpty) {
      return Center(
        child: Text('No hashtags for “$_activeQuery”', style: TextStyle(color: muted)),
      );
    }
    return ListView.builder(
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        return ListTile(
          leading: Icon(Icons.tag, color: muted),
          title: Text(tag),
          onTap: () => _selectSuggestion(tag),
        );
      },
    );
  }
}

class _DiscoveryItem {
  final String query;
  final bool hot;
  final String? subtitle;

  const _DiscoveryItem({
    required this.query,
    this.hot = false,
    this.subtitle,
  });
}
