import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quick_replies_repository.dart';

class QuickRepliesScreen extends ConsumerStatefulWidget {
  const QuickRepliesScreen({super.key});

  @override
  ConsumerState<QuickRepliesScreen> createState() => _QuickRepliesScreenState();
}

class _QuickRepliesScreenState extends ConsumerState<QuickRepliesScreen> {
  late Future<List<QuickReply>> _quickRepliesFuture;

  @override
  void initState() {
    super.initState();
    _loadQuickReplies();
  }

  void _loadQuickReplies() {
    final repo = ref.read(quickRepliesRepositoryProvider);
    setState(() {
      _quickRepliesFuture = repo.getQuickReplies();
    });
  }

  Future<void> _showAddEditDialog({QuickReply? quickReply}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController(text: quickReply?.title ?? '');
    final messageController = TextEditingController(text: quickReply?.message ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          quickReply == null ? 'Add Quick Reply' : 'Edit Quick Reply',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., "On my way"',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: 'Enter your quick reply message',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLength: 1000,
                maxLines: 4,
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
              if (titleController.text.trim().isNotEmpty &&
                  messageController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final repo = ref.read(quickRepliesRepositoryProvider);
        if (quickReply == null) {
          await repo.createQuickReply(
            titleController.text.trim(),
            messageController.text.trim(),
          );
        } else {
          await repo.updateQuickReply(
            quickReply.id,
            titleController.text.trim(),
            messageController.text.trim(),
          );
        }
        _loadQuickReplies();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(quickReply == null
                  ? 'Quick reply added'
                  : 'Quick reply updated'),
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

  Future<void> _deleteQuickReply(QuickReply quickReply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quick Reply'),
        content: const Text('Are you sure you want to delete this quick reply?'),
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
        final repo = ref.read(quickRepliesRepositoryProvider);
        await repo.deleteQuickReply(quickReply.id);
        _loadQuickReplies();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quick reply deleted')),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Quick Replies'),
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
          child: FutureBuilder<List<QuickReply>>(
            future: _quickRepliesFuture,
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
                        onPressed: _loadQuickReplies,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final quickReplies = snapshot.data ?? [];

              if (quickReplies.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.reply, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No quick replies yet',
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
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: quickReplies.length,
                itemBuilder: (context, index) {
                  final qr = quickReplies[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ListTile(
                      title: Text(qr.title),
                      subtitle: Text(
                        qr.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (qr.usageCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '${qr.usageCount}x',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showAddEditDialog(quickReply: qr),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () => _deleteQuickReply(qr),
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


