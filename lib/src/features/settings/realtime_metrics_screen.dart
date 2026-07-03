import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class RealtimeMetricsScreen extends ConsumerStatefulWidget {
  const RealtimeMetricsScreen({super.key});

  @override
  ConsumerState<RealtimeMetricsScreen> createState() =>
      _RealtimeMetricsScreenState();
}

class _RealtimeMetricsScreenState extends ConsumerState<RealtimeMetricsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  bool _autoRefresh = false;
  Timer? _autoRefreshTimer;
  final List<int> _dmTrend = [];
  final List<int> _groupTrend = [];
  static const int _maxTrendPoints = 30;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _setAutoRefresh(bool enabled) {
    setState(() {
      _autoRefresh = enabled;
    });
    _autoRefreshTimer?.cancel();
    if (enabled) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _fetch(showLoading: false);
      });
    }
  }

  void _pushTrendPoint(List<int> list, int value) {
    if (value <= 0) return;
    list.add(value);
    if (list.length > _maxTrendPoints) {
      list.removeRange(0, list.length - _maxTrendPoints);
    }
  }

  Future<void> _fetch({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _error = null;
    }
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/realtime/metrics');
      if (response.statusCode == 200 && response.data is Map) {
        final map = Map<String, dynamic>.from(response.data as Map);
        final dm = map['metrics']?['dm'];
        final group = map['metrics']?['group'];
        final dmLast = dm is Map ? dm['last_fanout_duration_ms'] : null;
        final groupLast =
            group is Map ? group['last_fanout_duration_ms'] : null;

        setState(() {
          _data = map;
          if (dmLast is num) _pushTrendPoint(_dmTrend, dmLast.toInt());
          if (groupLast is num) _pushTrendPoint(_groupTrend, groupLast.toInt());
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = 'Unexpected response from server';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'healthy':
        return Colors.green;
      case 'slow':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Health'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Failed to load metrics: $_error',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_data != null) ...[
              Card(
                child: SwitchListTile(
                  value: _autoRefresh,
                  title: const Text('Auto-refresh'),
                  subtitle: const Text('Refresh every 5 seconds'),
                  secondary: const Icon(Icons.autorenew),
                  onChanged: _setAutoRefresh,
                ),
              ),
              const SizedBox(height: 12),
              _MetricsCard(
                title: 'Direct Messages',
                metrics: _data!['metrics']?['dm'] as Map<String, dynamic>? ??
                    const {},
                trend: _dmTrend,
                statusColor: _statusColor(
                  context,
                  ((_data!['metrics']?['dm']?['status']) ?? 'unknown')
                      .toString(),
                ),
              ),
              const SizedBox(height: 12),
              _MetricsCard(
                title: 'Group Messages',
                metrics:
                    _data!['metrics']?['group'] as Map<String, dynamic>? ??
                        const {},
                trend: _groupTrend,
                statusColor: _statusColor(
                  context,
                  ((_data!['metrics']?['group']?['status']) ?? 'unknown')
                      .toString(),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text('Generated At'),
                  subtitle:
                      Text((_data!['generated_at'] ?? 'n/a').toString()),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _fetch,
                    tooltip: 'Refresh',
                  ),
                ),
              ),
            ],
            if (!_loading && _data == null && _error == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No realtime metrics data yet.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> metrics;
  final List<int> trend;
  final Color statusColor;

  const _MetricsCard({
    required this.title,
    required this.metrics,
    required this.trend,
    required this.statusColor,
  });

  String _value(dynamic value) => value?.toString() ?? '0';

  @override
  Widget build(BuildContext context) {
    final status = (metrics['status'] ?? 'unknown').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _kv('Events total', _value(metrics['events_total'])),
            _kv('Recipients total', _value(metrics['recipients_total'])),
            _kv('Avg recipients/event',
                _value(metrics['avg_recipients_per_event'])),
            _kv('Last fanout duration',
                '${_value(metrics['last_fanout_duration_ms'])} ms'),
            const SizedBox(height: 12),
            _Sparkline(values: trend, color: statusColor),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<int> values;
  final Color color;

  const _Sparkline({
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: Text('Trend: waiting for more samples'),
        ),
      );
    }
    return SizedBox(
      height: 44,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _SparklinePainter({
    required this.values,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce(math.max).toDouble();
    final minV = values.reduce(math.min).toDouble();
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);
    final stepX = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final normalized = (values[i] - minV) / range;
      final y = size.height - (normalized * (size.height - 4)) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawPath(path, linePaint);

    final baselinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.25);
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      baselinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

