import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/colored_avatar.dart';
import 'models.dart';

/// Telegram-style chat-list birthday strip (below filter pills).
class BirthdayChatBanner extends StatelessWidget {
  const BirthdayChatBanner({
    super.key,
    required this.summary,
    required this.onTap,
    required this.onDismiss,
    required this.isDark,
  });

  final BirthdaySummary summary;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (!summary.showBanner || summary.bannerTitle.isEmpty) {
      return const SizedBox.shrink();
    }

    final bg = isDark ? const Color(0xFF1F2C34) : const Color(0xFFF5F6F6);
    final border = isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                _AvatarStack(
                  avatars: summary.previewAvatars,
                  celebrants: summary.today.take(3).toList(),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BannerTitle(title: summary.bannerTitle, isDark: isDark),
                      if (summary.bannerSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          summary.bannerSubtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : const Color(0xFF667781),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark ? Colors.white54 : const Color(0xFF8696A0),
                  ),
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerTitle extends StatelessWidget {
  const _BannerTitle({required this.title, required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final lower = title.toLowerCase();
    final idx = lower.indexOf('birthday');
    if (idx < 0) {
      return Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF111B21),
        ),
      );
    }
    final before = title.substring(0, idx);
    final match = title.substring(idx, idx + 'birthday'.length);
    final after = title.substring(idx + 'birthday'.length);
    final baseColor = isDark ? Colors.white : const Color(0xFF111B21);

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: baseColor),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({
    required this.avatars,
    required this.celebrants,
    required this.isDark,
  });

  final List<String> avatars;
  final List<BirthdayCelebrant> celebrants;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final items = celebrants.isNotEmpty
        ? celebrants
        : avatars
            .map((url) => BirthdayCelebrant(userId: 0, name: '', avatarUrl: url))
            .toList();

    if (items.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.cake_rounded, color: AppTheme.primaryGreen, size: 22),
      );
    }

    const size = 36.0;
    const overlap = 22.0;
    final width = size + (items.length.clamp(1, 3) - 1) * overlap;

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < items.length && i < 3; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                    width: 2,
                  ),
                ),
                child: _miniAvatar(items[i], size),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniAvatar(BirthdayCelebrant c, double size) {
    if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: c.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => ColoredAvatar(name: c.name, radius: size / 2),
        ),
      );
    }
    return ColoredAvatar(name: c.name.isNotEmpty ? c.name : '?', radius: size / 2);
  }
}
