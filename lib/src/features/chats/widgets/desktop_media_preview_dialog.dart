import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/clipboard_media_helper.dart';
import 'video_preview_widget.dart';

/// Result from the desktop media preview dialog.
class DesktopMediaPreviewResult {
  final List<File> files;
  final List<String> captions;
  final bool sendAsAlbum;
  final String? sharedCaption;
  final bool isViewOnce;

  const DesktopMediaPreviewResult({
    required this.files,
    required this.captions,
    required this.sendAsAlbum,
    required this.sharedCaption,
    required this.isViewOnce,
  });
}

/// WhatsApp-style media preview with album / separate toggle (desktop dialog).
class DesktopMediaPreviewDialog extends StatefulWidget {
  final List<File> files;
  final String title;
  final bool initialSendAsAlbum;

  const DesktopMediaPreviewDialog({
    super.key,
    required this.files,
    required this.title,
    this.initialSendAsAlbum = true,
  });

  static Future<DesktopMediaPreviewResult?> show(
    BuildContext context, {
    required List<File> files,
    String? title,
  }) async {
    if (files.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final savedAlbumMode = prefs.getBool('media_send_as_album') ?? true;

    if (!context.mounted) return null;

    final resolvedTitle = title ?? _defaultTitle(files);

    return showDialog<DesktopMediaPreviewResult>(
      context: context,
      builder: (dialogContext) => DesktopMediaPreviewDialog(
        files: List<File>.from(files),
        title: resolvedTitle,
        initialSendAsAlbum: files.length > 1 ? savedAlbumMode : true,
      ),
    ).then((result) async {
      if (result != null) {
        await prefs.setBool('media_send_as_album', result.sendAsAlbum);
      }
      return result;
    });
  }

  static String _defaultTitle(List<File> files) {
    if (files.length == 1) {
      if (ClipboardMediaHelper.isImagePath(files.first.path)) {
        return 'Send photo';
      }
      if (ClipboardMediaHelper.isVideoPath(files.first.path)) {
        return 'Send video';
      }
    }
    if (files.every((f) => ClipboardMediaHelper.isImagePath(f.path))) {
      return 'Send photos';
    }
    return 'Send media';
  }

  @override
  State<DesktopMediaPreviewDialog> createState() =>
      _DesktopMediaPreviewDialogState();
}

class _DesktopMediaPreviewDialogState extends State<DesktopMediaPreviewDialog> {
  late List<File> _files;
  late PageController _pageController;
  late bool _sendAsAlbum;
  late bool _isViewOnce;
  int _currentIndex = 0;
  final TextEditingController _sharedCaptionController =
      TextEditingController();
  final List<TextEditingController> _captionControllers = [];

  @override
  void initState() {
    super.initState();
    _files = List<File>.from(widget.files);
    _pageController = PageController();
    _sendAsAlbum = widget.files.length <= 1 ? true : widget.initialSendAsAlbum;
    _isViewOnce = false;
    _captionControllers.addAll(
      _files.map((_) => TextEditingController()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sharedCaptionController.dispose();
    for (final c in _captionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _removeCurrent() {
    if (_files.length <= 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _captionControllers[_currentIndex].dispose();
      _captionControllers.removeAt(_currentIndex);
      _files.removeAt(_currentIndex);
      if (_currentIndex >= _files.length) {
        _currentIndex = _files.length - 1;
      }
      if (_files.length <= 1) {
        _sendAsAlbum = true;
      }
    });
  }

  void _send() {
    if (_files.isEmpty) return;
    Navigator.pop(
      context,
      DesktopMediaPreviewResult(
        files: List<File>.from(_files),
        captions: _captionControllers.map((c) => c.text.trim()).toList(),
        sendAsAlbum: _sendAsAlbum,
        sharedCaption: _sharedCaptionController.text.trim(),
        isViewOnce: _isViewOnce,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF202C33) : Colors.white;
    final onSurface = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? Colors.white60 : Colors.black54;
    final hasMultiple = _files.length > 1;

    return Dialog(
      backgroundColor: surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                  ),
                  if (hasMultiple)
                    Text(
                      '${_currentIndex + 1}/${_files.length}',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  IconButton(
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, color: muted, size: 20),
                    onPressed: _removeCurrent,
                  ),
                ],
              ),
              if (hasMultiple) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _modeChip(
                      icon: Icons.photo_library_outlined,
                      label: 'Album',
                      selected: _sendAsAlbum,
                      isDark: isDark,
                      onTap: () => setState(() => _sendAsAlbum = true),
                    ),
                    const SizedBox(width: 10),
                    _modeChip(
                      icon: Icons.view_stream_outlined,
                      label: 'Separate',
                      selected: !_sendAsAlbum,
                      isDark: isDark,
                      onTap: () => setState(() => _sendAsAlbum = false),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _sendAsAlbum
                        ? 'All ${_files.length} items sent in one message'
                        : 'Each item sent as its own message',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: isDark ? const Color(0xFF111B21) : Colors.grey.shade100,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemCount: _files.length,
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final path = file.path.toLowerCase();
                        final isImage = ClipboardMediaHelper.isImagePath(path);
                        final isVideo = ClipboardMediaHelper.isVideoPath(path);

                        Widget preview;
                        if (isImage) {
                          preview = Image.file(
                            file,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined, size: 40),
                            ),
                          );
                        } else if (isVideo) {
                          preview = VideoPreviewWidget(file: file);
                        } else {
                          preview = const Center(
                            child: Icon(Icons.insert_drive_file_outlined, size: 48),
                          );
                        }

                        return Center(child: preview);
                      },
                    ),
                  ),
                ),
              ),
              if (hasMultiple)
                SizedBox(
                  height: 52,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final selected = index == _currentIndex;
                      final isVideo = ClipboardMediaHelper.isVideoPath(file.path);
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.primaryGreen
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: isVideo
                                ? ColoredBox(
                                    color: Colors.grey.shade800,
                                    child: const Icon(
                                      Icons.videocam,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                  )
                                : Image.file(file, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _sendAsAlbum || !hasMultiple
                    ? _sharedCaptionController
                    : _captionControllers[_currentIndex],
                style: TextStyle(color: onSurface, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _sendAsAlbum || !hasMultiple
                      ? 'Add a caption…'
                      : 'Caption for item ${_currentIndex + 1}…',
                  hintStyle: TextStyle(color: muted, fontSize: 13),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2A3942)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('View once', style: TextStyle(color: onSurface)),
                subtitle: Text(
                  'Disappears after the recipient opens it once.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                value: _isViewOnce,
                onChanged: (v) => setState(() => _isViewOnce = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Send'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip({
    required IconData icon,
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? AppTheme.primaryGreen.withValues(alpha: isDark ? 0.35 : 0.18)
          : (isDark ? const Color(0xFF2A3942) : Colors.grey.shade200),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppTheme.primaryGreen : null,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppTheme.primaryGreen
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
