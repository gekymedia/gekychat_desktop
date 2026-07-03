import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../core/global_navigator_key.dart';
import 'call_repository.dart';

/// Issue keys must match Laravel `CallController::rate` whitelist.
const Map<String, String> kCallRatingIssueLabels = {
  'echo': 'Echo',
  'video_lag': 'Video lag',
  'audio_cut': 'Audio cut out',
  'dropped': 'Call dropped',
  'delay': 'Delay',
  'poor_video': 'Poor video',
  'poor_audio': 'Poor audio',
  'other': 'Other',
};

Future<void> showCallRatingSheet(
  BuildContext context, {
  required CallRepository repository,
  required int sessionId,
  required String callType,
  int? durationSeconds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: _CallRatingForm(
          repository: repository,
          sessionId: sessionId,
          callType: callType,
          durationSeconds: durationSeconds,
        ),
      );
    },
  );
}

void scheduleCallRatingPrompt({
  required CallRepository repository,
  required int sessionId,
  required String callType,
  int? durationSeconds,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    showCallRatingSheet(
      ctx,
      repository: repository,
      sessionId: sessionId,
      callType: callType,
      durationSeconds: durationSeconds,
    );
  });
}

class _CallRatingForm extends StatefulWidget {
  final CallRepository repository;
  final int sessionId;
  final String callType;
  final int? durationSeconds;

  const _CallRatingForm({
    required this.repository,
    required this.sessionId,
    required this.callType,
    this.durationSeconds,
  });

  @override
  State<_CallRatingForm> createState() => _CallRatingFormState();
}

class _CallRatingFormState extends State<_CallRatingForm> {
  int _stars = 0;
  final Set<String> _issues = {};
  final TextEditingController _comment = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Map<String, dynamic> _clientMeta() {
    return {
      'platform': Platform.operatingSystem,
    };
  }

  Future<void> _submit() async {
    if (_stars < 1 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.repository.submitCallRating(
        sessionId: widget.sessionId,
        rating: _stars,
        issues: _issues.isEmpty ? null : _issues.toList(),
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        callType: widget.callType,
        durationSeconds: widget.durationSeconds,
        clientMeta: _clientMeta(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        final root = rootNavigatorKey.currentContext;
        if (root != null && root.mounted) {
          ScaffoldMessenger.of(root).showSnackBar(
            const SnackBar(
              content: Text('Thanks — your feedback helps us improve calls.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send feedback: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How was your call?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Rate quality to help us improve audio and video.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final n = i + 1;
                final filled = n <= _stars;
                return IconButton(
                  iconSize: 40,
                  onPressed: () => setState(() => _stars = n),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? Colors.amber.shade700 : cs.outline,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'What went wrong? (optional)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCallRatingIssueLabels.entries.map((e) {
                final selected = _issues.contains(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _issues.add(e.key);
                      } else {
                        _issues.remove(e.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_stars < 1 || _submitting) ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
