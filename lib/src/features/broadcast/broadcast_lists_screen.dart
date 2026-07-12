import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'broadcast_repository.dart';
import 'models.dart';
import 'create_broadcast_screen.dart';
import 'edit_broadcast_screen.dart';
import 'send_broadcast_screen.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/desktop_center_modal.dart';

final broadcastListsProvider = FutureProvider<List<BroadcastList>>((ref) async {
  final repo = ref.read(broadcastRepositoryProvider);
  return await repo.getBroadcastLists();
});

/// Opens broadcast lists in a centered desktop modal.
Future<void> showBroadcastListsModal(BuildContext context) {
  return showDesktopCenterModal<void>(
    context: context,
    title: 'Broadcast Lists',
    maxWidth: 520,
    maxHeightFraction: 0.82,
    headerActions: [
      Builder(
        builder: (headerContext) {
          return IconButton(
            tooltip: 'Create broadcast list',
            icon: const Icon(Icons.add),
            onPressed: () => _openCreateBroadcastModal(headerContext),
          );
        },
      ),
    ],
    child: const BroadcastListsBody(inModal: true),
  );
}

Future<void> _openCreateBroadcastModal(BuildContext context) {
  return showDesktopCenterModal<void>(
    context: context,
    title: 'Create Broadcast List',
    maxWidth: 520,
    maxHeightFraction: 0.82,
    child: const _ModalCreateBroadcastBody(),
  );
}

Future<void> _openEditBroadcastModal(
  BuildContext context,
  BroadcastList list,
) {
  return showDesktopCenterModal<void>(
    context: context,
    title: 'Edit Broadcast List',
    maxWidth: 520,
    maxHeightFraction: 0.82,
    child: _ModalEditBroadcastBody(broadcastList: list),
  );
}

Future<void> _openSendBroadcastModal(
  BuildContext context,
  int broadcastListId,
) {
  return showDesktopCenterModal<void>(
    context: context,
    title: 'Send Broadcast',
    maxWidth: 520,
    maxHeightFraction: 0.75,
    child: _ModalSendBroadcastBody(broadcastListId: broadcastListId),
  );
}

class _ModalCreateBroadcastBody extends ConsumerWidget {
  const _ModalCreateBroadcastBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CreateBroadcastScreen(
      forModal: true,
      onComplete: () {
        ref.invalidate(broadcastListsProvider);
        Navigator.of(context).pop();
      },
    );
  }
}

class _ModalEditBroadcastBody extends ConsumerWidget {
  final BroadcastList broadcastList;

  const _ModalEditBroadcastBody({required this.broadcastList});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EditBroadcastScreen(
      broadcastList: broadcastList,
      forModal: true,
      onComplete: () {
        ref.invalidate(broadcastListsProvider);
        Navigator.of(context).pop();
      },
    );
  }
}

class _ModalSendBroadcastBody extends StatelessWidget {
  final int broadcastListId;

  const _ModalSendBroadcastBody({required this.broadcastListId});

  @override
  Widget build(BuildContext context) {
    return SendBroadcastScreen(
      broadcastListId: broadcastListId,
      forModal: true,
      onComplete: () => Navigator.of(context).pop(),
    );
  }
}

/// Sidebar / filter-tab body (no app bar) — matches mobile [EmbeddableBroadcastListsScreen].
class EmbeddableBroadcastListsScreen extends ConsumerWidget {
  const EmbeddableBroadcastListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const BroadcastListsBody();
  }
}

class BroadcastListsScreen extends ConsumerWidget {
  const BroadcastListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/chats');
            }
          },
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
      body: const BroadcastListsBody(),
    );
  }
}

class BroadcastListsBody extends ConsumerWidget {
  final bool inModal;

  const BroadcastListsBody({super.key, this.inModal = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listsAsync = ref.watch(broadcastListsProvider);

    return listsAsync.when(
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
                    if (inModal) {
                      _openCreateBroadcastModal(context);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateBroadcastScreen(),
                        ),
                      ).then((_) {
                        ref.invalidate(broadcastListsProvider);
                      });
                    }
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
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF008069),
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
                      if (list.description != null &&
                          list.description!.isNotEmpty)
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
                        if (inModal) {
                          _openSendBroadcastModal(context, list.id);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SendBroadcastScreen(broadcastListId: list.id),
                            ),
                          );
                        }
                      } else if (value == 'edit') {
                        if (inModal) {
                          await _openEditBroadcastModal(context, list);
                          ref.invalidate(broadcastListsProvider);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditBroadcastScreen(broadcastList: list),
                            ),
                          ).then((_) {
                            ref.invalidate(broadcastListsProvider);
                          });
                        }
                      } else if (value == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Broadcast List'),
                            content: Text(
                                'Are you sure you want to delete "${list.name}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          try {
                            final repo =
                                ref.read(broadcastRepositoryProvider);
                            await repo.deleteBroadcastList(list.id);
                            if (context.mounted) {
                                                            context.showSuccessToast('Broadcast list deleted');                            }
                            ref.invalidate(broadcastListsProvider);
                          } catch (e) {
                            if (context.mounted) {
                                                            context.showErrorToast('Failed to delete: $e');                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'send',
                        child: Row(
                          children: [
                            Icon(Icons.send, size: 20),
                            SizedBox(width: 8),
                            Text('Send Message'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
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
                    if (inModal) {
                      _openSendBroadcastModal(context, list.id);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SendBroadcastScreen(broadcastListId: list.id),
                        ),
                      );
                    }
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
    );
  }
}

