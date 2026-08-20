import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../utils/storage_url.dart';

/// Shown when an incoming call arrives while the user is already in another call.
class CallWaitingDialog extends StatelessWidget {
  final String callerName;
  final String? callerAvatar;
  final String callType;
  final VoidCallback onDecline;
  final VoidCallback onEndAndAnswer;

  const CallWaitingDialog({
    super.key,
    required this.callerName,
    this.callerAvatar,
    required this.callType,
    required this.onDecline,
    required this.onEndAndAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = callType == 'video';
    final avatarUrl = resolveAvatarUrl(callerAvatar);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.phone_callback, color: Color(0xFF00A884), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Incoming Call',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            child: avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildAvatarPlaceholder(isDark),
                      errorWidget: (_, __, ___) =>
                          _buildAvatarPlaceholder(isDark),
                    ),
                  )
                : _buildAvatarPlaceholder(isDark),
          ),
          const SizedBox(height: 16),
          Text(
            callerName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isVideo ? Icons.videocam : Icons.call,
                size: 18,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                isVideo ? 'Video call' : 'Voice call',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You have another call waiting',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDecline,
            icon: const Icon(Icons.call_end, color: Colors.red, size: 20),
            label: const Text(
              'Decline',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onEndAndAnswer,
            icon: const Icon(Icons.swap_calls, size: 20),
            label: const Text(
              'End & Answer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(bool isDark) {
    return Center(
      child: Text(
        callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }
}
