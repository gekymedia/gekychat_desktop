import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'live_broadcast_repository.dart';

/// Host stream tools: record, RTMP out, OBS ingress.
Future<void> showLiveBroadcastHostToolsSheet({
  required BuildContext context,
  required LiveBroadcastRepository repository,
  required int broadcastId,
  required bool isRecording,
  required ValueChanged<bool> onRecordingChanged,
  String? rtmpUrl,
  String? streamKey,
  String? whipUrl,
  required void Function({
    String? rtmpUrl,
    String? streamKey,
    String? whipUrl,
  }) onIngressUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _HostToolsSheet(
        repository: repository,
        broadcastId: broadcastId,
        isRecording: isRecording,
        onRecordingChanged: onRecordingChanged,
        rtmpUrl: rtmpUrl,
        streamKey: streamKey,
        whipUrl: whipUrl,
        onIngressUpdated: onIngressUpdated,
      );
    },
  );
}

class _HostToolsSheet extends StatefulWidget {
  const _HostToolsSheet({
    required this.repository,
    required this.broadcastId,
    required this.isRecording,
    required this.onRecordingChanged,
    required this.onIngressUpdated,
    this.rtmpUrl,
    this.streamKey,
    this.whipUrl,
  });

  final LiveBroadcastRepository repository;
  final int broadcastId;
  final bool isRecording;
  final ValueChanged<bool> onRecordingChanged;
  final String? rtmpUrl;
  final String? streamKey;
  final String? whipUrl;
  final void Function({
    String? rtmpUrl,
    String? streamKey,
    String? whipUrl,
  }) onIngressUpdated;

  @override
  State<_HostToolsSheet> createState() => _HostToolsSheetState();
}

class _HostToolsSheetState extends State<_HostToolsSheet> {
  late bool _recording;
  late String? _rtmpUrl;
  late String? _streamKey;
  late String? _whipUrl;
  bool _busy = false;
  final _rtmpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recording = widget.isRecording;
    _rtmpUrl = widget.rtmpUrl;
    _streamKey = widget.streamKey;
    _whipUrl = widget.whipUrl;
  }

  @override
  void dispose() {
    _rtmpController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_recording) {
        await widget.repository.stopEgress(widget.broadcastId);
        setState(() => _recording = false);
        widget.onRecordingChanged(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording stopped')),
          );
        }
      } else {
        await widget.repository.startRecording(widget.broadcastId);
        setState(() => _recording = true);
        widget.onRecordingChanged(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording started')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setupIngress() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await widget.repository.createIngress(widget.broadcastId);
      setState(() {
        _rtmpUrl = data['rtmp_url']?.toString() ?? _rtmpUrl;
        _streamKey = data['stream_key']?.toString() ?? _streamKey;
        _whipUrl = data['whip_url']?.toString() ?? _whipUrl;
      });
      widget.onIngressUpdated(
        rtmpUrl: _rtmpUrl,
        streamKey: _streamKey,
        whipUrl: _whipUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OBS setup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRtmpOut() async {
    final url = _rtmpController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an RTMP URL')),
      );
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.startRtmpOut(widget.broadcastId, rtmpUrl: url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RTMP stream started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RTMP out failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copy(String label, String? value) {
    if (value == null || value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Stream tools',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
                color: _recording ? Colors.redAccent : Colors.white,
              ),
              title: Text(
                _recording ? 'Stop recording' : 'Record this live',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Saves an MP4 on the server',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _busy ? null : _toggleRecord,
            ),
            const Divider(color: Colors.white12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.videocam_outlined, color: Colors.white),
              title: const Text(
                'OBS / encoder (RTMP in)',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _rtmpUrl == null
                    ? 'Get a stream URL for OBS'
                    : 'Ready — tap to refresh',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: _busy ? null : _setupIngress,
            ),
            if (_rtmpUrl != null) ...[
              _CopyRow(
                label: 'RTMP URL',
                value: _rtmpUrl!,
                onCopy: () => _copy('RTMP URL', _rtmpUrl),
              ),
              if (_streamKey != null && _streamKey!.isNotEmpty)
                _CopyRow(
                  label: 'Stream key',
                  value: _streamKey!,
                  obscure: true,
                  onCopy: () => _copy('Stream key', _streamKey),
                ),
              if (_whipUrl != null && _whipUrl!.isNotEmpty)
                _CopyRow(
                  label: 'WHIP URL',
                  value: _whipUrl!,
                  onCopy: () => _copy('WHIP URL', _whipUrl),
                ),
            ],
            const Divider(color: Colors.white12),
            const Text(
              'Restream to YouTube / Twitch / custom',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rtmpController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'rtmp://…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _startRtmpOut,
              child: const Text('Start RTMP out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.obscure = false,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final display = obscure && value.length > 8
        ? '${value.substring(0, 4)}…${value.substring(value.length - 4)}'
        : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Text(
                  display,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }
}
