import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'broadcast_repository.dart';
import 'models.dart';
import 'create_broadcast_screen.dart';
import 'edit_broadcast_screen.dart';
import 'send_broadcast_screen.dart';
import '../../core/providers.dart';

final broadcastListsProvider = FutureProvider<List<BroadcastList>>((ref) async {
  final repo = ref.read(broadcastRepositoryProvider);
  return await repo.getBroadcastLists();
});

class BroadcastListsScreen extends ConsumerWidget {
  const BroadcastListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listsAsync = ref.watch(broadcastListsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Broadcast Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateBroadcastScreen(),
                ),
              ).then((_) {
                ref.invalidate(broadcastListsProvider);
              });
            },
          ),
        ],
      ),
      body: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No broadcast lists',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a broadcast list to send messages to multiple contacts',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateBroadcastScreen(),
                        ),
                      ).then((_) {
                        ref.invalidate(broadcastListsProvider);
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Broadcast List'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(broadcastListsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: lists.length,
              itemBuilder: (context, index) {
                final list = lists[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF008069),
                      child: Icon(
                        Icons.campaign,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      list.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (list.description != null && list.description!.isNotEmpty)
                          Text(
                            list.description!,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '${list.recipientCount} ${list.recipientCount == 1 ? 'recipient' : 'recipients'}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'send') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SendBroadcastScreen(broadcastListId: list.id),
                            ),
                          );
                        } else if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditBroadcastScreen(broadcastList: list),
                            ),
                          ).then((_) {
                            ref.invalidate(broadcastListsProvider);
                          });
                        } else if (value == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Broadcast List'),
                              content: Text('Are you sure you want to delete "${list.name}"?'),
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
                              final repo = ref.read(broadcastRepositoryProvider);
                              await repo.deleteBroadcastList(list.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Broadcast list deleted')),
                                );
                              }
                              ref.invalidate(broadcastListsProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to delete: $e')),
                                );
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'send',
                          child: Row(
                            children: [
                              Icon(Icons.send, size: 20),
                              SizedBox(width: 8),
                              Text('Send Message'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SendBroadcastScreen(broadcastListId: list.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading broadcast lists',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(broadcastListsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

