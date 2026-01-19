import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'status_repository.dart';
import '../../core/providers.dart';

/// Helper function to build avatar with error handling
Widget _buildStatusAvatar({required String? avatarUrl, required String name, required double radius}) {
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

class StatusViewerScreen extends ConsumerStatefulWidget {
  final StatusSummary statusSummary;
  final int startIndex;
  final bool isOwnStatus;

  const StatusViewerScreen({
    super.key,
    required this.statusSummary,
    this.startIndex = 0,
    this.isOwnStatus = false,
  });

  @override
  ConsumerState<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends ConsumerState<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  late int currentIndex;
  late AnimationController _progressController;
  VideoPlayerController? _videoController;
  Timer? _autoAdvanceTimer;
  bool _isPaused = false;
  bool _stealthModeEnabled = false; // Stealth viewing toggle

  static const _imageDuration = Duration(seconds: 5);
  static const _textDuration = Duration(seconds: 7);

  @override
  void initState() {
    super.initState();
    currentIndex = widget.startIndex;
    _progressController = AnimationController(vsync: this);
    _loadCurrentStatus();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.dispose();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentStatus() async {
    final status = widget.statusSummary.updates[currentIndex];

    if (!widget.isOwnStatus) {
      final repo = ref.read(statusRepositoryProvider);
      await repo.markStatusAsViewed(status.id, stealth: _stealthModeEnabled);
    }

    _videoController?.dispose();
    _videoController = null;
    _progressController.reset();

    switch (status.type) {
      case StatusType.text:
        _startAutoAdvance(_textDuration);
        break;
      case StatusType.image:
        _startAutoAdvance(_imageDuration);
        break;
      case StatusType.video:
        if (status.mediaUrl != null) {
          await _initializeVideo(status.mediaUrl!);
        }
        break;
    }
  }

  Future<void> _initializeVideo(String url) async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      await _videoController!.play();

      final duration = _videoController!.value.duration;
      _startAutoAdvance(duration);

      _videoController!.addListener(() {
        if (_videoController!.value.position >= _videoController!.value.duration) {
          _nextStatus();
        }
      });

      setState(() {});
    } catch (e) {
      debugPrint('Error initializing video: $e');
      _startAutoAdvance(_imageDuration);
    }
  }

  void _startAutoAdvance(Duration duration) {
    _autoAdvanceTimer?.cancel();
    
    _progressController.duration = duration;
    _progressController.forward();

    _autoAdvanceTimer = Timer(duration, () {
      if (mounted && !_isPaused) {
        _nextStatus();
      }
    });
  }

  void _nextStatus() {
    if (currentIndex < widget.statusSummary.updates.length - 1) {
      setState(() {
        currentIndex++;
      });
      _loadCurrentStatus();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStatus() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
      _loadCurrentStatus();
    } else {
      Navigator.pop(context);
    }
  }

  void _toggleStealthMode() {
    setState(() {
      _stealthModeEnabled = !_stealthModeEnabled;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_stealthModeEnabled
              ? 'Stealth mode enabled - views will be hidden'
              : 'Stealth mode disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    
    if (_isPaused) {
      _autoAdvanceTimer?.cancel();
      _progressController.stop();
      _videoController?.pause();
    } else {
      _progressController.forward();
      _videoController?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statusSummary.updates[currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 2) {
            _previousStatus();
          } else {
            _nextStatus();
          }
        },
        child: Stack(
          children: [
            // Status content
            _buildStatusContent(status, isDark),
            
            // Header with progress bars
            _buildHeader(isDark),
            
            // Navigation buttons at edges
            _buildNavigationButtons(),
            
            // Bottom controls
            _buildBottomControls(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(StatusUpdate status, bool isDark) {
    switch (status.type) {
      case StatusType.text:
        return Container(
          color: status.backgroundColor != null
              ? Color(int.parse(status.backgroundColor!.replaceFirst('#', '0xFF')))
              : const Color(0xFF00A884),
          child: Center(
            child: Text(
              status.text ?? '',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      case StatusType.image:
        return CachedNetworkImage(
          imageUrl: status.mediaUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      case StatusType.video:
        return _videoController != null && _videoController!.value.isInitialized
            ? AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
            : const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildHeader(bool isDark) {
    return SafeArea(
      child: Column(
        children: [
          // Progress bars
          Row(
            children: widget.statusSummary.updates.asMap().entries.map((entry) {
              final index = entry.key;
              final isActive = index == currentIndex;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 2,
                    right: index == widget.statusSummary.updates.length - 1 ? 0 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }).toList(),
          ),
          
          // User info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatusAvatar(
                  avatarUrl: widget.statusSummary.userAvatar,
                  name: widget.statusSummary.userName,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.statusSummary.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Just now',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isOwnStatus) ...[
                  // View count and viewers button
                  if (widget.statusSummary.updates[currentIndex].viewCount > 0)
                    GestureDetector(
                      onTap: () => _showViewersList(widget.statusSummary.updates[currentIndex].id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.statusSummary.updates[currentIndex].viewCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ] else ...[
                  // PHASE 1: Stealth mode toggle
                  IconButton(
                    icon: Icon(
                      _stealthModeEnabled ? Icons.visibility_off : Icons.visibility,
                      color: _stealthModeEnabled ? Colors.amber : Colors.white,
                    ),
                    tooltip: _stealthModeEnabled
                        ? 'Stealth mode: ON (view hidden)'
                        : 'Stealth mode: OFF',
                    onPressed: _toggleStealthMode,
                  ),
                  // PHASE 1: Download button
                  if ((widget.statusSummary.updates[currentIndex].type == StatusType.image || 
                       widget.statusSummary.updates[currentIndex].type == StatusType.video) &&
                      widget.statusSummary.updates[currentIndex].allowDownload != false)
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: _downloadStatusMedia,
                      tooltip: 'Download',
                    ),
                ],
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View count for own status
              if (widget.isOwnStatus && widget.statusSummary.updates[currentIndex].viewCount > 0)
                GestureDetector(
                  onTap: () => _showViewersList(widget.statusSummary.updates[currentIndex].id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.statusSummary.updates[currentIndex].viewCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.comment_outlined, color: Colors.white, size: 28),
                    onPressed: () => _showCommentsDialog(widget.statusSummary.updates[currentIndex].id),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
                    onPressed: _togglePause,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavigationButtons() {
    return Stack(
      children: [
        // Previous button at left edge, vertically centered
        Positioned(
          left: 16,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
              onPressed: currentIndex > 0 ? _previousStatus : null,
            ),
          ),
        ),
        // Next button at right edge, vertically centered
        Positioned(
          right: 16,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
              onPressed: currentIndex < widget.statusSummary.updates.length - 1 ? _nextStatus : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showViewersList(int statusId) async {
    final repo = ref.read(statusRepositoryProvider);
    try {
      final viewers = await repo.getStatusViewers(statusId);
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _ViewersListSheet(viewers: viewers),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load viewers: $e')),
        );
      }
    }
  }

  Future<void> _showCommentsDialog(int statusId) async {
    // Pause video if it's currently playing
    if (_videoController != null && _videoController!.value.isPlaying) {
      // Pause the video
      _videoController!.pause();
      _autoAdvanceTimer?.cancel();
      _progressController.stop();
      setState(() {
        _isPaused = true;
      });
    }
    
    final repo = ref.read(statusRepositoryProvider);
    List<StatusComment> comments = [];

    try {
      comments = await repo.getStatusComments(statusId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _CommentsDialog(
        statusId: statusId,
        initialComments: comments,
      ),
    );
  }


  // PHASE 1: Download status media
  Future<void> _downloadStatusMedia() async {
    final status = widget.statusSummary.updates[currentIndex];
    
    if (status.mediaUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No media to download')),
      );
      return;
    }

    try {
      final repo = ref.read(statusRepositoryProvider);
      final downloadUrl = repo.getStatusDownloadUrl(status.id);
      final apiService = ref.read(apiServiceProvider);
      
      // Determine file extension from media URL or status type
      String fileExtension = 'jpg';
      if (status.type == StatusType.video) {
        fileExtension = 'mp4';
      } else if (status.type == StatusType.image) {
        final url = status.mediaUrl ?? '';
        if (url.contains('.')) {
          fileExtension = url.split('.').last.split('?').first;
        }
      }
      
      final fileName = 'status_${status.id}.$fileExtension';
      
      // Get download directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      
      final savePath = '${downloadDir.path}/$fileName';
      
      // Show downloading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading...')),
        );
      }
      
      // Download file using apiService
      await apiService.downloadFile(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            debugPrint('Download progress: $progress%');
          }
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to Downloads/$fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    }
  }
}

/// Viewers list bottom sheet
class _ViewersListSheet extends StatelessWidget {
  final List<StatusViewer> viewers;

  const _ViewersListSheet({required this.viewers});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Viewers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                Text(
                  '${viewers.length}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Viewers list
          Flexible(
            child: viewers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No viewers yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: viewers.length,
                    itemBuilder: (context, index) {
                      final viewer = viewers[index];
                      return ListTile(
                        leading: _buildStatusAvatar(
                          avatarUrl: viewer.userAvatar,
                          name: viewer.userName,
                          radius: 20,
                        ),
                        title: Text(
                          viewer.userName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('MMM d, h:mm a').format(viewer.viewedAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CommentsDialog extends ConsumerStatefulWidget {
  final int statusId;
  final List<StatusComment> initialComments;

  const _CommentsDialog({
    required this.statusId,
    required this.initialComments,
  });

  @override
  ConsumerState<_CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends ConsumerState<_CommentsDialog> {
  final TextEditingController _commentController = TextEditingController();
  List<StatusComment> _comments = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _comments = widget.initialComments;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      final repo = ref.read(statusRepositoryProvider);
      final comment = await repo.addStatusComment(widget.statusId, _commentController.text.trim());
      _commentController.clear();
      setState(() {
        _comments.add(comment);
        _isSending = false;
      });
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
      child: Container(
        width: 500,
        height: 600,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            
            // Comments list
            Expanded(
              child: _comments.isEmpty
                  ? Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatusAvatar(
                                avatarUrl: comment.user['avatar_url'],
                                name: comment.user['name'] ?? 'Unknown',
                                radius: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment.user['name'] ?? 'Unknown',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            comment.comment,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('h:mm a').format(comment.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            
            // Comment input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202C33) : Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Reply to status...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Color(0xFF008069)),
                    onPressed: _isSending ? null : _sendComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


