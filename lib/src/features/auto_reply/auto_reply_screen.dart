import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auto_reply_repository.dart';

/// AUTO-REPLY: Screen for managing auto-reply rules
class AutoReplyScreen extends ConsumerStatefulWidget {
  const AutoReplyScreen({super.key});

  @override
  ConsumerState<AutoReplyScreen> createState() => _AutoReplyScreenState();
}

class _AutoReplyScreenState extends ConsumerState<AutoReplyScreen> {
  late Future<List<AutoReplyRule>> _rulesFuture;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    final repo = ref.read(autoReplyRepositoryProvider);
    setState(() {
      _rulesFuture = repo.getAutoReplyRules();
    });
  }

  Future<void> _showAddEditDialog({AutoReplyRule? rule}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keywordController = TextEditingController(text: rule?.keyword ?? '');
    final replyController = TextEditingController(text: rule?.replyText ?? '');
    final delayController = TextEditingController(
      text: rule?.delaySeconds?.toString() ?? '',
    );
    bool isActive = rule?.isActive ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          title: Text(
            rule == null ? 'Add Auto-Reply Rule' : 'Edit Auto-Reply Rule',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This rule will automatically reply when someone sends a message containing the keyword.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keywordController,
                  decoration: InputDecoration(
                    labelText: 'Keyword',
                    hintText: 'e.g., "hello", "help"',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    helperText: 'Case-insensitive match',
                  ),
                  maxLength: 255,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: replyController,
                  decoration: InputDecoration(
                    labelText: 'Reply Text',
                    hintText: 'Message to send automatically',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  maxLength: 1000,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: delayController,
                  decoration: InputDecoration(
                    labelText: 'Delay (seconds)',
                    hintText: 'Optional delay before sending',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    helperText: 'Leave empty for immediate reply',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() {
                          isActive = value ?? true;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A3942) : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: isDark ? Colors.white70 : Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Auto-replies only work in one-to-one chats, not groups or channels.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (keywordController.text.trim().isNotEmpty &&
                    replyController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final repo = ref.read(autoReplyRepositoryProvider);
        final delay = delayController.text.trim().isEmpty
            ? null
            : int.tryParse(delayController.text.trim());

        if (rule == null) {
          await repo.createAutoReplyRule(
            keyword: keywordController.text.trim(),
            replyText: replyController.text.trim(),
            delaySeconds: delay,
            isActive: isActive,
          );
        } else {
          await repo.updateAutoReplyRule(
            id: rule.id,
            keyword: keywordController.text.trim(),
            replyText: replyController.text.trim(),
            delaySeconds: delay,
            isActive: isActive,
          );
        }
        _loadRules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                rule == null ? 'Auto-reply rule added' : 'Auto-reply rule updated',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteRule(AutoReplyRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Auto-Reply Rule'),
        content: const Text('Are you sure you want to delete this rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(autoReplyRepositoryProvider);
        await repo.deleteAutoReplyRule(rule.id);
        _loadRules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Auto-reply rule deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(AutoReplyRule rule) async {
    try {
      final repo = ref.read(autoReplyRepositoryProvider);
      await repo.updateAutoReplyRule(
        id: rule.id,
        isActive: !rule.isActive,
      );
      _loadRules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Auto-Reply Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: FutureBuilder<List<AutoReplyRule>>(
            future: _rulesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${snapshot.error}'),
                      ElevatedButton(
                        onPressed: _loadRules,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final rules = snapshot.data ?? [];

              if (rules.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.smart_toy_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No auto-reply rules yet',
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add one',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A3942) : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: isDark ? Colors.white70 : Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Auto-replies automatically respond to messages containing your keywords. They only work in one-to-one chats, not in groups.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: rules.length,
                itemBuilder: (context, index) {
                  final rule = rules[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ListTile(
                      leading: Icon(
                        rule.isActive ? Icons.smart_toy : Icons.smart_toy_outlined,
                        color: rule.isActive
                            ? const Color(0xFF008069)
                            : (isDark ? Colors.white38 : Colors.grey[400]),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.keyword,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          if (!rule.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Inactive',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            rule.replyText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                          if (rule.delaySeconds != null && rule.delaySeconds! > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: isDark ? Colors.white54 : Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${rule.delaySeconds}s delay',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              rule.isActive ? Icons.toggle_on : Icons.toggle_off,
                              color: rule.isActive
                                  ? const Color(0xFF008069)
                                  : (isDark ? Colors.white38 : Colors.grey[400]),
                            ),
                            onPressed: () => _toggleActive(rule),
                            tooltip: rule.isActive ? 'Disable' : 'Enable',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showAddEditDialog(rule: rule),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () => _deleteRule(rule),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

