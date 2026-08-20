import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'providers.dart';
import 'call_navigation.dart';
import 'livekit_call_screen.dart';
import '../../core/feature_flags.dart';
import '../../core/session.dart';
import '../live/live_broadcast_repository.dart';
import '../live/broadcast_streaming_screen.dart';
import '../contacts/contact_display_service.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/storage_url.dart';

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
      body: Column(
        children: [
          // Live Broadcasts Section (if enabled and user has username)
          Consumer(
            builder: (context, ref, child) {
              final liveBroadcastEnabled = featureEnabled(ref, 'live_broadcast');
              final userProfileAsync = ref.watch(currentUserProvider);
              
              return userProfileAsync.when(
                data: (userProfile) {
                  if (!liveBroadcastEnabled || !userProfile.hasUsername) {
                    return const SizedBox.shrink();
                  }
                  return _LiveBroadcastsSection(isDark: isDark);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          // Call Logs Section
          Expanded(
            child: callLogsAsync.when(
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
          ),
        ],
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

class _CallLogItem extends ConsumerWidget {
  final CallLog call;
  final bool isDark;

  const _CallLogItem({
    required this.call,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = call.group;
    if (!call.isGroupCall && call.otherUser == null) {
      return const SizedBox.shrink();
    }

    final user = call.otherUser;
    final displayService = ref.read(contactDisplayServiceProvider);
    final displayName = group?.name ??
        displayService.resolve(
          userId: user?.id,
          phone: user?.phone,
          apiName: user?.name ?? 'Unknown',
        );
    final avatarUrl = resolveAvatarUrl(group?.avatarUrl ?? user?.avatarUrl);
    final formattedPhone = (user?.phone != null &&
            user!.phone!.isNotEmpty &&
            displayName != user.phone)
        ? PhoneFormatter.format(user.phone)
        : null;

    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: avatarUrl != null
            ? CachedNetworkImageProvider(avatarUrl)
            : null,
        child: avatarUrl == null
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 20),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (formattedPhone != null) ...[
            Text(
              formattedPhone,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
          ],
          Row(
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
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              call.type == 'video' ? Icons.videocam : Icons.phone,
              color: isDark ? Colors.green : Colors.green[700],
            ),
            onPressed: () => _initiateCallback(context, ref),
            tooltip: 'Call back',
          ),
          if (call.duration != null && !call.isMissed) ...[
            const SizedBox(width: 8),
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
          ] else ...[
            const SizedBox(width: 8),
            Text(
              _formatTime(call.createdAt),
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
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

  Future<void> _initiateCallback(BuildContext context, WidgetRef ref) async {
    if (!call.isGroupCall && call.otherUser == null) return;

    try {
      final callManager = ref.read(callManagerProvider);

      if (call.isGroupCall && call.groupId != null) {
        await callManager.startCall(
          groupId: call.groupId,
          type: call.type,
        );
        final callSession = callManager.currentCall;
        if (callSession != null && context.mounted) {
          final roomName = 'call_${callSession.id}';
          final tokenResult = await ref
              .read(liveKitTokenServiceProvider)
              .fetchToken(roomName: roomName, displayName: 'User');
          if (context.mounted) {
            await pushLiveKitCallScreenOnRoot(
              url: tokenResult.url,
              token: tokenResult.token,
              roomName: roomName,
              callId: callSession.id,
              videoEnabled: call.type == 'video',
              peerName: call.group?.name ?? 'Group call',
              peerAvatar: call.group?.avatarUrl,
              groupId: call.groupId,
              isOutgoingCall: true,
            );
          }
        }
        return;
      }

      final user = call.otherUser!;
      final displayService = ref.read(contactDisplayServiceProvider);
      final peerDisplayName = displayService.resolve(
        userId: user.id,
        phone: user.phone,
        apiName: user.name,
      );

      await callManager.startCall(
        calleeId: user.id,
        type: call.type,
      );

      final callSession = callManager.currentCall;
      if (callSession != null && context.mounted) {
        final roomName = 'call_${callSession.id}';
        final tokenResult = await ref
            .read(liveKitTokenServiceProvider)
            .fetchToken(roomName: roomName, displayName: 'User');
        if (context.mounted) {
          await pushLiveKitCallScreenOnRoot(
            url: tokenResult.url,
            token: tokenResult.token,
            roomName: roomName,
            callId: callSession.id,
            videoEnabled: call.type == 'video',
            peerName: peerDisplayName,
            peerAvatar: user.avatarUrl,
            isOutgoingCall: true,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
                context.showErrorToast('Failed to start call: $e');      }
    }
  }
}

/// PHASE 2: Live Broadcasts Section
class _LiveBroadcastsSection extends ConsumerWidget {
  final bool isDark;

  const _LiveBroadcastsSection({required this.isDark});

  Future<void> _startBroadcast(BuildContext context, WidgetRef ref) async {
    try {
      // Get current user to generate default title
      final userProfileAsync = ref.read(currentUserProvider);
      final userProfile = userProfileAsync.requireValue;
      
      // Generate default title: "{username} is live" or "user_{id} is live"
      final username = userProfile.username ?? "user_${userProfile.id}";
      final defaultTitle = "$username is live";
      
      final repo = ref.read(liveBroadcastRepositoryProvider);
      final result = await repo.startBroadcast(title: defaultTitle);
      
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
    } catch (e) {
      if (context.mounted) {
                context.showErrorToast('Failed to start broadcast: $e');      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.live_tv, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Live Broadcasts',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Empty state for live broadcasts
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.videocam_off_outlined,
                    size: 48,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No active broadcasts',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _startBroadcast(context, ref);
                    },
                    icon: const Icon(Icons.live_tv),
                    label: const Text('Go Live'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

