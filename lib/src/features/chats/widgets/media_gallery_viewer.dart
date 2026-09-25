import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../models.dart';
import '../../../services/download_path_service.dart';
import '../../../utils/desktop_file_actions.dart';
import '../../../utils/snackbar_helper.dart';

/// A media item in the gallery, tied to its parent message for actions.
class GalleryMediaItem {
  final MessageAttachment attachment;
  final Message message;
  final bool isSent;

  const GalleryMediaItem({
    required this.attachment,
    required this.message,
    required this.isSent,
  });
}

/// Full-screen media viewer with swipe/keyboard navigation between chat media.
class MediaGalleryViewer extends StatefulWidget {
  final List<GalleryMediaItem> items;
  final int initialIndex;
  final bool isViewOnce;
  final void Function(Message message)? onReply;
  final Future<void> Function(Message message)? onForward;
  final Future<void> Function(Message message)? onDelete;
  final void Function(Message message, String emoji)? onReact;
  final void Function(Message message, bool pin)? onPin;
  final void Function(Message message)? onGoToMessage;

  const MediaGalleryViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    this.isViewOnce = false,
    this.onReply,
    this.onForward,
    this.onDelete,
    this.onReact,
    this.onPin,
    this.onGoToMessage,
  });

  @override
  State<MediaGalleryViewer> createState() => _MediaGalleryViewerState();
}

class _MediaGalleryViewerState extends State<MediaGalleryViewer> {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;
  final Map<int, VideoPlayerController?> _videoControllers = {};
  bool _showControls = true;
  bool _isDownloading = false;
  double _currentZoom = 1.0;
  late TransformationController _transformationController;

  GalleryMediaItem get _currentItem => widget.items[_currentIndex];

  static const double _thumbSize = 56;
  static const double _thumbGap = 6;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();
    _transformationController = TransformationController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbnailIntoView(_currentIndex, animate: false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _transformationController.dispose();
    // Controllers are owned by [_VideoPlayerWidget]; only clear the map.
    _videoControllers.clear();
    super.dispose();
  }

  void _onPageChanged(int index) {
    _videoControllers[_currentIndex]?.pause();
    setState(() {
      _currentIndex = index;
      _currentZoom = 1.0;
      _transformationController.value = Matrix4.identity();
    });
    _scrollThumbnailIntoView(index);
  }

