import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';

class PollOption {
  final int id;
  final String text;
  final int voteCount;
  final int percentage;
  final bool isVoted;

  const PollOption({
    required this.id,
    required this.text,
    required this.voteCount,
    required this.percentage,
    required this.isVoted,
  });

  factory PollOption.fromJson(Map<String, dynamic> j) => PollOption(
        id: j['id'] as int,
        text: j['text']?.toString() ?? '',
        voteCount: j['vote_count'] as int? ?? 0,
        percentage: j['percentage'] as int? ?? 0,
        isVoted: j['is_voted'] == true,
      );
}

class PollData {
  final int id;
  final int messageId;
  final String question;
  final bool allowMultiple;
  final bool isAnonymous;
  final bool isClosed;
  final int totalVotes;
  final List<PollOption> options;

  const PollData({
    required this.id,
    required this.messageId,
    required this.question,
    required this.allowMultiple,
    required this.isAnonymous,
    required this.isClosed,
    required this.totalVotes,
    required this.options,
  });

  factory PollData.fromJson(Map<String, dynamic> j) => PollData(
        id: j['id'] as int,
        messageId: j['message_id'] as int? ?? 0,
        question: j['question']?.toString() ?? 'Poll',
        allowMultiple: j['allow_multiple'] == true,
        isAnonymous: j['is_anonymous'] == true,
        isClosed: j['is_closed'] == true,
        totalVotes: j['total_votes'] as int? ?? 0,
        options: (j['options'] as List<dynamic>? ?? [])
            .map((o) => PollOption.fromJson(Map<String, dynamic>.from(o as Map)))
            .toList(),
      );
}

/// Interactive poll bubble with live vote counts (fetched from API).
class PollMessageWidget extends ConsumerStatefulWidget {
  final int messageId;
  final bool isGroupPoll;
  final bool isDark;

  const PollMessageWidget({
    super.key,
    required this.messageId,
    this.isGroupPoll = false,
    required this.isDark,
  });

  @override
  ConsumerState<PollMessageWidget> createState() => _PollMessageWidgetState();
}

class _PollMessageWidgetState extends ConsumerState<PollMessageWidget> {
  PollData? _poll;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPoll());
  }

  Future<void> _loadPoll() async {
    if (widget.messageId <= 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final api = ref.read(apiServiceProvider);
      final path = widget.isGroupPoll
          ? '/group-messages/${widget.messageId}/poll'
          : '/polls/${widget.messageId}';
      final res = await api.get(path);
      final raw = res.data;
      Map<String, dynamic>? map;
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final inner = m['data'];
        map = inner is Map ? Map<String, dynamic>.from(inner) : m;
      }
      if (!mounted) return;
      setState(() {
        _poll = map != null ? PollData.fromJson(map) : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load poll';
        _loading = false;
      });
    }
  }

  Future<void> _vote(int optionId) async {
    if (_poll == null || _poll!.isClosed) return;

    final option = _poll!.options.firstWhere((o) => o.id == optionId);
    final optionIds = option.isVoted ? <int>[] : [optionId];

    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post(
        '/polls/${_poll!.id}/vote',
        data: {'option_ids': optionIds},
      );
      final raw = res.data;
      if (raw is Map && mounted) {
        final m = Map<String, dynamic>.from(raw);
        final inner = m['data'];
        final map = inner is Map ? Map<String, dynamic>.from(inner) : m;
        setState(() => _poll = PollData.fromJson(map));
      }
    } catch (e) {
      debugPrint('Poll vote error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _poll == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null || _poll == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          _error ?? 'Poll unavailable',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    final poll = _poll!;
    final accent = AppTheme.primaryGreen;
    final muted = widget.isDark ? Colors.white54 : Colors.grey[600];

    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Row(
            children: [
              Icon(Icons.poll_outlined, size: 16, color: accent),
              const SizedBox(width: 4),
              Text(
                poll.isAnonymous ? 'Anonymous Poll' : 'Poll',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              if (poll.isClosed) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CLOSED',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            poll.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          ...poll.options.map(
            (opt) => _PollOptionTile(
              option: opt,
              totalVotes: poll.totalVotes,
              isClosed: poll.isClosed,
              accent: accent,
              isDark: widget.isDark,
              onTap: () => _vote(opt.id),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${poll.totalVotes} vote${poll.totalVotes != 1 ? 's' : ''}${poll.allowMultiple ? ' · Multiple answers' : ''}',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  final PollOption option;
  final int totalVotes;
  final bool isClosed;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _PollOptionTile({
    required this.option,
    required this.totalVotes,
    required this.isClosed,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pctFromCounts = totalVotes > 0
        ? (option.voteCount * 100.0) / totalVotes
        : 0.0;
    final pct = option.percentage > 0 ? option.percentage / 100.0 : pctFromCounts / 100.0;

    return GestureDetector(
      onTap: isClosed ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 36,
                backgroundColor: option.isVoted
                    ? accent.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  option.isVoted
                      ? accent.withValues(alpha: 0.35)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      option.isVoted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: option.isVoted ? accent : Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        option.text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              option.isVoted ? FontWeight.w600 : FontWeight.normal,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      option.voteCount > 0
                          ? '${option.voteCount} · ${(pct * 100).round()}%'
                          : '${(pct * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: option.isVoted ? accent : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
