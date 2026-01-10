import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:video_player/video_player.dart';
import 'status_repository.dart';
import '../../core/providers.dart';
import '../world/widgets/video_trimmer_widget.dart';

class CreateStatusScreen extends ConsumerStatefulWidget {
  const CreateStatusScreen({super.key});

  @override
  ConsumerState<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends ConsumerState<CreateStatusScreen> {
  final _textController = TextEditingController();
  
  File? _selectedMedia;
  bool _isVideo = false;
  bool _isLoading = false;
  bool _showEmojiPicker = false;
  Map<String, dynamic>? _uploadLimits;
  
  final List<Color> _backgroundColors = [
    const Color(0xFF00A884),
    const Color(0xFF6C5CE7),
    const Color(0xFFFF7675),
    const Color(0xFF74B9FF),
    const Color(0xFFFAB1A0),
    const Color(0xFFFDCB6E),
    const Color(0xFF00B894),
    const Color(0xFFD63031),
    const Color(0xFF0984E3),
    const Color(0xFFFF6348),
  ];
  
  Color _selectedColor = const Color(0xFF00A884);

  @override
  void initState() {
    super.initState();
    _loadUploadLimits();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadUploadLimits() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getUploadLimits();
      
      if (mounted) {
        setState(() {
          _uploadLimits = response.data;
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

      final maxDuration = _uploadLimits?['status']?['max_duration'] ?? 180;
      
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
          setState(() {
            _selectedMedia = trimmedVideo;
            _isVideo = true;
          });
        }
      } else {
        setState(() {
          _selectedMedia = videoFile;
          _isVideo = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check video: $e')),
        );
      }
    }
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final extension = result.files.single.extension?.toLowerCase();
      final isVideo = extension == 'mp4' || extension == 'mov' || extension == 'avi';
      
      if (isVideo) {
        // Check video duration and show trim UI if needed
        await _checkVideoAndTrim(file);
      } else {
        setState(() {
          _selectedMedia = file;
          _isVideo = false;
        });
      }
    }
  }

  Future<void> _createStatus() async {
    if (_isLoading) return;

    if (_selectedMedia == null && _textController.text.trim().isEmpty) {
      _showError('Please add text or select media');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(statusRepositoryProvider);

      if (_selectedMedia != null) {
        if (_isVideo) {
          await repo.createVideoStatus(
            videoFile: _selectedMedia!,
            caption: _textController.text.isNotEmpty ? _textController.text : null,
          );
        } else {
          await repo.createImageStatus(
            imageFile: _selectedMedia!,
            caption: _textController.text.isNotEmpty ? _textController.text : null,
          );
        }
      } else {
        await repo.createTextStatus(
          text: _textController.text,
          backgroundColor: '#${_selectedColor.value.toRadixString(16).substring(2)}',
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to create status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Create Status'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createStatus,
            child: const Text('Share'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Media preview or text input
                if (_selectedMedia != null)
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isVideo
                        ? const Center(child: Icon(Icons.videocam, size: 64))
                        : Image.file(_selectedMedia!, fit: BoxFit.cover),
                  )
                else
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type a status...',
                        hintStyle: TextStyle(color: Colors.white70),
                        contentPadding: EdgeInsets.all(24),
                      ),
                      maxLines: null,
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // Caption input for media
                if (_selectedMedia != null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _showEmojiPicker = !_showEmojiPicker;
                          });
                        },
                      ),
                    ),
                    maxLines: 3,
                  ),
                  if (_showEmojiPicker)
                    Container(
                      height: 250,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF202C33) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3B4A54) : Colors.grey[300]!,
                        ),
                      ),
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          _textController.text = _textController.text + emoji.emoji;
                        },
                        config: const Config(
                          height: 250,
                          checkPlatformCompatibility: true,
                        ),
                      ),
                    ),
                ],
                
                const SizedBox(height: 24),
                
                // Color picker (for text status)
                if (_selectedMedia == null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _backgroundColors.map((color) {
                      final isSelected = color == _selectedColor;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                
                const SizedBox(height: 24),
                
                // Pick media button
                OutlinedButton.icon(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(_selectedMedia != null ? 'Change Media' : 'Add Photo/Video'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


