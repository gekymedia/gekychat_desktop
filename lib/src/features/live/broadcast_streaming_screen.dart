import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../calls/livekit_quality.dart';
import 'live_broadcast_repository.dart';
import 'live_broadcast_screen.dart' show liveBroadcastsProvider;
import 'live_broadcast_social_overlay.dart';
import 'live_broadcast_host_tools_sheet.dart';
import '../../utils/snackbar_helper.dart';

/// PHASE 2: Broadcast Streaming Screen for Desktop
/// Allows broadcaster to stream their video with realtime social overlay.
class BroadcastStreamingScreen extends ConsumerStatefulWidget {
  final int broadcastId;
  final Map<String, dynamic> startData; // Contains token, room_name, websocket_url

  const BroadcastStreamingScreen({
    super.key,
    required this.broadcastId,
    required this.startData,
  });

  @override
  ConsumerState<BroadcastStreamingScreen> createState() => _BroadcastStreamingScreenState();
}

class _BroadcastStreamingScreenState extends ConsumerState<BroadcastStreamingScreen> {
  Room? _room;
  bool _isStreaming = false;
  bool _isConnecting = true;
  String? _errorMessage;
  bool _cameraEnabled = true;
  bool _microphoneEnabled = true;

  LiveBroadcastRoomRealtime? _rtmRoom;
  int _likesCount = 0;
  int _viewerCount = 0;
  final List<BroadcastFeedEntry> _feedEntries = [];
  final List<GiftFloatAnimation> _giftFloats = [];
  int _giftFloatId = 0;

  Timer? _countdownTimer;
  Timer? _followerNotifyTimer;
  Timer? _statsPollTimer;
  int? _countdownSeconds;
  bool _showFollowerNotify = false;
  bool _isRecording = false;
  String? _ingressRtmpUrl;
  String? _ingressStreamKey;
  String? _ingressWhipUrl;

  @override
  void initState() {
    super.initState();
    _likesCount = int.tryParse(widget.startData['likes_count']?.toString() ?? '') ?? 0;
    _viewerCount = int.tryParse(widget.startData['viewers_count']?.toString() ?? '') ?? 0;
    _isRecording = widget.startData['recording'] == true ||
        widget.startData['recording']?.toString() == 'true';
    _connectAndStartStreaming();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _followerNotifyTimer?.cancel();
    _statsPollTimer?.cancel();
    _rtmRoom?.detach();
    _room?.disconnect();
    super.dispose();
  }

  void _attachRealtime() {
    _rtmRoom?.detach();
    final me = ref.read(currentUserProvider).valueOrNull?.id;
    _rtmRoom = LiveBroadcastRoomRealtime(
      pusher: ref.read(pusherServiceProvider),
      broadcastId: widget.broadcastId,
      currentUserId: me,
      onGift: (emoji, sender, label) {
        if (!mounted) return;
        _triggerGiftFloat(emoji, sender, label);
        _pushFeed(BroadcastFeedEntry(
          id: 'g_${DateTime.now().microsecondsSinceEpoch}',
          emoji: emoji,
          title: '$sender sent $label',
          subtitle: 'Gift',
          accent: const Color(0xFFFFB300),
        ));
      },
      onChat: (userName, message) {
        if (!mounted) return;
        _pushFeed(BroadcastFeedEntry(
          id: 'c_${DateTime.now().microsecondsSinceEpoch}',
          emoji: '💬',
          title: userName,
          subtitle: message,
          accent: const Color(0xFF64B5F6),
        ));
      },
      onLike: (userName, total) {
        if (!mounted) return;
        setState(() => _likesCount = total);
        _pushFeed(BroadcastFeedEntry(
          id: 'l_${DateTime.now().microsecondsSinceEpoch}',
          emoji: '❤️',
          title: '$userName tapped',
          subtitle: '$total likes on stream',
          accent: const Color(0xFFFF4081),
        ));
      },
      onViewerJoined: (viewerName, viewersCount) {
        if (!mounted) return;
        if (viewersCount != null) {
          setState(() => _viewerCount = viewersCount);
        }
        if (_showFollowerNotify) {
          setState(() => _showFollowerNotify = false);
        }
        _pushFeed(BroadcastFeedEntry(
          id: 'vj_${DateTime.now().microsecondsSinceEpoch}',
          emoji: '👋',
          title: viewerName,
          subtitle: 'joined',
          accent: const Color(0xFF81C784),
          sayHiViewerName: viewerName,
        ));
      },
    );
    _rtmRoom!.attach();
    _startStatsPolling();
  }