  void _scrollThumbnailIntoView(int index, {bool animate = true}) {
    if (!_thumbnailScrollController.hasClients) return;
    final target = (index * (_thumbSize + _thumbGap)) -
        (_thumbnailScrollController.position.viewportDimension / 2) +
        (_thumbSize / 2);
    final offset = target.clamp(
      0.0,
      _thumbnailScrollController.position.maxScrollExtent,
    );
    if (animate) {
      _thumbnailScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _thumbnailScrollController.jumpTo(offset);
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.items.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goPrevious() => _goToPage(_currentIndex - 1);

  void _goNext() => _goToPage(_currentIndex + 1);

  bool _isVideo(MessageAttachment attachment) {
    if (attachment.isVideo) return true;
    final mimeType = attachment.mimeType.toLowerCase();
    if (mimeType.startsWith('video/')) return true;
    final url = attachment.url.toLowerCase();
    return url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.avi') ||
        url.endsWith('.mkv') ||
        url.endsWith('.webm');
  }

  Future<void> _shareCurrentMedia() async {
    final attachment = _currentItem.attachment;

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName =
          attachment.originalName?.trim().isNotEmpty == true
              ? attachment.originalName!
              : 'share_${attachment.id}${_extensionFor(attachment)}';
      final downloadPath = '${tempDir.path}/$fileName';

      final dio = Dio();
      await dio.download(attachment.displayUrl, downloadPath);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(downloadPath, mimeType: attachment.mimeType)],
        text: attachment.originalName,
      );
    } catch (e) {
      if (!mounted) return;
      if (attachment.url.isNotEmpty) {
        try {
          await Share.share(attachment.url);
          return;
        } catch (_) {}
      }
            context.showErrorToast('Failed to share: $e');    }
  }

  Future<String?> _existingDownloadPath() async {
    final attachment = _currentItem.attachment;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored =
          await DownloadPathService(prefs).getDownloadPath(attachment.url);
      if (stored != null && await File(stored).exists()) return stored;
      if (stored != null) {
        await DownloadPathService(prefs).removeDownloadPath(attachment.url);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _promptAlreadyDownloaded() {
    final kind = _isVideo(_currentItem.attachment) ? 'Video' : 'Image';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$kind already downloaded'),
        content: const Text(
          'This file is already saved on your computer. '
          'You can open its folder or download another copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('reveal'),
            child: const Text('Show in folder'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('again'),
            child: const Text('Download again'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCurrentMedia({bool forceNewCopy = false}) async {
    if (_isDownloading) return;

    final attachment = _currentItem.attachment;

    if (!forceNewCopy) {
      final existing = await _existingDownloadPath();
      if (existing != null) {
        if (!mounted) return;
        final choice = await _promptAlreadyDownloaded();
        if (!mounted || choice == null) return;
        if (choice == 'reveal') {
          final ok = await DesktopFileActions.revealInFileManager(existing);
          if (!mounted) return;
          if (!ok) {
            context.showErrorToast('Could not open folder');
          }
          return;
        }
        if (choice != 'again') return;
        forceNewCopy = true;
      }
    }

    setState(() => _isDownloading = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads/GekyChat');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final fileName = attachment.originalName?.trim().isNotEmpty == true
          ? attachment.originalName!
          : 'gekychat_${attachment.id}${_extensionFor(attachment)}';
      var savePath = '${downloadDir.path}/$fileName';
      if (forceNewCopy) {
        savePath = await DesktopFileActions.uniqueDownloadPath(savePath);
      }

      final dio = Dio();
      await dio.download(attachment.displayUrl, savePath);

      try {
        final prefs = await SharedPreferences.getInstance();
        await DownloadPathService(prefs)
            .saveDownloadPath(attachment.url, savePath);
      } catch (_) {}

      if (!mounted) return;
      final savedName = savePath.split(RegExp(r'[/\\]')).last;
      SnackbarHelper.showSuccess(
        context,
        'Downloaded $savedName',
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Show in folder',
          onPressed: () {
            unawaited(DesktopFileActions.revealInFileManager(savePath));
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Failed to download: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _copyCurrentImageToClipboard() async {
    final attachment = _currentItem.attachment;
    if (_isVideo(attachment)) {
      if (!mounted) return;
      context.showInfoToast('Copy works for images');
      return;
    }
    final ok = await DesktopFileActions.copyNetworkImageToClipboard(
      attachment.displayUrl,
    );
    if (!mounted) return;
    if (ok) {
      context.showSuccessToast('Image copied to clipboard');
    } else {
      context.showErrorToast('Could not copy image');
    }
  }

  void _showImageContextMenu(Offset globalPosition) {
    final attachment = _currentItem.attachment;
    if (_isVideo(attachment) || widget.isViewOnce) return;

    final albumMedia = _currentItem.message.attachments
        .where((a) => a.isImage || a.isVideo)
        .toList();
    final hasAlbum = albumMedia.length > 1;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlaySize = overlay?.size ?? MediaQuery.sizeOf(context);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlaySize.width - globalPosition.dx,
        overlaySize.height - globalPosition.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 18),
              SizedBox(width: 12),
              Text('Copy image'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.download_rounded, size: 18),
              SizedBox(width: 12),
              Text('Download'),
            ],
          ),
        ),
        if (hasAlbum)
          const PopupMenuItem(
            value: 'download_all',
            child: Row(
              children: [
                Icon(Icons.download_for_offline_outlined, size: 18),
                SizedBox(width: 12),
                Text('Download all'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'reveal',
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 18),
              SizedBox(width: 12),
              Text('Show in folder'),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (value == 'copy') {
        unawaited(_copyCurrentImageToClipboard());
      } else if (value == 'download') {
        unawaited(_downloadCurrentMedia());
      } else if (value == 'download_all') {
        unawaited(_downloadAlbumMedia(albumMedia));
      } else if (value == 'reveal') {
        final existing = await _existingDownloadPath();
        if (existing != null) {
          unawaited(DesktopFileActions.revealInFileManager(existing));
        } else if (mounted) {
          context.showInfoToast('Download this file first');
        }
      }
    });
  }

  Future<void> _downloadAlbumMedia(List<MessageAttachment> attachments) async {
    if (_isDownloading || attachments.isEmpty) return;
    setState(() => _isDownloading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads/GekyChat');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      final downloadPathService = DownloadPathService(prefs);
      final dio = Dio();
      var saved = 0;
      String? lastPath;

      for (final attachment in attachments) {
        final existing =
            await downloadPathService.getDownloadPath(attachment.url);
        if (existing != null && await File(existing).exists()) {
          saved++;
          lastPath = existing;
          continue;
        }
        final fileName = attachment.originalName?.trim().isNotEmpty == true
            ? attachment.originalName!
            : 'gekychat_${attachment.id}${_extensionFor(attachment)}';
        var savePath = '${downloadDir.path}/$fileName';
        savePath = await DesktopFileActions.uniqueDownloadPath(savePath);
        await dio.download(attachment.displayUrl, savePath);
        await downloadPathService.saveDownloadPath(attachment.url, savePath);
        saved++;
        lastPath = savePath;
      }

      if (!mounted) return;
      SnackbarHelper.showSuccess(
        context,
        'Downloaded $saved of ${attachments.length}',
        duration: const Duration(seconds: 5),
        action: lastPath != null
            ? SnackBarAction(
                label: 'Show in folder',
                onPressed: () {
                  unawaited(DesktopFileActions.revealInFileManager(lastPath!));
                },
              )
            : null,
      );
    } catch (e) {
      if (!mounted) return;
      context.showErrorToast('Failed to download: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  String _extensionFor(MessageAttachment attachment) {
    final mimeMap = {
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/gif': '.gif',
      'image/webp': '.webp',
      'video/mp4': '.mp4',
      'video/quicktime': '.mov',
    };
    return mimeMap[attachment.mimeType] ?? '.bin';
  }

  void _runReply() {
    final callback = widget.onReply;
    if (callback == null) return;
    final message = _currentItem.message;
    Navigator.pop(context);
    callback(message);
  }

  Future<void> _runForward() async {
    final callback = widget.onForward;
    if (callback == null) return;
    final message = _currentItem.message;
    Navigator.pop(context);
    await callback(message);
  }

  void _runDelete() {
    final callback = widget.onDelete;
    if (callback == null) return;
    final message = _currentItem.message;
    Navigator.pop(context);
    callback(message);
  }

  void _goToMessage() {
    final message = _currentItem.message;
    Navigator.pop(context);
    widget.onGoToMessage?.call(message);
  }

  void _runPin() {
    final callback = widget.onPin;
    if (callback == null) return;
    final message = _currentItem.message;
    Navigator.pop(context);
    callback(message, true);
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 0.5).clamp(1.0, 4.0);
      _transformationController.value =
          Matrix4.identity()..scaleByDouble(_currentZoom, _currentZoom, 1.0, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 0.5).clamp(1.0, 4.0);
      _transformationController.value =
          Matrix4.identity()..scaleByDouble(_currentZoom, _currentZoom, 1.0, 1.0);
    });
  }

  void _showReactionPicker() {
    final callback = widget.onReact;
    if (callback == null) return;
    final message = _currentItem.message;
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.min,
          children: emojis.map((emoji) {
            return InkWell(
              onTap: () => Navigator.pop(ctx, emoji),
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            );
          }).toList(),
        ),
      ),
    ).then((emoji) {
      if (emoji == null || !mounted) return;
      Navigator.pop(context);
      callback(message, emoji);
    });
  }

  void _showMediaInfo() {
    final attachment = _currentItem.attachment;
    final message = _currentItem.message;
    final isSent = _currentItem.isSent;

    final senderName =
        isSent ? 'You' : (message.sender?['name']?.toString() ?? 'Unknown');
    final timestamp = _formatHeaderTimestamp(message.createdAt);
    final fileSize =
        _formatFileSize(attachment.compressedSize ?? attachment.originalSize);
    final mediaName = attachment.originalName ?? 'Unknown';
    final mediaType = _isVideo(attachment) ? 'Video' : 'Image';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Media info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: $mediaName'),
              const SizedBox(height: 8),
              Text('Type: $mediaType'),
              const SizedBox(height: 8),
              Text('Size: $fileSize'),
              const SizedBox(height: 8),
              Text('Sent: $timestamp'),
              const SizedBox(height: 8),
              Text('From: $senderName'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatHeaderTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year} at $hour12:$minute $ampm';
  }

  String? _senderAvatarUrl(Message message) {
    final sender = message.sender;
    if (sender == null) return null;
    final url = sender['avatar_url']?.toString() ??
        sender['avatar_path']?.toString();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  String _senderDisplayName() {
    if (_currentItem.isSent) return 'You';
    return _currentItem.message.sender?['name']?.toString() ?? 'Unknown';
  }

  Widget _buildSenderHeader(Color onBackdrop) {
    final avatarUrl = _senderAvatarUrl(_currentItem.message);
    final name = _senderDisplayName();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final dateText = _formatHeaderTimestamp(_currentItem.message.createdAt);

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFDFE5E7),
          backgroundImage:
              avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF54656F),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onBackdrop,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                dateText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onBackdrop.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(int index) {
    final item = widget.items[index];
    final attachment = item.attachment;
    final isVideo = _isVideo(attachment);
    final isSelected = index == _currentIndex;

    return GestureDetector(
      onTap: () => _goToPage(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _thumbSize,
        height: _thumbSize,
        margin: EdgeInsets.only(
          right: index == widget.items.length - 1 ? 0 : _thumbGap,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF00A884) : Colors.transparent,
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: attachment.thumbnailUrl ?? attachment.displayUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey[300]),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
              if (isVideo)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navChevron({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF3B4A54).withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _moreMenuItems() {
    return [
      const PopupMenuItem(
        value: 'download',
        child: Row(
          children: [
            Icon(Icons.download_rounded, size: 18),
            SizedBox(width: 12),
            Text('Download'),
          ],
        ),
      ),
      if (!_isVideo(_currentItem.attachment))
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 18),
              SizedBox(width: 12),
              Text('Copy image'),
            ],
          ),
        ),
      const PopupMenuItem(
        value: 'share',
        child: Row(
          children: [
            Icon(Icons.share_outlined, size: 18),
            SizedBox(width: 12),
            Text('Share'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'info',
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18),
            SizedBox(width: 12),
            Text('Media info'),
          ],
        ),
      ),
      if (widget.onDelete != null)
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
    ];
  }

  Future<void> _onMoreSelected(String value) async {
    switch (value) {
      case 'download':
        await _downloadCurrentMedia();
      case 'copy':
        await _copyCurrentImageToClipboard();
      case 'share':
        await _shareCurrentMedia();
      case 'info':
        _showMediaInfo();
      case 'delete':
        _runDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.items.length;
    const backdrop = Colors.white;
    const onBackdrop = Color(0xFF111B21);
    final isImage = !_isVideo(_currentItem.attachment);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (!widget.isViewOnce) _goPrevious();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!widget.isViewOnce) _goNext();
        },
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): () {
          if (!widget.isViewOnce && isImage) {
            unawaited(_copyCurrentImageToClipboard());
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: ExcludeSemantics(
          child: Scaffold(
            backgroundColor: backdrop,
            extendBodyBehindAppBar: false,
            appBar: AppBar(
              backgroundColor: backdrop,
              foregroundColor: onBackdrop,
              surfaceTintColor: backdrop,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              centerTitle: false,
              titleSpacing: 16,
              title: _buildSenderHeader(onBackdrop),
              actions: [
                if (_showControls && !widget.isViewOnce) ...[
                  if (isImage) ...[
                    IconButton(
                      icon: const Icon(Icons.zoom_out, color: onBackdrop),
                      tooltip: 'Zoom out',
                      onPressed: _currentZoom > 1.0 ? _zoomOut : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in, color: onBackdrop),
                      tooltip: 'Zoom in',
                      onPressed: _currentZoom < 4.0 ? _zoomIn : null,
                    ),
                  ],
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: onBackdrop,
                    ),
                    tooltip: 'Go to message',
                    onPressed: _goToMessage,
                  ),
                  if (widget.onReply != null)
                    IconButton(
                      icon: const Icon(Icons.reply, color: onBackdrop),
                      tooltip: 'Reply',
                      onPressed: _runReply,
                    ),
                  if (widget.onPin != null)
                    IconButton(
                      icon: const Icon(
                        Icons.push_pin_outlined,
                        color: onBackdrop,
                      ),
                      tooltip: 'Pin',
                      onPressed: _runPin,
                    ),
                  if (widget.onReact != null)
                    IconButton(
                      icon: const Icon(
                        Icons.add_reaction_outlined,
                        color: onBackdrop,
                      ),
                      tooltip: 'React',
                      onPressed: _showReactionPicker,
                    ),
                  if (widget.onForward != null)
                    IconButton(
                      icon: Transform.flip(
                        flipX: true,
                        child: const Icon(Icons.reply, color: onBackdrop),
                      ),
                      tooltip: 'Forward',
                      onPressed: _runForward,
                    ),
                  IconButton(
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onBackdrop,
                            ),
                          )
                        : const Icon(Icons.download, color: onBackdrop),
                    tooltip: 'Download',
                    onPressed:
                        _isDownloading ? null : _downloadCurrentMedia,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: onBackdrop),
                    tooltip: 'More options',
                    color: Colors.white,
                    offset: const Offset(0, 48),
                    onSelected: (value) => unawaited(_onMoreSelected(value)),
                    itemBuilder: (_) => _moreMenuItems(),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close, color: onBackdrop),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  physics: widget.isViewOnce
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    if (_isVideo(item.attachment)) {
                      return _buildPageBackdrop(
                        child: _buildVideoPlayer(index, item.attachment),
                      );
                    }
                    return _buildImageViewer(item.attachment);
                  },
                ),
                if (_showControls && totalCount > 1 && !widget.isViewOnce) ...[
                  if (_currentIndex > 0)
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 100,
                      child: Center(
                        child: _navChevron(
                          icon: Icons.chevron_left,
                          onPressed: _goPrevious,
                        ),
                      ),
                    ),
                  if (_currentIndex < totalCount - 1)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 100,
                      child: Center(
                        child: _navChevron(
                          icon: Icons.chevron_right,
                          onPressed: _goNext,
                        ),
                      ),
                    ),
                ],
                if (_showControls && totalCount > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 88,
                      padding: const EdgeInsets.only(bottom: 16, top: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Center(
                        child: SizedBox(
                          height: _thumbSize + 6,
                          child: ListView.builder(
                            controller: _thumbnailScrollController,
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: totalCount,
                            itemBuilder: (context, index) =>
                                _buildThumbnail(index),
                          ),
                        ),
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

  /// White backdrop; tap outside the media closes the viewer.
  Widget _buildPageBackdrop({required Widget child}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          behavior: HitTestBehavior.opaque,
          child: const ColoredBox(color: Colors.white),
        ),
        Center(child: child),
      ],
    );
  }

  Widget _buildImageViewer(MessageAttachment attachment) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          behavior: HitTestBehavior.opaque,
          child: const ColoredBox(color: Colors.white),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(48),
              onInteractionEnd: (_) {
                final scale = _transformationController.value.getMaxScaleOnAxis();
                if ((scale - _currentZoom).abs() > 0.01) {
                  setState(() => _currentZoom = scale.clamp(1.0, 4.0));
                }
              },
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: GestureDetector(
                  onTap: _toggleControls,
                  onSecondaryTapDown: (details) {
                    _showImageContextMenu(details.globalPosition);
                  },
                  child: CachedNetworkImage(
                    imageUrl: attachment.displayUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          color: Color(0xFF008069),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: SizedBox(
                        width: 240,
                        height: 160,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Color(0xFF667781),
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Color(0xFF667781)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    imageBuilder: (context, imageProvider) => Image(
                      image: imageProvider,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVideoPlayer(int index, MessageAttachment attachment) {
    return _VideoPlayerWidget(
      attachment: attachment,
      onControllerCreated: (controller) {
        _videoControllers[index] = controller;
      },
      isCurrentPage: index == _currentIndex,
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final MessageAttachment attachment;
  final Function(VideoPlayerController) onControllerCreated;
  final bool isCurrentPage;

  const _VideoPlayerWidget({
    required this.attachment,
    required this.onControllerCreated,
    required this.isCurrentPage,
  });

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(_VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage != oldWidget.isCurrentPage && !widget.isCurrentPage) {
      _controller?.pause();
      setState(() => _isPlaying = false);
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      // Avoid double-dispose races with async initialize().
      controller.dispose().catchError((_) {});
    }
    super.dispose();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeVideo() async {
    final url = widget.attachment.displayUrl;
    if (url.isEmpty) {
      setState(() => _error = 'No video source available');
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose().catchError((_) {});
        return;
      }
      controller.addListener(_onVideoTick);
      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
      widget.onControllerCreated(controller);
    } catch (e) {
      debugPrint('Video initialization error: $e');
      await controller.dispose().catchError((_) {});
      if (mounted) {
        setState(() => _error = 'Failed to load video');
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF667781), size: 48),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFF667781))),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF008069)),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          if (_controller!.value.isBuffering)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF008069)),
            ),
          if (!_isPlaying)
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF008069),
                bufferedColor: Color(0xFFB8C2C8),
                backgroundColor: Color(0xFFE9EDEF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
