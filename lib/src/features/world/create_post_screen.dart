import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../../core/providers.dart';
import '../audio/audio_search_screen.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  File? _selectedMedia; // Only one media file like TikTok
  bool _isPosting = false;
  VideoPlayerController? _videoController;
  Map<String, dynamic>? _selectedAudio;
  int _audioVolume = 100;

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Media'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      if (result == 'photo') {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          setState(() {
            _selectedMedia = File(pickedFile.path);
          });
        }
      } else if (result == 'video') {
        final picker = ImagePicker();
        final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
        if (pickedFile != null) {
          final videoFile = File(pickedFile.path);
          // Dispose previous controller
          await _videoController?.dispose();
          // Initialize video player
          final controller = VideoPlayerController.file(videoFile);
          await controller.initialize();
          await controller.setLooping(true);
          await controller.play();
          setState(() {
            _selectedMedia = videoFile;
            _videoController = controller;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick media: $e')),
        );
      }
    }
  }

  void _removeMedia() async {
    await _videoController?.dispose();
    setState(() {
      _selectedMedia = null;
      _videoController = null;
    });
  }

  Future<void> _createPost() async {
    // Media is required - World feed is like TikTok (no text-only posts)
    if (_selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo or video to post')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final caption = _captionController.text.trim();

      await apiService.createWorldFeedPost(
        media: _selectedMedia!,
        caption: caption.isNotEmpty ? caption : null,
        audioId: _selectedAudio?['id'],
        audioVolume: _selectedAudio != null ? _audioVolume : null,
        audioLoop: _selectedAudio != null ? true : null,
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _createPost,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      color: Color(0xFF008069),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media preview - required
            if (_selectedMedia == null)
              Container(
                height: 400,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey[300]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? const Color(0xFF202C33) : Colors.grey[100],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 64,
                        color: isDark ? Colors.white38 : Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Add a photo or video',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Media is required',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white38 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _pickMedia,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Choose Media'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF008069),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 400,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[300],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _selectedMedia!.path.toLowerCase().endsWith('.mp4') ||
                              _selectedMedia!.path.toLowerCase().endsWith('.mov') ||
                              _selectedMedia!.path.toLowerCase().endsWith('.avi') ||
                              _selectedMedia!.path.toLowerCase().endsWith('.mkv')
                          ? _videoController != null && _videoController!.value.isInitialized
                              ? AspectRatio(
                                  aspectRatio: _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!),
                                )
                              : const Center(
                                  child: CircularProgressIndicator(),
                                )
                          : Image.file(
                              _selectedMedia!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                      onPressed: _removeMedia,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // Caption field (optional)
            TextField(
              controller: _captionController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: "Add a caption (optional)...",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey[300]!,
                  ),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Audio selection (only for videos)
            if (_selectedMedia != null && _isVideo(_selectedMedia!))
              _buildAudioSection(isDark),
            
            if (_selectedMedia == null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Media'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008069),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  bool _isVideo(File file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.mp4') || 
           path.endsWith('.mov') || 
           path.endsWith('.avi') || 
           path.endsWith('.mkv');
  }
  
  Widget _buildAudioSection(bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF202C33) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.music_note, color: Color(0xFF008069)),
            title: Text(
              _selectedAudio == null ? 'Add Audio' : _selectedAudio!['name'] ?? 'Audio',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: _selectedAudio != null
                ? Text(
                    'by ${_selectedAudio!['freesound_username'] ?? 'Unknown'}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  )
                : Text(
                    'Add background music to your video',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
            trailing: _selectedAudio == null
                ? const Icon(Icons.add_circle_outline, color: Color(0xFF008069))
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() => _selectedAudio = null);
                    },
                  ),
            onTap: () async {
              final audio = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AudioSearchScreen(),
                ),
              );
              
              if (audio != null) {
                setState(() => _selectedAudio = audio);
              }
            },
          ),
          if (_selectedAudio != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        size: 20,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _audioVolume.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '$_audioVolume%',
                          activeColor: const Color(0xFF008069),
                          onChanged: (value) {
                            setState(() => _audioVolume = value.toInt());
                          },
                        ),
                      ),
                      Text(
                        '$_audioVolume%',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedAudio!['attribution_required'] == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Attribution: ${_selectedAudio!['attribution_text'] ?? ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

