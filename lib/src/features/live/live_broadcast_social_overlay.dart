import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../realtime/pusher_service.dart';

/// Decode Laravel / Pusher JSON payloads (Map or JSON string).
Map<String, dynamic>? decodePusherPayload(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    try {
      final d = jsonDecode(raw);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
  }
  return null;
}

String senderDisplayName(dynamic sender) {
  if (sender is! Map) return 'Someone';
  final m = Map<String, dynamic>.from(sender);
  final name = m['name']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  final u = m['username']?.toString().trim();
  if (u != null && u.isNotEmpty) return '@$u';
  return 'Someone';
}

int? _pusherPayloadUserId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

/// Subscribe to `live-broadcast.{id}` public channel (Reverb / Pusher).
class LiveBroadcastRoomRealtime {
  LiveBroadcastRoomRealtime({
    required this.pusher,
    required this.broadcastId,
    required this.onGift,
    required this.onChat,
    required this.onLike,
    this.currentUserId,
    this.onViewerJoined,
    this.onBroadcastEnded,
  });

  final PusherService pusher;
  final int broadcastId;
  final void Function(String emoji, String senderName, String giftLabel) onGift;
  final void Function(String userName, String message) onChat;
  final void Function(String userName, int likesTotal) onLike;

  /// When set (viewer side), Pusher echoes for the same user are ignored — local UI already updated.
  final int? currentUserId;

  /// Host (and optionally viewers) see "X joined" + updated [viewers_count].
  final void Function(String viewerName, int? viewersCount)? onViewerJoined;

  /// Fired when the server broadcasts [LiveBroadcastEnded] for this room.
  final VoidCallback? onBroadcastEnded;

  String get _channel => 'public-live-broadcast.$broadcastId';

  void Function(dynamic)? _endedHandler;

  void attach() {
    unawaited(pusher.connect());
    pusher.listen(_channel, 'gift.sent', _rawGift);
    pusher.listen(_channel, 'chat.sent', _rawChat);
    pusher.listen(_channel, 'like.sent', _rawLike);
    pusher.listen(_channel, 'viewer.joined', _rawViewerJoined);
    if (onBroadcastEnded != null) {
      _endedHandler = _rawBroadcastEnded;
      pusher.listen('live-broadcasts', 'LiveBroadcastEnded', _endedHandler!);
    }
  }

  void _rawBroadcastEnded(dynamic raw) {
    if (onBroadcastEnded == null) return;
    final m = decodePusherPayload(raw);
    if (m == null) return;
    final id = int.tryParse(m['id']?.toString() ?? '');
    if (id != null && id == broadcastId) {
      onBroadcastEnded!();
    }
  }

  void _rawGift(dynamic raw) {
    final m = decodePusherPayload(raw);
    if (m == null) return;
    final sender = m['sender'];
    final sid = sender is Map ? _pusherPayloadUserId(sender['id']) : null;
    if (currentUserId != null && sid == currentUserId) return;
    final emoji = m['emoji']?.toString() ?? '🎁';
    final label = m['label']?.toString() ?? 'Gift';
    onGift(emoji, senderDisplayName(m['sender']), label);
  }

  void _rawChat(dynamic raw) {
    final m = decodePusherPayload(raw);
    if (m == null) return;
    final uid = _pusherPayloadUserId(m['user_id']);
    if (currentUserId != null && uid == currentUserId) return;
    final name = m['user_name']?.toString() ?? 'Someone';
    final msg = m['message']?.toString() ?? '';
    if (msg.isEmpty) return;
    onChat(name, msg);
  }

  void _rawLike(dynamic raw) {
    final m = decodePusherPayload(raw);
    if (m == null) return;
    final sender = m['sender'];
    final sid = sender is Map ? _pusherPayloadUserId(sender['id']) : null;
    if (currentUserId != null && sid == currentUserId) return;
    final total = int.tryParse(m['likes_count']?.toString() ?? '') ?? 0;
    onLike(senderDisplayName(m['sender']), total);
  }

  void _rawViewerJoined(dynamic raw) {
    if (onViewerJoined == null) return;
    final m = decodePusherPayload(raw);
    if (m == null) return;
    final viewer = m['viewer'];
    final vid = viewer is Map ? _pusherPayloadUserId(viewer['id']) : null;
    if (currentUserId != null && vid == currentUserId) return;
    final name = senderDisplayName(viewer);
    final vc = m['viewers_count'];
    final total = vc is int ? vc : int.tryParse('$vc');
    onViewerJoined!(name, total);
  }

