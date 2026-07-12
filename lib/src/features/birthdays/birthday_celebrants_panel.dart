import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/colored_avatar.dart';
import '../../widgets/desktop_center_modal.dart';
import 'birthday_gift_actions.dart';
import 'models.dart';

Future<void> showBirthdayCelebrantsDesktop(
  BuildContext context, {
  required BirthdaySummary summary,
  required Future<void> Function(BirthdayCelebrant celebrant) onSendWish,
  required Future<void> Function(BirthdayCelebrant celebrant) onSendSticker,
  VoidCallback? onAddBirthday,
}) {
  return showDesktopCenterModal<void>(
    context: context,
    title: 'Birthdays',
    maxWidth: 420,
    maxHeightFraction: 0.82,
    child: BirthdayCelebrantsPanel(
      summary: summary,
      onSendWish: onSendWish,
      onSendSticker: onSendSticker,
      onAddBirthday: onAddBirthday,
      dense: false,
    ),
  );
}

/// Telegram "Send a Gift"–style celebrant list (modal / bottom sheet body).
class BirthdayCelebrantsPanel extends StatelessWidget {
  const BirthdayCelebrantsPanel({
    super.key,
    required this.summary,
    required this.onSendWish,
    required this.onSendSticker,
    this.onAddBirthday,
    this.dense = false,
  });

  final BirthdaySummary summary;
  final Future<void> Function(BirthdayCelebrant celebrant) onSendWish;
  final Future<void> Function(BirthdayCelebrant celebrant) onSendSticker;
  final VoidCallback? onAddBirthday;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!summary.hasBirthdaySet && onAddBirthday != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextButton.icon(
              onPressed: onAddBirthday,
              icon: const Icon(Icons.cake_outlined, size: 20),
              label: const Text('Add your birthday'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: dense ? 8 : 16),
            children: [
              if (summary.today.isNotEmpty) ...[
                _sectionHeader(context, 'BIRTHDAY TODAY'),
                ...summary.today.map((c) => _CelebrantTile(
                      celebrant: c,
                      isDark: isDark,
                      onSendWish: () => onSendWish(c),
                      onSendSticker: () => onSendSticker(c),
                    )),
              ],
              if (summary.yesterday.isNotEmpty) ...[
                _sectionHeader(context, 'BIRTHDAY YESTERDAY'),
                ...summary.yesterday.map((c) => _CelebrantTile(
                      celebrant: c,
                      isDark: isDark,
                      onSendWish: () => onSendWish(c),
                      onSendSticker: () => onSendSticker(c),
                    )),
              ],
              if (summary.selfToday != null) ...[
                _sectionHeader(context, 'THIS IS YOU'),
                _CelebrantTile(
                  celebrant: summary.selfToday!,
                  isDark: isDark,
                  subtitleOverride: 'Treat yourself today',
                  onSendWish: () => onSendWish(summary.selfToday!),
                  onSendSticker: () {},
                  selfMode: true,
                ),
              ],
              if (summary.today.isEmpty &&
                  summary.yesterday.isEmpty &&
                  summary.selfToday == null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No birthdays to show right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF667781),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: isDark ? const Color(0xFF8696A0) : const Color(0xFF008069),
        ),
      ),
    );
  }
}

class _CelebrantTile extends StatelessWidget {
  const _CelebrantTile({
    required this.celebrant,
    required this.isDark,
    required this.onSendWish,
    required this.onSendSticker,
    this.subtitleOverride,
    this.selfMode = false,
  });

  final BirthdayCelebrant celebrant;
  final bool isDark;
  final VoidCallback onSendWish;
  final VoidCallback onSendSticker;
  final String? subtitleOverride;
  final bool selfMode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: selfMode
            ? () => showBirthdayGiftSheet(context, celebrant)
            : onSendWish,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ColoredAvatar(
                imageUrl: celebrant.avatarUrl,
                name: celebrant.name,
                radius: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      celebrant.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111B21),
                      ),
                    ),
                    if ((subtitleOverride ?? celebrant.lastSeenLabel)?.isNotEmpty ==
                        true)
                      Text(
                        subtitleOverride ?? celebrant.lastSeenLabel!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : const Color(0xFF667781),
                        ),
                      ),
                  ],
                ),
              ),
              if (!selfMode) ...[
                _actionIcon(
                  context,
                  icon: Icons.emoji_emotions_outlined,
                  color: isDark ? Colors.white38 : const Color(0xFF8696A0),
                  tooltip: 'Send sticker',
                  onPressed: onSendSticker,
                ),
                _actionIcon(
                  context,
                  icon: Icons.card_giftcard_rounded,
                  color: const Color(0xFFE91E8C),
                  tooltip: 'Send gift',
                  onPressed: () => showBirthdayGiftSheet(context, celebrant),
                ),
                _actionIcon(
                  context,
                  icon: Icons.chat_bubble_outline_rounded,
                  color: AppTheme.primaryGreen,
                  tooltip: 'Send wish',
                  onPressed: onSendWish,
                ),
              ] else
                _actionIcon(
                  context,
                  icon: Icons.card_giftcard_rounded,
                  color: const Color(0xFFE91E8C),
                  tooltip: 'Send gift',
                  onPressed: () => showBirthdayGiftSheet(context, celebrant),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIcon(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      ),
    );
  }
}

Future<void> showBirthdayCelebrantsMobileSheet(
  BuildContext context, {
  required BirthdaySummary summary,
  required Future<void> Function(BirthdayCelebrant celebrant) onSendWish,
  required Future<void> Function(BirthdayCelebrant celebrant) onSendSticker,
  VoidCallback? onAddBirthday,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final height = MediaQuery.sizeOf(ctx).height * 0.88;
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111B21) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const Expanded(
                    child: Text(
                      'Birthdays',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: BirthdayCelebrantsPanel(
                summary: summary,
                onSendWish: onSendWish,
                onSendSticker: onSendSticker,
                onAddBirthday: onAddBirthday,
                dense: true,
              ),
            ),
          ],
        ),
      );
    },
  );
}
