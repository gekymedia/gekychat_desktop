import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';
import '../../core/providers.dart';
import '../../services/video_compression_service.dart';
import '../audio/audio_search_screen.dart';
import 'widgets/video_trimmer_widget.dart';
import 'world_feed_repository.dart';
import '../../utils/snackbar_helper.dart';

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
  Map<String, dynamic>? _uploadLimits;

  @override
  void initState() {
    super.initState();
    _loadUploadLimits();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadUploadLimits() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getUploadLimits();
      
      if (mounted) {
        setState(() {
          _uploadLimits = parseUploadLimitsPayload(response.data);
        });
      }
    } catch (e) {
      // Limits will default to backend values
    }
  }

  Future<void> _checkVideoAndTrim(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final durationSeconds = controller.value.duration.inSeconds;
      await controller.dispose();

      final maxDuration = uploadLimitDurationSeconds(
        _uploadLimits,
        'world_feed',
        fallback: 180,
      );
      
      if (durationSeconds > maxDuration) {
        if (!mounted) return;
        
        final trimmedVideo = await showDialog<File>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: VideoTrimmerWidget(
              videoFile: videoFile,
              maxDuration: maxDuration,
              onTrimComplete: (trimmed) {
                Navigator.pop(context, trimmed);
              },
              onCancel: () {
                Navigator.pop(context);
              },
            ),
          ),
        );

        if (trimmedVideo != null && mounted) {
          final trimmedController = VideoPlayerController.file(trimmedVideo);
          await trimmedController.initialize();
          await trimmedController.setLooping(true);
          await trimmedController.play();
          setState(() {
            _selectedMedia = trimmedVideo;
            _videoController = trimmedController;
          });
        }
      } else {
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();
        await controller.setLooping(true);
        await controller.play();
        setState(() {
          _selectedMedia = videoFile;
          _videoController = controller;
        });
      }
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to check video: $e');      }
    }
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
          await _videoController?.dispose();
          await _checkVideoAndTrim(videoFile);
        }
      }
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to pick media: $e');      }
    }
  }

  void _removeMedia() async {
    await _releaseVideoPreview();
    setState(() {
      _selectedMedia = null;
    });
  }

  Future<void> _releaseVideoPreview() async {
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      try {
        await controller.pause();
      } catch (_) {}
      await controller.dispose();
    }
  }

  int _worldFeedMaxVideoBytes() {
    return uploadLimitBytes(
      _uploadLimits,
      'world_feed',
      fallback: VideoCompressionService.worldFeedMaxBytesDefault,
    );
  }

  Future<File> _compressWorldFeedVideo(File videoFile) async {
    final maxBytes = _worldFeedMaxVideoBytes();
    final originalSize = await videoFile.length();
    if (originalSize > 40 * 1024 * 1024 && mounted) {
      context.showInfoToast(
        'Compressing video so it can upload. 4K clips can take a minute.',
      );
    }
    final out = await VideoCompressionService().compressVideo(
      videoFile,
      maxHeight: 720,
      skipIfUnderBytes: 15 * 1024 * 1024,
      maxBytes: maxBytes,
    );
    final size = await out.length();
    if (size > maxBytes) {
      throw VideoTooLargeException(maxBytes);
    }
    return out;
  }

  String _friendlyWorldPostError(Object error, {String kind = 'video'}) {
    return friendlyVideoUploadError(error, kind: kind);
  }

  Future<void> _uploadPreparedPost(
    ProviderContainer container, {
    required File media,
    required bool deleteAfterUpload,
    String? caption,
    int? audioId,
    int? audioVolume,
    bool? audioLoop,
  }) async {
    try {
      final apiService = container.read(apiServiceProvider);
      await apiService.createWorldFeedPost(
        media: media,
        caption: caption,
        audioId: audioId,
        audioVolume: audioVolume,
        audioLoop: audioLoop,
      );
      container.read(worldFeedRefreshNonceProvider.notifier).state++;
      SnackbarHelper.showSuccessGlobal('Post published');
    } catch (e) {
      SnackbarHelper.showErrorGlobal(
        _friendlyWorldPostError(
          e,
          kind: VideoCompressionService.isVideoPath(media.path)
              ? 'video'
              : 'photo',
        ),
      );
    } finally {
      if (deleteAfterUpload) {
        try {
          await media.delete();
        } catch (_) {}
      }
      container.read(worldPostPendingProvider.notifier).state = false;
    }
  }

  Future<void> _createPost() async {
    // Media is required - World feed is like TikTok (no text-only posts)
    if (_selectedMedia == null) {
            context.showInfoToast('Please add a photo or video to post');      return;
    }
    if (_isPosting) return;

    setState(() {
      _isPosting = true;
    });

    final container = ProviderScope.containerOf(context);
    File? compressTemp;

    try {
      var media = _selectedMedia!;
      final isVideo = _isVideo(media);

      if (isVideo) {
        await _releaseVideoPreview();
        if (mounted) setState(() {});
        await Future<void>.delayed(const Duration(milliseconds: 80));
        final compressed = await _compressWorldFeedVideo(media);
        if (compressed.path != media.path) {
          compressTemp = compressed;
          media = compressed;
        }
      }

      final caption = _captionController.text.trim();
      final audioId = _selectedAudio?['id'] is int
          ? _selectedAudio!['id'] as int
          : int.tryParse(_selectedAudio?['id']?.toString() ?? '');
      final audioVolume = _selectedAudio != null ? _audioVolume : null;
      final audioLoop = _selectedAudio != null ? true : null;

      container.read(worldPostPendingProvider.notifier).state = true;

      if (mounted) {
        Navigator.of(context).pop();
      }

      unawaited(
        _uploadPreparedPost(
          container,
          media: media,
          deleteAfterUpload: compressTemp != null,
          caption: caption.isNotEmpty ? caption : null,
          audioId: audioId,
          audioVolume: audioVolume,
          audioLoop: audioLoop,
        ),
      );
      compressTemp = null;
    } catch (e) {
      if (compressTemp != null) {
        try {
          await compressTemp.delete();
        } catch (_) {}
      }
      container.read(worldPostPendingProvider.notifier).state = false;
      if (mounted) {
        context.showErrorToast(_friendlyWorldPostError(e));
        if (_selectedMedia != null && _isVideo(_selectedMedia!)) {
          try {
            final controller = VideoPlayerController.file(_selectedMedia!);
            await controller.initialize();
            await controller.setLooping(true);
            await controller.play();
            if (mounted) {
              setState(() => _videoController = controller);
            } else {
              await controller.dispose();
            }
          } catch (_) {}
        }
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

    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.3),
      insetPadding: const EdgeInsets.symmetric(horizontal: 100, vertical: 50),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 900),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF202C33) : Colors.white).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Create Post'),
            backgroundColor: Colors.transparent,
            elevation: 0,
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
        ),
      ),
    );
  }
  
  bool _isVideo(File file) {
    return VideoCompressionService.isVideoPath(file.path);
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

