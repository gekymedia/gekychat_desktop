import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';

class AudioSearchScreen extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>)? onAudioSelected;
  
  const AudioSearchScreen({super.key, this.onAudioSelected});

  @override
  ConsumerState<AudioSearchScreen> createState() => _AudioSearchScreenState();
}

class _AudioSearchScreenState extends ConsumerState<AudioSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  int? _playingAudioId;
  String _currentTab = 'search'; // 'search' or 'trending'
  
  @override
  void initState() {
    super.initState();
    _loadTrending();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/audio/trending');
      
      if (response.data['success'] == true) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(
            (response.data['data'] as List).map((e) => Map<String, dynamic>.from(e))
          );
        });
      }
    } catch (e) {
      debugPrint('Failed to load trending audio: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() => _isSearching = true);
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/audio/search', queryParameters: {
        'q': query,
        'max_duration': 120, // Max 2 minutes for short videos
      });
      
      if (response.data['success'] == true) {
        final data = response.data['data'];
        final cached = List<Map<String, dynamic>>.from(
          (data['cached'] as List? ?? []).map((e) => Map<String, dynamic>.from(e))
        );
        final freesound = List<Map<String, dynamic>>.from(
          (data['freesound'] as List? ?? []).map((e) => Map<String, dynamic>.from(e))
        );
        
        setState(() {
          _searchResults = [...cached, ...freesound];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }
  
  Future<void> _playPreview(Map<String, dynamic> audio) async {
    final audioId = audio['id'];
    
    // If already playing this audio, stop it
    if (_playingAudioId == audioId) {
      await _audioPlayer.stop();
      setState(() => _playingAudioId = null);
      return;
    }
    
    // Stop any currently playing audio
    await _audioPlayer.stop();
    
    try {
      final previewUrl = audio['preview_url'] ?? '';
      if (previewUrl.isEmpty) {
        throw Exception('No preview URL available');
      }
      
      setState(() => _playingAudioId = audioId);
      
      await _audioPlayer.play(UrlSource(previewUrl));
      
      // Auto-stop after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (_playingAudioId == audioId) {
          _audioPlayer.stop();
          if (mounted) {
            setState(() => _playingAudioId = null);
          }
        }
      });
      
      // Listen for completion
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted && _playingAudioId == audioId) {
          setState(() => _playingAudioId = null);
        }
      });
    } catch (e) {
      setState(() => _playingAudioId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play preview: $e')),
        );
      }
    }
  }
  
  void _selectAudio(Map<String, dynamic> audio) {
    _audioPlayer.stop();
    if (widget.onAudioSelected != null) {
      widget.onAudioSelected!(audio);
    }
    Navigator.pop(context, audio);
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Add Audio'),
      ),
      body: Column(
        children: [
          // Tabs and search bar
          Container(
            color: isDark ? const Color(0xFF202C33) : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Tabs
                Row(
                  children: [
                    _buildTabButton('Search', 'search', isDark),
                    const SizedBox(width: 8),
                    _buildTabButton('Trending', 'trending', isDark),
                  ],
                ),
                const SizedBox(height: 16),
                // Search bar
                if (_currentTab == 'search')
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search sounds...',
                      prefixIcon: const Icon(Icons.search),
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
                              icon: const Icon(Icons.send),
                              onPressed: _search,
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF111B21) : Colors.grey[100],
                    ),
                    onSubmitted: (_) => _search(),
                  ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _currentTab == 'search' ? Icons.search : Icons.trending_up,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _currentTab == 'search'
                                  ? 'Search for sounds to add to your video'
                                  : 'No trending sounds yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final audio = _searchResults[index];
                          return _buildAudioTile(audio, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(String label, String tab, bool isDark) {
    final isActive = _currentTab == tab;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentTab = tab);
          if (tab == 'trending') {
            _loadTrending();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF008069)
                : (isDark ? const Color(0xFF111B21) : Colors.grey[200]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAudioTile(Map<String, dynamic> audio, bool isDark) {
    final audioId = audio['id'];
    final isPlaying = _playingAudioId == audioId;
    final name = audio['name'] ?? 'Unknown';
    final duration = audio['duration'] ?? 0;
    final username = audio['freesound_username'] ?? audio['username'] ?? 'Unknown';
    final license = audio['license_type'] ?? audio['license'] ?? 'Unknown';
    final attributionRequired = audio['attribution_required'] ?? false;
    
    // Format duration
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    final durationText = '$minutes:${seconds.toString().padLeft(2, '0')}';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF202C33) : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF008069),
          child: Icon(
            isPlaying ? Icons.stop : Icons.music_note,
            color: Colors.white,
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'by $username • $durationText',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: license.contains('CC0')
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    license.contains('CC0') ? 'CC0' : 'CC BY',
                    style: TextStyle(
                      fontSize: 10,
                      color: license.contains('CC0') ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (attributionRequired) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 12, color: Colors.orange[700]),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.stop_circle : Icons.play_circle,
                color: const Color(0xFF008069),
                size: 32,
              ),
              onPressed: () => _playPreview(audio),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Color(0xFF008069), size: 32),
              onPressed: () => _selectAudio(audio),
            ),
          ],
        ),
      ),
    );
  }
}
