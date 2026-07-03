import 'dart:io';

import 'package:flutter/material.dart';

import '../../../utils/clipboard_media_helper.dart';

/// Compact attachment chip shown above the composer (WhatsApp-style thumbnail).
class ChatAttachmentThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  final bool isDark;

  const ChatAttachmentThumb({
    super.key,
    required this.file,
    required this.onRemove,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final path = file.path.toLowerCase();
    final isAudio = path.endsWith('.mp3') ||
        path.endsWith('.wav') ||
        path.endsWith('.m4a') ||
        path.endsWith('.ogg') ||
        path.endsWith('.aac');
    final isImage = ClipboardMediaHelper.isImagePath(path);
    final isVideo = ClipboardMediaHelper.isVideoPath(path);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: isImage
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    width: 64,
                    height: 64,
                    errorBuilder: (_, __, ___) => _icon(Icons.broken_image_outlined),
                  )
                : isVideo
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: isDark
                                ? const Color(0xFF111B21)
                                : Colors.black12,
                          ),
                          Icon(
                            Icons.videocam,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ],
                      )
                    : _icon(
                        isAudio ? Icons.audiotrack : Icons.insert_drive_file,
                      ),
          ),
          if (isImage || isVideo)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isImage ? 'Photo' : 'Video',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(IconData icon) {
    return Icon(
      icon,
      color: isDark ? Colors.white70 : Colors.grey[600],
    );
  }
}
