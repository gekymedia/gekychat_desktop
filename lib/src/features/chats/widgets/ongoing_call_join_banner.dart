import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calls/join_call_from_link.dart';
import '../../calls/joinable_call_message.dart';
import '../../calls/providers.dart';

/// WhatsApp-style strip: ongoing call join lives here (not on the call message bubble).
class OngoingCallJoinBanner extends StatelessWidget {
  final bool isVideo;
  final VoidCallback onJoin;

  const OngoingCallJoinBanner({
    super.key,
    required this.isVideo,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = isVideo ? 'Ongoing video call' : 'Ongoing voice call';

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: InkWell(
        onTap: onJoin,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.45),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isVideo ? Icons.videocam : Icons.call,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'Tap to join',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: onJoin,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VerifiedOngoingCallJoinBanner extends ConsumerStatefulWidget {
  final int sessionId;
  final String callLink;
  final Map<String, dynamic> callData;
  final bool isVideo;

  const VerifiedOngoingCallJoinBanner({
    super.key,
    required this.sessionId,
    required this.callLink,
    required this.callData,
    required this.isVideo,
  });

  @override
  ConsumerState<VerifiedOngoingCallJoinBanner> createState() =>
      _VerifiedOngoingCallJoinBannerState();
}

class _VerifiedOngoingCallJoinBannerState
    extends ConsumerState<VerifiedOngoingCallJoinBanner> {
  bool _loading = true;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _verify(widget.sessionId);
  }

  Future<void> _verify(int sessionId) async {
    try {
      final joinable = await ref.read(
        callSessionJoinableProvider(sessionId).future,
      );
      if (!mounted) return;
      if (!joinable) {
        try {
          rememberDismissedDeadCall(
            ProviderScope.containerOf(context),
            widget.callLink,
            widget.callData,
          );
        } catch (_) {}
      }
      setState(() {
        _show = joinable;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _show = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dismissedDeadCallKeysProvider);
    final container = ProviderScope.containerOf(context);
    if (ongoingCallBannerSuppressed(container, widget.callData)) {
      return const SizedBox.shrink();
    }
    if (_loading || !_show) {
      return const SizedBox.shrink();
    }
    return OngoingCallJoinBanner(
      isVideo: widget.isVideo,
      onJoin: () => joinCallFromChatLink(
        context,
        widget.callLink,
        Map<String, dynamic>.from(widget.callData),
      ),
    );
  }
}
