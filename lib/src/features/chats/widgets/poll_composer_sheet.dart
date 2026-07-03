import 'package:flutter/material.dart';

/// Bottom sheet to create a poll (question + options). Pops with a [Map] on Send.
class PollComposerSheet extends StatefulWidget {
  const PollComposerSheet({super.key});

  @override
  State<PollComposerSheet> createState() => _PollComposerSheetState();
}

class _PollComposerSheetState extends State<PollComposerSheet> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMultiple = false;
  bool _isAnonymous = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length >= 10) return;
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_optionCtrls.length <= 2) return;
    setState(() {
      _optionCtrls[i].dispose();
      _optionCtrls.removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.poll_outlined, color: p),
              const SizedBox(width: 8),
              const Text('Create Poll',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  final q = _questionCtrl.text.trim();
                  final opts = _optionCtrls
                      .map((c) => c.text.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();
                  if (q.isEmpty || opts.length < 2) return;
                  Navigator.pop(context, {
                    'question': q,
                    'options': opts,
                    'allow_multiple': _allowMultiple,
                    'is_anonymous': _isAnonymous,
                  });
                },
                child: Text(
                  'Send',
                  style: TextStyle(
                    color: p,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _questionCtrl,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Options', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...List.generate(_optionCtrls.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _optionCtrls[i],
                        decoration: InputDecoration(
                          labelText: 'Option ${i + 1}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_optionCtrls.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeOption(i),
                      ),
                  ]),
                )),
            if (_optionCtrls.length < 10)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add option'),
                onPressed: _addOption,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow multiple answers'),
              value: _allowMultiple,
              onChanged: (v) => setState(() => _allowMultiple = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Anonymous poll'),
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
            ),
          ],
        ),
      ),
    );
  }
}
