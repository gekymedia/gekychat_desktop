import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../world_feed_repository.dart';

/// TikTok-style first-visit interest picker for World Feed.
Future<bool> maybeShowWorldFeedInterestsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final repo = ref.read(worldFeedRepositoryProvider);
    final data = await repo.getInterests();
    if (data['needs_onboarding'] != true) return false;
    if (!context.mounted) return false;

    final catalog = (data['catalog'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final minRequired = (data['min_required'] as num?)?.toInt() ?? 3;
    final initial = (data['selected'] as List? ?? const [])
        .map((e) => e.toString())
        .toSet();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WorldFeedInterestsDialog(
        catalog: catalog,
        minRequired: minRequired,
        initiallySelected: initial,
        onSubmit: (ids, {required skip}) async {
          await repo.saveInterests(interests: ids, skip: skip);
        },
      ),
    );
    return saved == true;
  } catch (_) {
    return false;
  }
}

class _WorldFeedInterestsDialog extends StatefulWidget {
  const _WorldFeedInterestsDialog({
    required this.catalog,
    required this.minRequired,
    required this.initiallySelected,
    required this.onSubmit,
  });

  final List<Map<String, dynamic>> catalog;
  final int minRequired;
  final Set<String> initiallySelected;
  final Future<void> Function(List<String> ids, {required bool skip}) onSubmit;

  @override
  State<_WorldFeedInterestsDialog> createState() =>
      _WorldFeedInterestsDialogState();
}

class _WorldFeedInterestsDialogState extends State<_WorldFeedInterestsDialog> {
  late final Set<String> _selected = {...widget.initiallySelected};
  bool _saving = false;
  String? _error;

  IconData _iconFor(String id) {
    switch (id) {
      case 'comedy':
        return Icons.emoji_emotions_outlined;
      case 'music':
        return Icons.music_note_outlined;
      case 'dance':
        return Icons.nightlife_outlined;
      case 'sports':
        return Icons.sports_soccer_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'beauty':
        return Icons.spa_outlined;
      case 'gaming':
        return Icons.sports_esports_outlined;
      case 'education':
        return Icons.menu_book_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'tech':
        return Icons.memory_outlined;
      case 'news':
        return Icons.newspaper_outlined;
      case 'faith':
        return Icons.favorite_outline;
      case 'business':
        return Icons.work_outline;
      case 'lifestyle':
        return Icons.home_outlined;
      case 'diy':
        return Icons.handyman_outlined;
      case 'auto':
        return Icons.directions_car_outlined;
      default:
        return Icons.tag_outlined;
    }
  }

  Future<void> _submit({required bool skip}) async {
    if (_saving) return;
    if (!skip && _selected.length < widget.minRequired) {
      setState(() {
        _error = 'Pick at least ${widget.minRequired} interests, or skip.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_selected.toList(), skip: skip);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save interests. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canContinue = _selected.length >= widget.minRequired;

    return AlertDialog(
      title: const Text('What would you like to watch?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick at least ${widget.minRequired} topics so World Feed matches your style.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in widget.catalog)
                      FilterChip(
                        avatar: Icon(_iconFor('${item['id']}'), size: 18),
                        label: Text('${item['label'] ?? item['id']}'),
                        selected: _selected.contains('${item['id']}'),
                        onSelected: _saving
                            ? null
                            : (selected) {
                                setState(() {
                                  final id = '${item['id']}';
                                  if (selected) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                  _error = null;
                                });
                              },
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              FilledButton(
                onPressed: _saving || !canContinue
                    ? null
                    : () => _submit(skip: false),
                child: Text(
                  _saving
                      ? 'Saving…'
                      : 'Continue (${_selected.length}/${widget.minRequired})',
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => _submit(skip: true),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
