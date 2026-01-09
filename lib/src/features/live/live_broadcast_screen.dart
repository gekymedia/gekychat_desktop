import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'live_broadcast_repository.dart';
import 'broadcast_viewer_screen.dart';
import 'broadcast_streaming_screen.dart';

final liveBroadcastsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(liveBroadcastRepositoryProvider);
  return await repo.getActiveBroadcasts();
});

class LiveBroadcastScreen extends ConsumerWidget {
  const LiveBroadcastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final broadcastsAsync = ref.watch(liveBroadcastsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.live_tv, color: Colors.red, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Live Broadcasts',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start or join live broadcasts',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showStartBroadcastDialog(context, ref),
                  icon: const Icon(Icons.videocam, size: 20),
                  label: const Text('Go Live'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          // Broadcasts List
          Expanded(
            child: broadcastsAsync.when(
              data: (broadcasts) {
                if (broadcasts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.live_tv_outlined,
                          size: 64,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active broadcasts',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to go live!',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(liveBroadcastsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: broadcasts.length,
                    itemBuilder: (context, index) {
                      final broadcast = broadcasts[index];
                      return _BroadcastCard(
                        broadcast: broadcast,
                        isDark: isDark,
                        onJoin: () => _joinBroadcast(context, ref, broadcast['id'] as int),
                      );
                    },
                  ),
                );
              },
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading broadcasts...',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading broadcasts',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey[500],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(liveBroadcastsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStartBroadcastDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          'Start Live Broadcast',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: 'Broadcast Title',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF2A3942) : Colors.grey.shade300,
              ),
            ),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a title')),
                );
                return;
              }

              Navigator.pop(context);
              await _startBroadcast(context, ref, titleController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go Live'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBroadcast(BuildContext context, WidgetRef ref, String title) async {
    try {
      final repo = ref.read(liveBroadcastRepositoryProvider);
      final result = await repo.startBroadcast(title: title);
      
      // Navigate to broadcast streaming screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BroadcastStreamingScreen(
              broadcastId: result['broadcast_id'] as int? ?? 0,
              startData: result,
            ),
          ),
        );
      }
      
      // Refresh the list in background
      ref.invalidate(liveBroadcastsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start broadcast: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _joinBroadcast(BuildContext context, WidgetRef ref, int broadcastId) async {
    try {
      final repo = ref.read(liveBroadcastRepositoryProvider);
      final result = await repo.joinBroadcast(broadcastId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joining broadcast...'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate to broadcast viewer screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BroadcastViewerScreen(
              broadcastId: broadcastId,
              joinData: result,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join broadcast: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _BroadcastCard extends StatelessWidget {
  final Map<String, dynamic> broadcast;
  final bool isDark;
  final VoidCallback onJoin;

  const _BroadcastCard({
    required this.broadcast,
    required this.isDark,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final title = broadcast['title'] as String? ?? 'Untitled Broadcast';
    final viewersCount = broadcast['viewers_count'] as int? ?? 0;
    final broadcaster = broadcast['broadcaster'] as Map<String, dynamic>?;
    final creatorName = broadcaster?['name'] as String? ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111B21) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3942) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Live indicator
            Container(
              width: 12,
              height: 12,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        creatorName,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$viewersCount viewers',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Join button
            ElevatedButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Watch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

