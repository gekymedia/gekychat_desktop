import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'models.dart';

/// Left accent + body strip that is safe inside ListView / shrink-wrap Columns.
///
/// Do **not** use `BoxDecoration(borderRadius: …, border: Border(left: …))` —
/// Flutter asserts on non-uniform borders with radius and the chat subtree can
/// stop painting (blank bubbles while scroll still works).
class ReplyAccentStrip extends StatelessWidget {
  const ReplyAccentStrip({
    super.key,
    required this.accentColor,
    required this.backgroundColor,
    required this.child,
    this.trailing,
    this.accentWidth = 3,
    this.borderRadius,
  });

  final Color accentColor;
  final Color backgroundColor;
  final Widget child;
  final Widget? trailing;
  final double accentWidth;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final body = ColoredBox(
      color: backgroundColor,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: accentColor,
              child: SizedBox(width: accentWidth),
            ),
            Expanded(child: child),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
    final radius = borderRadius;
    if (radius == null) return body;
    return ClipRRect(borderRadius: radius, child: body);
  }
}

class ReplyQuoteThumbnail extends StatelessWidget {
  const ReplyQuoteThumbnail({
    super.key,
    this.localPath,
    this.networkUrl,
    this.size = 40,
    this.showPlayIcon = false,
  });

  final String? localPath;
  final String? networkUrl;
  final double size;
  final bool showPlayIcon;

  static bool _fileExists(String path) {
    try {
      return path.isNotEmpty && File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static ({String? localPath, String? networkUrl, bool isVideo, bool hasThumb})
  fromMessage(Message? message) {
    if (message == null || message.attachments.isEmpty) {
      return (
        localPath: null,
        networkUrl: null,
        isVideo: false,
        hasThumb: false,
      );
    }
    final a = message.attachments.first;
    final mime = a.mimeType.toLowerCase();
    final name = a.originalName?.toLowerCase() ?? '';
    final isImage = a.isImage ||
        mime.startsWith('image/') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif');

    if (isImage) {
      for (final u in [
        if (a.thumbnailUrl != null && a.thumbnailUrl!.isNotEmpty) a.thumbnailUrl!,
        if (a.compressedUrl != null && a.compressedUrl!.isNotEmpty)
          a.compressedUrl!,
        if (a.url.isNotEmpty) a.url,
      ]) {
        if (u.startsWith('http://') || u.startsWith('https://')) {
          return (
            localPath: null,
            networkUrl: u,
            isVideo: false,
            hasThumb: true,
          );
        }
        if (_fileExists(u)) {
          return (
            localPath: u,
            networkUrl: null,
            isVideo: false,
            hasThumb: true,
          );
        }
      }
    } else if (a.isVideo) {
      final u = a.thumbnailUrl;
      if (u != null && u.isNotEmpty) {
        if (u.startsWith('http://') || u.startsWith('https://')) {
          return (
            localPath: null,
            networkUrl: u,
            isVideo: true,
            hasThumb: true,
          );
        }
        if (_fileExists(u)) {
          return (
            localPath: u,
            networkUrl: null,
            isVideo: true,
            hasThumb: true,
          );
        }
      }
      return (
        localPath: null,
        networkUrl: null,
        isVideo: true,
        hasThumb: true,
      );
    }
    return (
      localPath: null,
      networkUrl: null,
      isVideo: false,
      hasThumb: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        showPlayIcon ? Icons.videocam_rounded : Icons.image_outlined,
        size: size * 0.45,
        color: scheme.onSurfaceVariant,
      ),
    );

    Widget image = placeholder;
    final local = localPath;
    if (local != null && local.isNotEmpty && _fileExists(local)) {
      image = Image.file(
        File(local),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        cacheHeight: (size * 3).round(),
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      final url = networkUrl;
      if (url != null && url.isNotEmpty) {
        image = CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: (size * 3).round(),
          memCacheHeight: (size * 3).round(),
          errorWidget: (_, __, ___) => placeholder,
          placeholder: (_, __) => placeholder,
        );
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (showPlayIcon)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