  void detach() {
    if (_endedHandler != null) {
      pusher.removeListener('live-broadcasts', 'LiveBroadcastEnded', _endedHandler!);
      _endedHandler = null;
    }
    pusher.unsubscribe(_channel);
  }
}

/// Frosted pill used for LIVE headers and metrics (TikTok-style).
class LiveGlassCapsule extends StatelessWidget {
  const LiveGlassCapsule({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white12),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Full-screen dim + large countdown digit before going on air.
class LiveCountdownOverlay extends StatelessWidget {
  const LiveCountdownOverlay({super.key, required this.value});

  /// Shown digit (typically 3, 2, 1).
  final int value;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.82, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, t, child) {
            return Transform.scale(scale: t, child: child);
          },
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 112,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.96),
              height: 1,
              shadows: [
                Shadow(
                  blurRadius: 28,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown to the host right after the countdown while the app notifies followers.
class LiveFollowerNotifyBanner extends StatelessWidget {
  const LiveFollowerNotifyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return LiveGlassCapsule(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_outlined, color: Colors.white.withValues(alpha: 0.95), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "Notifying friends and followers you're LIVE…",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular glass icon button for the bottom host / viewer tool strip.
class LiveGlassIconButton extends StatelessWidget {
  const LiveGlassIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = 48,
    this.iconSize = 24,
    this.active = true,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final double size;
  final double iconSize;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.38),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: iconSize,
                color: active ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row in the TikTok-style left feed.
class BroadcastFeedEntry {
  BroadcastFeedEntry({
    required this.id,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.accent = const Color(0xFFFF4081),
    /// When set (viewer joined row), host can tap "Say hi" to send a quick greeting.
    this.sayHiViewerName,
  });

  final String id;
  final String emoji;
  final String title;
  final String? subtitle;
  final Color accent;
  final String? sayHiViewerName;
}

/// Left-stacked fading activity (gifts, chat, likes).
class BroadcastSocialFeed extends StatelessWidget {
  const BroadcastSocialFeed({
    super.key,
    required this.entries,
    this.maxWidth = 300,
    this.onSayHi,
  });

  final List<BroadcastFeedEntry> entries;
  final double maxWidth;

  /// Host only: called when "Say hi" is tapped on a viewer join row.
  final void Function(String viewerName)? onSayHi;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: SizedBox(
          width: maxWidth,
          child: ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries.take(8).map((e) {
                  final isChat = e.emoji == '💬';
                  final showSayHi =
                      onSayHi != null &&
                      e.sayHiViewerName != null &&
                      e.sayHiViewerName!.isNotEmpty;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) {
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset((1 - t) * 12, 0),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.emoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      maxLines: isChat ? 1 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isChat ? Colors.white70 : Colors.white,
                                        fontSize: isChat ? 11 : 13,
                                        fontWeight: isChat ? FontWeight.w600 : FontWeight.w600,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (e.subtitle != null && e.subtitle!.isNotEmpty)
                                      Text(
                                        e.subtitle!,
                                        maxLines: isChat ? 4 : 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isChat ? Colors.white : e.accent.withValues(alpha: 0.95),
                                          fontSize: isChat ? 14 : 11,
                                          fontWeight: FontWeight.w500,
                                          height: 1.25,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (showSayHi)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => onSayHi!(e.sayHiViewerName!),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('👋', style: TextStyle(fontSize: 13)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Say hi',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.95),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
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
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gift / combo floating up (full-screen overlay).
class GiftFloatAnimation {
  GiftFloatAnimation({
    required this.id,
    required this.emoji,
    required this.line1,
    required this.line2,
    required this.startX,
  });

  final int id;
  final String emoji;
  final String line1;
  final String line2;
  final double startX;
}

class GiftFloatAnimator extends StatefulWidget {
  const GiftFloatAnimator({
    super.key,
    required this.data,
    required this.onComplete,
  });

  final GiftFloatAnimation data;
  final VoidCallback onComplete;

  @override
  State<GiftFloatAnimator> createState() => _GiftFloatAnimatorState();
}

class _GiftFloatAnimatorState extends State<GiftFloatAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _y;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 2600), vsync: this);
    _y = Tween<double>(begin: 0.78, end: 0.12).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.55, 1, curve: Curves.easeIn)),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.45, end: 1.15), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0.85), weight: 60),
    ]).animate(_c);
    _c.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Positioned(
          left: sz.width * widget.data.startX - 72,
          top: sz.height * _y.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.data.emoji, style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data.line1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (widget.data.line2.isNotEmpty)
                          Text(
                            widget.data.line2,
                            style: TextStyle(
                              color: Colors.amber.shade200,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
