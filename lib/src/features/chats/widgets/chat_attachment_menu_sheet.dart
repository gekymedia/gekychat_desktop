import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feature_flags.dart';

/// Callbacks for each attachment action in 1-1 or group chats.
class ChatAttachmentMenuCallbacks {
  final Future<void> Function() onGallery;
  final Future<void> Function() onCamera;
  final Future<void> Function() onDocument;
  final Future<void> Function() onAudio;
  final Future<void> Function() onLocation;
  final Future<void> Function() onContact;
  final Future<void> Function()? onPoll;
  final VoidCallback onBlackTask;
  final VoidCallback? onSika;

  const ChatAttachmentMenuCallbacks({
    required this.onGallery,
    required this.onCamera,
    required this.onDocument,
    required this.onAudio,
    required this.onLocation,
    required this.onContact,
    this.onPoll,
    required this.onBlackTask,
    this.onSika,
  });
}

class _AttachItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Compact attachment picker — small popup above the composer (desktop).
class ChatAttachmentMenuSheet extends ConsumerWidget {
  final ChatAttachmentMenuCallbacks callbacks;

  const ChatAttachmentMenuSheet({
    super.key,
    required this.callbacks,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    ChatAttachmentMenuCallbacks callbacks,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 76),
              child: Material(
                elevation: 8,
                shadowColor: Colors.black38,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: ChatAttachmentMenuSheet(callbacks: callbacks),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            alignment: Alignment.bottomLeft,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).dialogTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;

    void popThen(Future<void> Function() action) {
      Navigator.pop(context);
      action();
    }

    void popThenSync(VoidCallback action) {
      Navigator.pop(context);
      action();
    }

    final items = <_AttachItem>[
      _AttachItem(
        icon: Icons.photo_library_rounded,
        label: 'Gallery',
        color: const Color(0xFF9C27B0),
        onTap: () => popThen(callbacks.onGallery),
      ),
      _AttachItem(
        icon: Icons.photo_camera_rounded,
        label: 'Camera',
        color: const Color(0xFF2196F3),
        onTap: () => popThen(callbacks.onCamera),
      ),
      _AttachItem(
        icon: Icons.description_rounded,
        label: 'Document',
        color: const Color(0xFF1976D2),
        onTap: () => popThen(callbacks.onDocument),
      ),
      _AttachItem(
        icon: Icons.audiotrack_rounded,
        label: 'Audio',
        color: const Color(0xFF5C6BC0),
        onTap: () => popThen(callbacks.onAudio),
      ),
      _AttachItem(
        icon: Icons.location_on_rounded,
        label: 'Location',
        color: const Color(0xFF4CAF50),
        onTap: () => popThen(callbacks.onLocation),
      ),
      _AttachItem(
        icon: Icons.contact_phone_rounded,
        label: 'Contact',
        color: const Color(0xFFFF7043),
        onTap: () => popThen(callbacks.onContact),
      ),
    ];

    if (callbacks.onPoll != null) {
      items.add(
        _AttachItem(
          icon: Icons.poll_outlined,
          label: 'Poll',
          color: primary,
          onTap: () => popThen(callbacks.onPoll!),
        ),
      );
    }

    items.add(
      _AttachItem(
        icon: Icons.task_alt_rounded,
        label: 'BlackTask',
        color: const Color(0xFF2196F3),
        onTap: () => popThenSync(callbacks.onBlackTask),
      ),
    );

    final sikaHandler = callbacks.onSika;
    if (sikaHandler != null && featureEnabled(ref, 'sika_wallet')) {
      items.add(
        _AttachItem(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Sika',
          color: const Color(0xFFFFB300),
          onTap: () => popThenSync(sikaHandler),
        ),
      );
    }

    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.95,
        children: items.map((item) => _buildAttachGridItem(item, isDark)).toList(),
      ),
    );
  }

  Widget _buildAttachGridItem(_AttachItem item, bool isDark) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: isDark ? 0.22 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 21),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
