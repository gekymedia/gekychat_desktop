import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../utils/snackbar_helper.dart';

/// CapCut / TikTok–style audio picker for World (and other composers).
class AudioSearchScreen extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>)? onAudioSelected;

  const AudioSearchScreen({super.key, this.onAudioSelected});

  @override
  ConsumerState<AudioSearchScreen> createState() => _AudioSearchScreenState();
}

class _AudioSearchScreenState extends ConsumerState<AudioSearchScreen> {
  static const _starredPrefsKey = 'audio_library_starred_ids';
  static const _brand = Color(0xFF008069);

  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final PageController _featuredController = PageController(viewportFraction: 0.92);

  List<Map<String, dynamic>> _results = [];
  List<String> _categories = [];
  Set<int> _starredIds = {};
  bool _isLoading = false;
  bool _isSearching = false;
  int? _playingAudioId;
  int _featuredPage = 0;

  /// suggested | mood | genre | starred — plus optional category slug.
  String _chip = 'suggested';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadStarred();
    await Future.wait([_loadLibrary(), _loadCategories()]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    _featuredController.dispose();
    super.dispose();
  }

  Future<void> _loadStarred() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_starredPrefsKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _starredIds = raw.map(int.tryParse).whereType<int>().toSet();
    });
  }

  Future<void> _persistStarred() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _starredPrefsKey,
      _starredIds.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _loadCategories() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/audio/categories');
      if (response.data['success'] == true) {
        final data = response.data['data'];
        List<String> cats = [];
        if (data is Map) {
          cats = data.keys.map((e) => e.toString()).toList();
        } else if (data is List) {
          cats = data.map((e) => e.toString()).toList();
        }
        if (mounted) setState(() => _categories = cats.take(8).toList());
      }
    } catch (_) {}
  }

  Future<void> _loadLibrary({String? category, String? q}) async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get(
        '/audio/library',
        queryParameters: {
          'limit': 60,
          if (category != null && category.isNotEmpty) 'category': category,
          if (q != null && q.isNotEmpty) 'q': q,
        },
      );
      if (response.data['success'] == true) {
        final list = List<Map<String, dynamic>>.from(
          (response.data['data'] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        if (mounted) {
          setState(() {
            _results = list;
            _featuredPage = 0;
          });
          if (_featuredController.hasClients) {
            _featuredController.jumpToPage(0);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load audio library: $e');
      // Fallback to trending if library fails.
      await _loadTrending();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/audio/trending');
      if (response.data['success'] == true) {
        final list = List<Map<String, dynamic>>.from(
          (response.data['data'] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        if (mounted) setState(() => _results = list);
      }
    } catch (e) {
      debugPrint('Failed to load trending audio: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      await _applyChip(_chip);
      return;
    }

    setState(() {
      _isSearching = true;
      _chip = 'suggested';
    });

    try {
      final api = ref.read(apiServiceProvider);
      // Prefer local library search first (our 500+ CC0 tracks).
      final libraryRes = await api.get(
        '/audio/library',
        queryParameters: {'q': query, 'limit': 60},
      );
      var list = <Map<String, dynamic>>[];
      if (libraryRes.data['success'] == true) {
        list = List<Map<String, dynamic>>.from(
          (libraryRes.data['data'] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
      }

      if (list.isEmpty) {
        final response = await api.get(
          '/audio/search',
          queryParameters: {'q': query, 'max_duration': 120},
        );
        if (response.data['success'] == true) {
          final data = response.data['data'];
          final cached = List<Map<String, dynamic>>.from(
            (data['cached'] as List? ?? []).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
          final freesound = List<Map<String, dynamic>>.from(
            (data['freesound'] as List? ?? []).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
          list = [...cached, ...freesound];
        }
      }

      if (mounted) setState(() => _results = list);
    } catch (e) {
      if (mounted) context.showErrorToast('Search failed: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _applyChip(String chip) async {
    setState(() => _chip = chip);
    switch (chip) {
      case 'suggested':
        await _loadLibrary();
        break;
      case 'mood':
        await _loadTrending();
        break;
      case 'genre':
        if (_categories.isNotEmpty) {
          await _loadLibrary(category: _categories.first);
        } else {
          await _loadLibrary();
        }
        break;
      case 'starred':
        setState(() => _isLoading = true);
        try {
          await _loadLibrary();
          if (mounted) {
            setState(() {
              _results = _results
                  .where((a) => _starredIds.contains(_audioId(a)))
                  .toList();
            });
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
        break;
      default:
        // Category slug from API.
        await _loadLibrary(category: chip);
    }
  }

  int? _audioId(Map<String, dynamic> audio) {
    final id = audio['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse('$id');
  }

  Future<void> _toggleStar(Map<String, dynamic> audio) async {
    final id = _audioId(audio);
    if (id == null) return;
    setState(() {
      if (_starredIds.contains(id)) {
        _starredIds.remove(id);
      } else {
        _starredIds.add(id);
      }
    });
    await _persistStarred();
    if (_chip == 'starred' && mounted) {
      setState(() {
        _results = _results.where((a) => _starredIds.contains(_audioId(a))).toList();
      });
    }
  }

  Future<void> _playPreview(Map<String, dynamic> audio) async {
    final audioId = _audioId(audio);

    if (_playingAudioId == audioId) {
      await _audioPlayer.stop();
      setState(() => _playingAudioId = null);
      return;
    }

    await _audioPlayer.stop();

    try {
      final previewUrl = '${audio['preview_url'] ?? ''}';
      if (previewUrl.isEmpty) {
        throw Exception('No preview URL available');
      }

      setState(() => _playingAudioId = audioId);
      await _audioPlayer.play(UrlSource(previewUrl));

      Future.delayed(const Duration(seconds: 15), () {
        if (_playingAudioId == audioId) {
          _audioPlayer.stop();
          if (mounted) setState(() => _playingAudioId = null);
        }
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted && _playingAudioId == audioId) {
          setState(() => _playingAudioId = null);
        }
      });
    } catch (e) {
      setState(() => _playingAudioId = null);
      if (mounted) context.showErrorToast('Failed to play preview: $e');
    }
  }

  void _selectAudio(Map<String, dynamic> audio) {
    _audioPlayer.stop();
    widget.onAudioSelected?.call(audio);
    Navigator.pop(context, audio);
  }

  String _formatDuration(dynamic duration) {
    final secs = duration is num
        ? duration.toDouble()
        : double.tryParse('$duration') ?? 0;
    final total = secs.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _artistOf(Map<String, dynamic> audio) {
    return '${audio['freesound_username'] ?? audio['username'] ?? audio['source'] ?? 'GekyChat'}';
  }

  List<Map<String, dynamic>> get _featured {
    if (_results.isEmpty) return const [];
    return _results.take(math.min(5, _results.length)).toList();
  }

  List<Map<String, dynamic>> get _listItems {
    if (_results.length <= 1) return _results;
    // Keep featured items in the list too (CapCut does); no skip.
    return _results;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B141A) : const Color(0xFFF7F8FA);
    final surface = isDark ? const Color(0xFF1A242B) : Colors.white;
    final muted = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : _brand,
        title: Text(
          'Add Audio',
          style: TextStyle(
            color: isDark ? Colors.white : _brand,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search songs or artists',
                hintStyle: TextStyle(color: muted),
                prefixIcon: Icon(Icons.search, color: muted),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Search',
                        icon: Icon(Icons.arrow_forward, color: muted),
                        onPressed: _search,
                      ),
                filled: true,
                fillColor: isDark ? const Color(0xFF202C33) : surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: _brand, width: 1.4),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chipButton('Suggested', 'suggested', isDark),
                _chipButton('Trending', 'mood', isDark),
                _chipButton('Genre', 'genre', isDark),
                _chipButton('Starred', 'starred', isDark),
                ..._categories.map(
                  (c) => _chipButton(
                    c[0].toUpperCase() + c.substring(1),
                    c,
                    isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _brand))
                : _results.isEmpty
                    ? _emptyState(muted)
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (_featured.isNotEmpty) ...[
                            SizedBox(
                              height: 108,
                              child: PageView.builder(
                                controller: _featuredController,
                                itemCount: _featured.length,
                                onPageChanged: (i) =>
                                    setState(() => _featuredPage = i),
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: _FeaturedAudioCard(
                                      audio: _featured[index],
                                      isPlaying: _playingAudioId ==
                                          _audioId(_featured[index]),
                                      isStarred: _starredIds.contains(
                                        _audioId(_featured[index]),
                                      ),
                                      artist: _artistOf(_featured[index]),
                                      durationText: _formatDuration(
                                        _featured[index]['duration'],
                                      ),
                                      onPlay: () =>
                                          _playPreview(_featured[index]),
                                      onStar: () =>
                                          _toggleStar(_featured[index]),
                                      onSelect: () =>
                                          _selectAudio(_featured[index]),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_featured.length, (i) {
                                final active = i == _featuredPage;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: active ? 8 : 6,
                                  height: active ? 8 : 6,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? _brand
                                        : muted.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                          ],
                          ..._listItems.map(
                            (audio) => _AudioRow(
                              audio: audio,
                              isPlaying: _playingAudioId == _audioId(audio),
                              isStarred:
                                  _starredIds.contains(_audioId(audio)),
                              artist: _artistOf(audio),
                              durationText:
                                  _formatDuration(audio['duration']),
                              muted: muted,
                              onPlay: () => _playPreview(audio),
                              onStar: () => _toggleStar(audio),
                              onSelect: () => _selectAudio(audio),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(Color muted) {
    final searching = _searchController.text.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _chip == 'starred' ? Icons.star_border : Icons.search,
            size: 72,
            color: muted.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 16),
          Text(
            _chip == 'starred'
                ? 'No starred sounds yet'
                : searching
                    ? 'No sounds found'
                    : 'Search for sounds to add to your video',
            style: TextStyle(color: muted, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _chipButton(String label, String value, bool isDark) {
    final active = _chip == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _applyChip(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? _brand.withValues(alpha: isDark ? 0.22 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? _brand
                    : (isDark ? Colors.white24 : Colors.black26),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? (isDark ? Colors.white : _brand)
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedAudioCard extends StatelessWidget {
  const _FeaturedAudioCard({
    required this.audio,
    required this.isPlaying,
    required this.isStarred,
    required this.artist,
    required this.durationText,
    required this.onPlay,
    required this.onStar,
    required this.onSelect,
  });

  final Map<String, dynamic> audio;
  final bool isPlaying;
  final bool isStarred;
  final String artist;
  final String durationText;
  final VoidCallback onPlay;
  final VoidCallback onStar;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final name = '${audio['name'] ?? 'Unknown'}';
    final colors = _coverColors(name);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _CoverThumb(
            seed: name,
            size: 72,
            isPlaying: isPlaying,
            onTap: onPlay,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$artist · $durationText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onStar,
            icon: Icon(
              isStarred ? Icons.star : Icons.star_border,
              color: isStarred ? Colors.amber : Colors.white,
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSelect,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioRow extends StatelessWidget {
  const _AudioRow({
    required this.audio,
    required this.isPlaying,
    required this.isStarred,
    required this.artist,
    required this.durationText,
    required this.muted,
    required this.onPlay,
    required this.onStar,
    required this.onSelect,
  });

  final Map<String, dynamic> audio;
  final bool isPlaying;
  final bool isStarred;
  final String artist;
  final String durationText;
  final Color muted;
  final VoidCallback onPlay;
  final VoidCallback onStar;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = '${audio['name'] ?? 'Unknown'}';

    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _CoverThumb(
              seed: name,
              size: 56,
              isPlaying: isPlaying,
              onTap: onPlay,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$artist · $durationText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onStar,
              icon: Icon(
                isStarred ? Icons.star : Icons.star_border,
                color: isStarred
                    ? Colors.amber
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            Material(
              color: isDark ? const Color(0xFF2A3942) : const Color(0xFFECEFF1),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSelect,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({
    required this.seed,
    required this.size,
    required this.isPlaying,
    required this.onTap,
  });

  final String seed;
  final double size;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _coverColors(seed);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Center(
          child: Container(
            width: size * 0.42,
            height: size * 0.42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: size * 0.28,
            ),
          ),
        ),
      ),
    );
  }
}

List<Color> _coverColors(String seed) {
  final hash = seed.hashCode;
  final hues = <List<Color>>[
    [const Color(0xFF5C1A3A), const Color(0xFF2A0F24)],
    [const Color(0xFF0E4D4A), const Color(0xFF08302E)],
    [const Color(0xFF3B2A6E), const Color(0xFF1C1438)],
    [const Color(0xFF6B3A1F), const Color(0xFF2E180C)],
    [const Color(0xFF1F3A6B), const Color(0xFF0F1C38)],
    [const Color(0xFF4A1F6B), const Color(0xFF241038)],
  ];
  return hues[hash.abs() % hues.length];
}
