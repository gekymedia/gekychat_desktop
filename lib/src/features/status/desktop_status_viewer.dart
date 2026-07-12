import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/global_navigator_key.dart';
import 'models.dart';
import 'status_viewer_screen.dart';

/// WhatsApp / Telegram–style full-window status overlay for desktop.
Future<void> showDesktopStatusViewer(
  BuildContext context, {
  required StatusSummary statusSummary,
  int startIndex = 0,
  bool isOwnStatus = false,
  List<StatusSummary>? allSummaries,
  int? summaryIndex,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss status viewer',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final size = MediaQuery.sizeOf(dialogContext);
      final cardWidth = (size.width * 0.36).clamp(360.0, 500.0);
      final cardHeight = (size.height * 0.9).clamp(520.0, 920.0);
      final summaries = allSummaries ?? [statusSummary];
      final activeSummaryIndex = summaryIndex ??
          summaries.indexWhere((s) => s.userId == statusSummary.userId);

      StatusSummary? neighborAt(int offset) {
        final idx = activeSummaryIndex + offset;
        if (idx < 0 || idx >= summaries.length) return null;
        final summary = summaries[idx];
        if (summary.activeUpdates.isEmpty) return null;
        return summary;
      }

      final prevSummary = neighborAt(-1);
      final nextSummary = neighborAt(1);

      void openNeighbor(StatusSummary summary, int index) {
        Navigator.of(dialogContext).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx == null || !ctx.mounted) return;
          showDesktopStatusViewer(
            ctx,
            statusSummary: summary,
            allSummaries: summaries,
            summaryIndex: index,
            isOwnStatus: false,
          );
        });
      }

      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).pop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
            if (prevSummary != null)
              Positioned(
                left: 24,
                child: _StatusPeekCard(
                  summary: prevSummary,
                  onTap: () =>
                      openNeighbor(prevSummary, activeSummaryIndex - 1),
                ),
              ),
            if (nextSummary != null)
              Positioned(
                right: 24,
                child: _StatusPeekCard(
                  summary: nextSummary,
                  onTap: () =>
                      openNeighbor(nextSummary, activeSummaryIndex + 1),
                ),
              ),
            Material(
              color: Colors.transparent,
              elevation: 28,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: StatusViewerScreen(
                  statusSummary: statusSummary,
                  startIndex: startIndex,
                  isOwnStatus: isOwnStatus,
                  desktopOverlay: true,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _StatusPeekCard extends StatelessWidget {
  final StatusSummary summary;
  final VoidCallback onTap;

  const _StatusPeekCard({
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final update = summary.activeUpdates.first;
    final thumb = update.thumbnailUrl ??
        (update.type == StatusType.image ? update.mediaUrl : null);

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedOpacity(
          opacity: 0.72,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 72,
            height: 128,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb != null && thumb.isNotEmpty)
                  Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(update),
                  )
                else
                  _fallback(update),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Text(
                      summary.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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

  Widget _fallback(StatusUpdate update) {
    if (update.type == StatusType.text) {
      final bg = update.backgroundColor != null
          ? Color(int.parse(update.backgroundColor!.replaceFirst('#', '0xFF')))
          : const Color(0xFF00A884);
      return ColoredBox(
        color: bg,
        child: Center(
          child: Text(
            (update.text ?? '').length > 24
                ? '${(update.text ?? '').substring(0, 24)}…'
                : (update.text ?? ''),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return const ColoredBox(
      color: Color(0xFF1A1A2E),
      child: Icon(Icons.auto_stories_outlined, color: Colors.white54, size: 28),
    );
  }
}
