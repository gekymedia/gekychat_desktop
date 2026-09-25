import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/providers.dart';
import '../../services/video_compression_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/desktop_shell_colors.dart';
import '../audio/audio_search_screen.dart';
import 'widgets/video_trimmer_widget.dart';
import 'world_feed_repository.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  static const _accent = Color(0xFF008069);

  final _captionController = TextEditingController();
  File? _selectedMedia;
  bool _isPosting = false;
  bool _isDragging = false;
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
    } catch (_) {
      // Limits fall back to backend defaults.
    }
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.bmp');
  }

  bool _isVideo(File file) => VideoCompressionService.isVideoPath(file.path);

  Future<void> _applyMediaFile(File file) async {
    final path = file.path;
    if (_isVideo(file)) {
      await _videoController?.dispose();
      _videoController = null;
      await _checkVideoAndTrim(file);
      return;
    }
    if (_isImagePath(path)) {
      await _releaseVideoPreview();
      if (!mounted) return;
      setState(() {
        _selectedMedia = file;
        _selectedAudio = null;
      });
      return;
    }
    if (mounted) {
      context.showErrorToast('Please use a photo or video file');
    }
  }

  Future<void> _onFilesDropped(DropDoneDetails detail) async {
    setState(() => _isDragging = false);
    if (detail.files.isEmpty) return;
    final path = detail.files.first.path;
    if (path.isEmpty) return;
    await _applyMediaFile(File(path));
  }

  Future<void> _checkVideoAndTrim(File videoFile) async {
    try {
      final probe = VideoPlayerController.file(videoFile);
      await probe.initialize();
      final durationSeconds = probe.value.duration.inSeconds;
      await probe.dispose();

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
              onTrimComplete: (trimmed) => Navigator.pop(context, trimmed),
              onCancel: () => Navigator.pop(context),
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
        if (!mounted) {
          await controller.dispose();
          return;
        }
        setState(() {
          _selectedMedia = videoFile;
          _videoController = controller;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to open video: $e');
      }
    }
  }

  Future<void> _pickMedia({required bool video}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: video ? FileType.video : FileType.image,
        allowMultiple: false,
        withData: false,
      );
      final path = result?.files.single.path;
      if (path == null || path.isEmpty) return;
      await _applyMediaFile(File(path));
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to pick media: $e');
      }
    }
  }

  Future<void> _showPickSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF202C33)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_outlined, color: _accent),
                  title: const Text('Photo'),
                  onTap: () => Navigator.pop(context, 'photo'),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_outlined, color: _accent),
                  title: const Text('Video'),
                  onTap: () => Navigator.pop(context, 'video'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (choice == 'photo') await _pickMedia(video: false);
    if (choice == 'video') await _pickMedia(video: true);
  }

  Future<void> _removeMedia() async {
    await _releaseVideoPreview();
    setState(() {
      _selectedMedia = null;
      _selectedAudio = null;
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
    if (_selectedMedia == null) {
      context.showInfoToast('Add a photo or video to post');
      return;
    }
    if (_isPosting) return;

    setState(() => _isPosting = true);

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
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF111B21) : Colors.white;
    final border = DesktopShellColors.listPanelBorder(isDark);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      child: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: _onFilesDropped,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDragging ? _accent : border,
              width: _isDragging ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: panelBg,
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Divider(height: 1, color: border),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 720;
                        final media = _buildMediaPane(isDark);
                        final details = _buildDetailsPane(isDark);
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: media),
                              VerticalDivider(width: 1, color: border),
                              Expanded(flex: 4, child: details),
                            ],
                          );
                        }
                        return SingleChildScrollView(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              SizedBox(height: 360, child: media),
                              Divider(height: 1, color: border),
                              details,
                            ],
                          ),
                        );
                      },
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

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: _isPosting ? null : () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create World post',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Drop a photo or video anywhere, or browse',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _isPosting || _selectedMedia == null ? null : _createPost,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _accent.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isPosting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPane(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: isDark ? const Color(0xFF0B141A) : const Color(0xFFF7F8FA),
        ),
        if (_selectedMedia == null)
          _buildEmptyDropZone(isDark)
        else
          _buildMediaPreview(isDark),
        if (_isDragging)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  border: Border.all(color: _accent, width: 3),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF202C33) : Colors.white)
                          .withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _accent, width: 1.5),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_download_outlined, size: 36, color: _accent),
                        SizedBox(height: 10),
                        Text(
                          'Drop to attach',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _accent,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Photos and videos supported',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyDropZone(bool isDark) {
    final line = isDark ? Colors.white24 : const Color(0xFFD0D5DD);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: CustomPaint(
            painter: _DashedRRectPainter(
              color: _isDragging ? _accent : line,
              radius: 16,
              strokeWidth: _isDragging ? 2.2 : 1.4,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: isDark ? 0.18 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.collections_outlined,
                      size: 34,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Drag & drop a photo or video',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'World posts need media — drop a file here or browse.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _pickMedia(video: false),
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('Photo'),
                        style: FilledButton.styleFrom(
                          foregroundColor: _accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _pickMedia(video: true),
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Video'),
                        style: FilledButton.styleFrom(
                          foregroundColor: _accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(bool isDark) {
    final media = _selectedMedia!;
    final video = _isVideo(media);

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: video
              ? (_videoController != null &&
                      _videoController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio == 0
                          ? 9 / 16
                          : _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : const CircularProgressIndicator(color: _accent))
              : Image.file(
                  media,
                  fit: BoxFit.contain,
                ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            children: [
              _PreviewChip(
                icon: Icons.swap_horiz,
                label: 'Replace',
                onTap: _showPickSheet,
              ),
              const SizedBox(width: 8),
              _PreviewChip(
                icon: Icons.close,
                label: 'Remove',
                onTap: _removeMedia,
              ),
            ],
          ),
        ),
        if (video)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsPane(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Caption',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            maxLines: 5,
            minLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Say something about this post (optional)',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _accent, width: 1.4),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          if (_selectedMedia != null && _isVideo(_selectedMedia!)) ...[
            const SizedBox(height: 8),
            _buildAudioSection(isDark),
          ],
          if (_selectedMedia == null) ...[
            const SizedBox(height: 8),
            Text(
              'Tip: you can drag a file from Explorer or Finder onto this window.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B141A) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.music_note, color: _accent),
            title: Text(
              _selectedAudio == null
                  ? 'Add audio'
                  : _selectedAudio!['name']?.toString() ?? 'Audio',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              _selectedAudio != null
                  ? 'by ${_selectedAudio!['freesound_username'] ?? 'Unknown'}'
                  : 'Optional background music for your video',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 12.5,
              ),
            ),
            trailing: _selectedAudio == null
                ? const Icon(Icons.add_circle_outline, color: _accent)
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: () => setState(() => _selectedAudio = null),
                  ),
            onTap: () async {
              final audio = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AudioSearchScreen(),
                ),
              );
              if (audio != null && mounted) {
                setState(() => _selectedAudio = audio);
              }
            },
          ),
          if (_selectedAudio != null) ...[
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      Expanded(
                        child: Slider(
                          value: _audioVolume.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '$_audioVolume%',
                          activeColor: _accent,
                          onChanged: (value) {
                            setState(() => _audioVolume = value.toInt());
                          },
                        ),
                      ),
                      Text(
                        '$_audioVolume%',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedAudio!['attribution_required'] == true) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Attribution: ${_selectedAudio!['attribution_text'] ?? ''}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.orange[800],
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

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  static const double dash = 7;
  static const double gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
