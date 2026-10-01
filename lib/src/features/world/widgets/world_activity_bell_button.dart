import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../world_activity_screen.dart';
import '../world_feed_repository.dart';

/// Activity bell with unread badge (World feed header + Profile tab).
class WorldActivityBellButton extends ConsumerWidget {
  final Color iconColor;
  final double iconSize;

  const WorldActivityBellButton({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize = 22,
  });

  void _openActivity(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WorldActivityScreen()),
    ).then((_) {
      ref.invalidate(worldFeedActivityUnreadCountProvider);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(worldFeedActivityUnreadCountProvider);
    return unreadAsync.when(
      data: (count) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: iconColor, size: iconSize),
            tooltip: 'Activity',
            onPressed: () => _openActivity(context, ref),
          ),
          if (count > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      loading: () => IconButton(
        icon: Icon(Icons.notifications_none, color: iconColor, size: iconSize),
        tooltip: 'Activity',
        onPressed: () => _openActivity(context, ref),
      ),
      error: (_, __) => IconButton(
        icon: Icon(Icons.notifications_none, color: iconColor, size: iconSize),
        tooltip: 'Activity',
        onPressed: () => _openActivity(context, ref),
      ),
    );
  }
}
