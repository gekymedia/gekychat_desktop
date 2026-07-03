import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/global_navigator_key.dart';
import '../features/calls/call_duration_format.dart';
import '../core/providers.dart';
import '../features/calls/livekit_call_screen.dart';
import '../features/calls/providers.dart';
import '../services/livekit_call_service.dart';

/// Floating bubble for a minimized LiveKit call (desktop).
class LiveKitCallOverlay extends ConsumerStatefulWidget {
  const LiveKitCallOverlay({super.key});

  @override
  ConsumerState<LiveKitCallOverlay> createState() =>
      _LiveKitCallOverlayState();
}

class _LiveKitCallOverlayState extends ConsumerState<LiveKitCallOverlay> {
  Offset _position = const Offset(16, 72);
  bool _isDragging = false;

  String _formatDuration(Duration duration) => formatCallDurationHms(duration);

  void _maximizeCall(LiveKitCallService service) {
    final activeCall = service.activeCall;
    if (activeCall == null) return;

    final nav = rootNavigatorKey.currentState;
    if (nav == null || !nav.mounted) return;

    nav.push(
      MaterialPageRoute(
        builder: (context) => LiveKitCallScreen(
          existingRoom: activeCall.room,
          roomName: activeCall.roomName,
          callId: activeCall.callId ?? 0,
          peerName: activeCall.displayName,
          peerAvatar: activeCall.avatarUrl,
          videoEnabled: activeCall.isVideoEnabled,
          conversationId: activeCall.conversationId,
          groupId: activeCall.groupId,
          isRestoredFromOverlay: true,
        ),
      ),
    );
    service.maximizeCall();
  }

  void _openChat(LiveKitCallService service) {
    final activeCall = service.activeCall;
    if (activeCall == null || !activeCall.hasChat) return;

    service.minimizeCall();

    if (activeCall.conversationId != null) {
      ref
          .read(selectedConversationProvider.notifier)
          .selectConversation(activeCall.conversationId!);
    } else if (activeCall.groupId != null) {
      ref.read(pendingDesktopGroupSelectProvider.notifier).state =
          activeCall.groupId;
    }

    rootNavigatorKey.currentContext?.go('/chats');
  }

  Future<void> _endCall(LiveKitCallService service) async {
    final activeCall = service.activeCall;
    if (activeCall == null) return;

    final callId = activeCall.callId;
    final cm = ref.read(callManagerProvider);
    if (callId != null) {
      if (activeCall.groupId != null &&
          activeCall.room.remoteParticipants.isNotEmpty) {
        await cm.leaveCall(sessionIdOverride: callId);
      } else {
        await cm.endCall(sessionIdOverride: callId);
      }
    }
    await service.endCall();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(liveKitCallServiceProvider);
    final activeCall = service.activeCall;

    if (activeCall == null || !service.isMinimized) {
      return const SizedBox.shrink();
    }

    final isConnected = activeCall.isConnected;
    final participantCount = activeCall.participantCount;
    final bubbleColor =
        isConnected ? const Color(0xFF008069) : Colors.orange.shade700;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(0, 900),
              (_position.dy + details.delta.dy).clamp(0, 600),
            );
          });
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        child: Material(
          elevation: _isDragging ? 12 : 6,
          borderRadius: BorderRadius.circular(28),
          color: bubbleColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => _maximizeCall(service),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAvatar(activeCall),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              activeCall.displayName ?? 'Call',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            isConnected
                                ? '${_formatDuration(activeCall.callDuration)} • $participantCount'
                                : 'Connecting…',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (activeCall.hasChat) ...[
                  const SizedBox(width: 8),
                  _roundIconButton(
                    color: Colors.blue.shade700,
                    icon: Icons.message,
                    onTap: () => _openChat(service),
                  ),
                ],
                const SizedBox(width: 6),
                _roundIconButton(
                  color: Colors.red,
                  icon: Icons.call_end,
                  onTap: () => _endCall(service),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildAvatar(LiveKitCallInfo activeCall) {
    final url = activeCall.avatarUrl;
    if (url != null && url.isNotEmpty && url.startsWith('http')) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(url),
        backgroundColor: Colors.white24,
      );
    }
    final initial = (activeCall.displayName ?? 'C').characters.first.toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white24,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