  void _startStatsPolling() {
    _statsPollTimer?.cancel();
    _statsPollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!mounted || !_isStreaming) return;
      try {
        final repo = ref.read(liveBroadcastRepositoryProvider);
        final stats = await repo.getBroadcastStats(widget.broadcastId);
        if (!mounted || stats.isEmpty) return;
        final likes = int.tryParse(stats['likes_count']?.toString() ?? '');
        final viewers = int.tryParse(stats['viewers_count']?.toString() ?? '');
        if (likes == null && viewers == null) return;
        final nextLikes = likes ?? _likesCount;
        final nextViewers = viewers ?? _viewerCount;
        if (nextLikes != _likesCount || nextViewers != _viewerCount) {
          setState(() {
            _likesCount = nextLikes;
            _viewerCount = nextViewers;
          });
        }
      } catch (_) {
        // Realtime remains primary path; polling is best-effort fallback.
      }
    });
  }

  void _pushFeed(BroadcastFeedEntry e) {
    if (!mounted) return;
    setState(() {
      _feedEntries.insert(0, e);
      if (_feedEntries.length > 12) {
        _feedEntries.removeRange(12, _feedEntries.length);
      }
    });
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _feedEntries.removeWhere((x) => x.id == e.id);
      });
    });
  }

  void _triggerGiftFloat(String emoji, String senderName, String giftLabel) {
    final random = Random();
    if (!mounted) return;
    setState(() {
      _giftFloats.add(GiftFloatAnimation(
        id: _giftFloatId++,
        emoji: emoji,
        line1: senderName,
        line2: 'sent $giftLabel',
        startX: random.nextDouble() * 0.55 + 0.18,
      ));
    });
  }

  Future<void> _connectAndStartStreaming() async {
    try {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
      });

      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted) {
        throw Exception('Camera permission is required to start broadcasting');
      }

      if (!micStatus.isGranted) {
        throw Exception('Microphone permission is required to start broadcasting');
      }

      final roomName = widget.startData['room_name'] as String? ?? '';
      final token = widget.startData['token'] as String? ?? '';
      final websocketUrl = widget.startData['websocket_url'] as String? ?? '';

      if (token.isEmpty || roomName.isEmpty) {
        throw Exception('Missing token or room name');
      }

      final room = Room(roomOptions: LiveKitQuality.broadcastHostRoomOptions());

      await room.connect(
        websocketUrl,
        token,
      );

      await room.localParticipant?.setCameraEnabled(_cameraEnabled);
      await room.localParticipant?.setMicrophoneEnabled(_microphoneEnabled);

      setState(() {
        _room = room;
        _isConnecting = false;
        _isStreaming = false;
        _countdownSeconds = 3;
      });
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          final next = (_countdownSeconds ?? 1) - 1;
          if (next <= 0) {
            timer.cancel();
            _countdownSeconds = null;
            _isStreaming = true;
            _showFollowerNotify = true;
            _attachRealtime();
            _followerNotifyTimer?.cancel();
            _followerNotifyTimer = Timer(const Duration(seconds: 14), () {
              if (mounted) setState(() => _showFollowerNotify = false);
            });
          } else {
            _countdownSeconds = next;
          }
        });
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start streaming: $e';
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_room == null) return;

    try {
      _cameraEnabled = !_cameraEnabled;
      await _room!.localParticipant?.setCameraEnabled(_cameraEnabled);
      setState(() {});
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to toggle camera: $e');      }
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_room == null) return;

    try {
      _microphoneEnabled = !_microphoneEnabled;
      await _room!.localParticipant?.setMicrophoneEnabled(_microphoneEnabled);
      setState(() {});
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to toggle microphone: $e');      }
    }
  }

  Future<void> _endBroadcast() async {
    _statsPollTimer?.cancel();
    _statsPollTimer = null;
    _rtmRoom?.detach();
    _rtmRoom = null;
    if (_room != null) {
      await _room!.disconnect();
    }

    try {
      final repo = ref.read(liveBroadcastRepositoryProvider);
      await repo.endBroadcast(widget.broadcastId);
    } catch (e) {
      debugPrint('Failed to end broadcast: $e');
    }

    ref.invalidate(liveBroadcastsProvider);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool?> _confirmEndLive() async {
    final inSession = _room != null && (_countdownSeconds != null || _isStreaming);
    if (!inSession) return true;
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        title: const Text('End LIVE?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Your viewers are watching. End the stream now?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.88), height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End now', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _onEndPressed() async {
    if (await _confirmEndLive() == true) {
      await _endBroadcast();
    }
  }

  String _liveWatchUrl() => 'https://chat.gekychat.com/live/${widget.broadcastId}';

  Future<void> _shareLiveLink() async {
    final url = _liveWatchUrl();
    final text = 'Watch my LIVE on GekyChat\n$url';
    await Share.share(text, subject: 'Live on GekyChat');
  }

  Future<void> _openHostTools() async {
    final repo = ref.read(liveBroadcastRepositoryProvider);
    await showLiveBroadcastHostToolsSheet(
      context: context,
      repository: repo,
      broadcastId: widget.broadcastId,
      isRecording: _isRecording,
      onRecordingChanged: (v) {
        if (mounted) setState(() => _isRecording = v);
      },
      rtmpUrl: _ingressRtmpUrl,
      streamKey: _ingressStreamKey,
      whipUrl: _ingressWhipUrl,
      onIngressUpdated: ({rtmpUrl, streamKey, whipUrl}) {
        if (!mounted) return;
        setState(() {
          _ingressRtmpUrl = rtmpUrl ?? _ingressRtmpUrl;
          _ingressStreamKey = streamKey ?? _ingressStreamKey;
          _ingressWhipUrl = whipUrl ?? _ingressWhipUrl;
        });
      },
    );
  }

  Future<void> _onSayHi(String viewerName) async {
    final name = viewerName.trim();
    if (name.isEmpty) return;
    final msg = 'Hi $name! 👋';
    try {
      final repo = ref.read(liveBroadcastRepositoryProvider);
      await repo.sendChatMessage(widget.broadcastId, message: msg);
      if (!mounted) return;
      final me = ref.read(currentUserProvider).valueOrNull;
      final who = me != null && me.name.trim().isNotEmpty
          ? me.name
          : (me?.username != null ? '@${me!.username}' : 'You');
      _pushFeed(BroadcastFeedEntry(
        id: 'me_hi_${DateTime.now().microsecondsSinceEpoch}',
        emoji: '💬',
        title: who,
        subtitle: msg,
        accent: const Color(0xFF64B5F6),
      ));
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Could not send: $e');      }
    }
  }

  String _shortName(String raw) {
    final t = raw.trim();
    if (t.length <= 10) return t;
    return '${t.substring(0, 9)}…';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final displayName = _shortName(
      user != null && user.name.trim().isNotEmpty
          ? user.name
          : (user?.username != null ? '@${user!.username}' : 'Live'),
    );
    final avatarUrl = user?.avatarUrl;

    final inLiveSession = _room != null && (_countdownSeconds != null || _isStreaming);

    return PopScope(
      canPop: !inLiveSession,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onEndPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_isConnecting)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Starting broadcast…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _connectAndStartStreaming,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_room != null && _cameraEnabled)
              _LocalVideoPreview(room: _room!)
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Camera is off',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

            if (_room != null && !_isConnecting && _errorMessage == null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.42),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        stops: const [0, 0.2, 0.62, 1],
                      ),
                    ),
                  ),
                ),
              ),

            if (_countdownSeconds != null && _countdownSeconds! > 0)
              Positioned.fill(
                child: LiveCountdownOverlay(value: _countdownSeconds!),
              ),

            ..._giftFloats.map(
              (anim) => GiftFloatAnimator(
                key: ValueKey(anim.id),
                data: anim,
                onComplete: () {
                  setState(() {
                    _giftFloats.removeWhere((a) => a.id == anim.id);
                  });
                },
              ),
            ),

            if (_isStreaming)
              Positioned(
                left: 0,
                right: 0,
                bottom: 112,
                top: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showFollowerNotify)
                      const Padding(
                        padding: EdgeInsets.only(left: 12, bottom: 8),
                        child: LiveFollowerNotifyBanner(),
                      ),
                    Expanded(
                      child: BroadcastSocialFeed(
                        entries: _feedEntries,
                        onSayHi: _onSayHi,
                      ),
                    ),
                  ],
                ),
              ),

            if (_room != null &&
                !_isConnecting &&
                _errorMessage == null &&
                (_countdownSeconds != null || _isStreaming))
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: LiveGlassCapsule(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.white24,
                                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null || avatarUrl.isEmpty
                                        ? Text(
                                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.favorite, size: 12, color: Colors.orange.shade200),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$_likesCount',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.9),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          LiveGlassCapsule(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            borderRadius: 22,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite, color: Colors.orange.shade400, size: 22),
                                const SizedBox(width: 6),
                                Text(
                                  '$_likesCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          LiveGlassCapsule(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_alt_outlined, color: Colors.white.withValues(alpha: 0.9), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '$_viewerCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _onEndPressed,
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.38),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(Icons.power_settings_new, color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_room != null &&
                !_isConnecting &&
                _errorMessage == null &&
                (_countdownSeconds != null || _isStreaming))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        LiveGlassIconButton(
                          icon: _microphoneEnabled ? Icons.mic_none_rounded : Icons.mic_off_rounded,
                          active: _microphoneEnabled,
                          onPressed: _toggleMicrophone,
                        ),
                        LiveGlassIconButton(
                          icon: _cameraEnabled ? Icons.videocam_outlined : Icons.videocam_off_outlined,
                          active: _cameraEnabled,
                          onPressed: _toggleCamera,
                        ),
                        LiveGlassIconButton(
                          icon: Icons.ios_share_rounded,
                          onPressed: _shareLiveLink,
                        ),
                        LiveGlassIconButton(
                          icon: Icons.more_horiz,
                          onPressed: _openHostTools,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget to render local video preview
class _LocalVideoPreview extends StatefulWidget {
  final Room room;

  const _LocalVideoPreview({required this.room});

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoTrack? _localVideoTrack;

  @override
  void initState() {
    super.initState();
    widget.room.localParticipant?.addListener(_onLocalParticipantChanged);
    _onLocalParticipantChanged();
  }

  @override
  void dispose() {
    widget.room.localParticipant?.removeListener(_onLocalParticipantChanged);
    super.dispose();
  }

  void _onLocalParticipantChanged() {
    final localParticipant = widget.room.localParticipant;
    if (localParticipant == null) {
      setState(() => _localVideoTrack = null);
      return;
    }

    final trackPublications = localParticipant.trackPublications.values;
    final videoTracks = trackPublications
        .where((pub) => pub.track != null && pub.track is LocalVideoTrack)
        .map((pub) => pub.track as LocalVideoTrack);

    setState(() {
      _localVideoTrack = videoTracks.isNotEmpty ? videoTracks.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_localVideoTrack != null) {
      return Center(
        child: VideoTrackRenderer(
          _localVideoTrack!,
          fit: VideoViewFit.cover,
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 80,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Camera is off',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
