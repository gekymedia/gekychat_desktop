import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models.dart';
import 'status_repository.dart';
import 'widgets/status_ring.dart';
import 'status_viewer_screen.dart';
import 'create_status_screen.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';

final statusListProvider = FutureProvider<List<StatusSummary>>((ref) async {
  final repo = ref.read(statusRepositoryProvider);
  return await repo.getStatuses();
});

final myStatusProvider = FutureProvider<MyStatus>((ref) async {
  final repo = ref.read(statusRepositoryProvider);
  return await repo.getMyStatus();
});

class StatusListScreen extends ConsumerWidget {
  const StatusListScreen({super.key});

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return 'Yesterday';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusListAsync = ref.watch(statusListProvider);
    final myStatusAsync = ref.watch(myStatusProvider);

    return Container(
      color: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Add Status Button (first item)
          Consumer(
            builder: (context, ref, child) {
              final userAsync = ref.watch(currentUserProvider);
              return userAsync.when(
                data: (user) {
                  return myStatusAsync.when(
                    data: (myStatus) {
                      final hasStatus = myStatus.hasActiveStatus;
                      return InkWell(
                        onTap: () {
                          if (hasStatus) {
                            // View own status
                            final statusSummary = StatusSummary(
                              userId: user.id,
                              userName: user.name,
                              userAvatar: user.avatarUrl,
                              updates: myStatus.updates,
                              lastUpdatedAt: myStatus.lastUpdatedAt ?? DateTime.now(),
                              hasUnviewed: false,
                            );
                            
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StatusViewerScreen(
                                    statusSummary: statusSummary,
                                    startIndex: 0,
                                    isOwnStatus: true,
                                  ),
                                ),
                              ).then((_) {
                                ref.invalidate(myStatusProvider);
                                ref.invalidate(statusListProvider);
                              });
                            }
                          } else {
                            // Create new status
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateStatusScreen(),
                              ),
                            ).then((_) {
                              ref.invalidate(myStatusProvider);
                              ref.invalidate(statusListProvider);
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              if (hasStatus)
                                StatusRing(
                                  size: 60,
                                  hasViewed: true,
                                  totalSegments: myStatus.activeUpdates.length,
                                  viewedSegments: myStatus.activeUpdates.length,
                                  child: Container(
                                    color: Colors.teal,
                                    child: const Icon(Icons.person, size: 30, color: Colors.white),
                                  ),
                                )
                              else
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isDark ? Colors.white38 : Colors.grey[400]!, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: isDark ? Colors.white38 : Colors.grey[400],
                                    size: 30,
                                  ),
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'My Status',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      hasStatus ? 'Tap to view' : 'Tap to add status update',
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasStatus)
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: AppTheme.primaryGreen,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const CreateStatusScreen(),
                                      ),
                                    ).then((_) {
                                      ref.invalidate(myStatusProvider);
                                      ref.invalidate(statusListProvider);
                                    });
                                  },
                                  tooltip: 'Add new status',
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          const Divider(height: 1),
          
          // Other Statuses
          Text(
            'Recent Updates',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          statusListAsync.when(
            data: (statuses) {
              if (statuses.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No status updates',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }
              
              return Column(
                children: statuses.map((status) {
                  final activeUpdates = status.activeUpdates;
                  if (activeUpdates.isEmpty) return const SizedBox.shrink();
                  
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StatusViewerScreen(
                            statusSummary: status,
                            startIndex: 0,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          StatusRing(
                            size: 60,
                            hasViewed: !status.hasUnviewed,
                            totalSegments: activeUpdates.length,
                            viewedSegments: status.viewedSegments,
                            child: status.userAvatar != null
                                ? CachedNetworkImage(
                                    imageUrl: status.userAvatar!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.teal,
                                      child: Center(
                                        child: Text(
                                          status.userName[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.teal,
                                    child: Center(
                                      child: Text(
                                        status.userName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status.userName,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _formatTime(status.lastUpdatedAt),
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Error loading statuses: $error',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension StatusSummaryExtension on StatusSummary {
  int get viewedSegments {
    return updates.where((u) => u.viewed).length;
  }
}

