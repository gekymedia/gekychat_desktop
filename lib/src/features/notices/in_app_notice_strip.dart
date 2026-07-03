import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'in_app_notice.dart';

/// Horizontal-friendly stacked banners above the chat filter chips.
class InAppNoticeStrip extends StatefulWidget {
  final List<InAppNotice> notices;
  final void Function(String noticeKey) onDismiss;

  const InAppNoticeStrip({
    super.key,
    required this.notices,
    required this.onDismiss,
  });

  @override
  State<InAppNoticeStrip> createState() => _InAppNoticeStripState();
}

class _InAppNoticeStripState extends State<InAppNoticeStrip> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color _bg(BuildContext context, String style) {
    final scheme = Theme.of(context).colorScheme;
    switch (style) {
      case 'warning':
        return scheme.secondaryContainer.withValues(alpha: 0.85);
      case 'promo':
        return scheme.tertiaryContainer.withValues(alpha: 0.9);
      default:
        return scheme.primaryContainer.withValues(alpha: 0.55);
    }
  }

  Color _border(BuildContext context, String style) {
    final scheme = Theme.of(context).colorScheme;
    switch (style) {
      case 'warning':
        return scheme.secondary.withValues(alpha: 0.45);
      case 'promo':
        return scheme.tertiary.withValues(alpha: 0.45);
      default:
        return scheme.primary.withValues(alpha: 0.35);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notices.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notices = widget.notices;

    Widget buildCard(InAppNotice n) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Material(
          color: _bg(context, n.style),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border(context, n.style)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (n.title != null && n.title!.trim().isNotEmpty)
                          Text(
                            n.title!,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                          ),
                        Text(
                          n.body,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.25,
                              ),
                        ),
                        if (n.actionUrl != null &&
                            n.actionUrl!.isNotEmpty &&
                            n.actionLabel != null &&
                            n.actionLabel!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: () async {
                                final uri = Uri.tryParse(n.actionUrl!);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(n.actionLabel!),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Dismiss',
                    onPressed: () => widget.onDismiss(n.noticeKey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (notices.length == 1) {
      return buildCard(notices.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: _pageController,
            itemCount: notices.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => buildCard(notices[i]),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(notices.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 14 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}
