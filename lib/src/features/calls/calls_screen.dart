import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'call_repository.dart';
import 'models.dart';
import 'providers.dart';

final callLogsProvider = FutureProvider<List<CallLog>>((ref) async {
  final repo = ref.read(callRepositoryProvider);
  return await repo.getCallLogs();
});

class CallsScreen extends ConsumerWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final callLogsAsync = ref.watch(callLogsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Call Logs'),
      ),
      body: callLogsAsync.when(
        data: (callLogs) {
          if (callLogs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_disabled,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No call history',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group calls by date
          final groupedCalls = _groupCallsByDate(callLogs);

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: groupedCalls.keys.length,
            itemBuilder: (context, index) {
              final date = groupedCalls.keys.elementAt(index);
              final calls = groupedCalls[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      date,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...calls.map((call) => _CallLogItem(call: call, isDark: isDark)),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading call logs',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(callLogsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<CallLog>> _groupCallsByDate(List<CallLog> calls) {
    final grouped = <String, List<CallLog>>{};
    
    for (final call in calls) {
      final date = _formatDate(call.createdAt);
      grouped.putIfAbsent(date, () => []).add(call);
    }
    
    return grouped;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final callDate = DateTime(date.year, date.month, date.day);

    if (callDate == today) {
      return 'Today';
    } else if (callDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMMM d').format(date);
    }
  }
}

class _CallLogItem extends StatelessWidget {
  final CallLog call;
  final bool isDark;

  const _CallLogItem({
    required this.call,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (call.otherUser == null) {
      return const SizedBox.shrink();
    }

    final user = call.otherUser!;

    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: user.avatarUrl != null
            ? CachedNetworkImageProvider(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? Text(
                user.name[0].toUpperCase(),
                style: const TextStyle(fontSize: 20),
              )
            : null,
      ),
      title: Text(
        user.name,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(
            call.isOutgoing
                ? (call.isMissed ? Icons.call_missed_outgoing : Icons.call_made)
                : (call.isMissed ? Icons.call_missed : Icons.call_received),
            size: 16,
            color: call.isMissed
                ? Colors.red
                : (isDark ? Colors.white70 : Colors.grey[600]),
          ),
          const SizedBox(width: 4),
          Text(
            _formatSubtitle(),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(call.createdAt),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (call.duration != null && !call.isMissed) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  call.type == 'video' ? Icons.videocam : Icons.phone,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  call.formattedDuration,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatSubtitle() {
    if (call.isMissed) {
      return call.isOutgoing ? 'Missed outgoing call' : 'Missed call';
    } else if (call.isOutgoing) {
      return 'Outgoing call';
    } else {
      return 'Incoming call';
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }
}

