import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../widgets/desktop_typography.dart';
import 'live_broadcast_repository.dart';

final liveCreatorAnalyticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repo = ref.read(liveBroadcastRepositoryProvider);
  return repo.getCreatorAnalytics();
});

/// Creator dashboard for live broadcast analytics.
class LiveAnalyticsScreen extends ConsumerWidget {
  const LiveAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final analyticsAsync = ref.watch(liveCreatorAnalyticsProvider);

    return analyticsAsync.when(
      data: (data) {
        final totalBroadcasts = data['total_broadcasts'] as int? ?? 0;
        final totalViews = data['total_views'] as int? ?? 0;
        final totalMinutes = data['total_minutes'] as int? ?? 0;
        final recent = data['recent_broadcasts'] as List<dynamic>? ?? [];

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(liveCreatorAnalyticsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Your live stats',
                style: TextStyle(
                  fontFamily: DesktopTypography.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Broadcasts',
                      value: '$totalBroadcasts',
                      icon: Icons.live_tv,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Total views',
                      value: _formatCount(totalViews),
                      icon: Icons.visibility,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Watch time',
                      value: _formatDuration(totalMinutes),
                      icon: Icons.schedule,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Recent broadcasts',
                style: TextStyle(
                  fontFamily: DesktopTypography.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.live_tv_outlined,
                          size: 56,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No broadcasts yet',
                          style: TextStyle(
                            fontFamily: DesktopTypography.fontFamily,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Go live from the Live tab to see your analytics here.',
                          style: TextStyle(
                            fontFamily: DesktopTypography.fontFamily,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...recent.map<Widget>((e) {
                  final b = Map<String, dynamic>.from(e as Map);
                  return _RecentBroadcastTile(broadcast: b, isDark: isDark);
                }),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Could not load analytics',
                style: TextStyle(
                  fontFamily: DesktopTypography.fontFamily,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => ref.invalidate(liveCreatorAnalyticsProvider),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  static String _formatDuration(int totalMinutes) {
    if (totalMinutes < 60) return '${totalMinutes}m';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111B21) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3942) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.red.shade400),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: DesktopTypography.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: DesktopTypography.fontFamily,
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentBroadcastTile extends StatelessWidget {
  const _RecentBroadcastTile({
    required this.broadcast,
    required this.isDark,
  });

  final Map<String, dynamic> broadcast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final title = broadcast['title'] as String? ?? 'Untitled';
    final status = broadcast['status'] as String? ?? 'ended';
    final viewersCount = broadcast['viewers_count'] as int? ?? 0;
    final startedAt = broadcast['started_at'] as String?;
    final durationMinutes = broadcast['duration_minutes'] as int? ?? 0;

    String? dateStr;
    if (startedAt != null) {
      try {
        final dt = DateTime.parse(startedAt);
        dateStr = DateFormat('MMM d, y • HH:mm').format(dt);
      } catch (_) {
        dateStr = startedAt;
      }
    }

    String durationStr;
    if (durationMinutes >= 60) {
      durationStr = '${durationMinutes ~/ 60}h ${durationMinutes % 60}m';
    } else {
      durationStr = '${durationMinutes}m';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111B21) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3942) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: status == 'live' ? Colors.red : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: DesktopTypography.fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dateStr != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontFamily: DesktopTypography.fontFamily,
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$viewersCount views',
                style: TextStyle(
                  fontFamily: DesktopTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              if (durationMinutes > 0)
                Text(
                  durationStr,
                  style: TextStyle(
                    fontFamily: DesktopTypography.fontFamily,
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
