import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_repository.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

final storageUsageProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(storageRepositoryProvider);
  return await repo.getStorageUsage();
});

class StorageUsageScreen extends ConsumerWidget {
  const StorageUsageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usageAsync = ref.watch(storageUsageProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Storage Usage'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: usageAsync.when(
        data: (usage) {
          final total = usage['total'] ?? {};
          final photos = usage['photos'] ?? {};
          final videos = usage['videos'] ?? {};
          final audio = usage['audio'] ?? {};
          final documents = usage['documents'] ?? {};

          final totalSize = total['size'] ?? 0;
          final totalCount = total['count'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          _formatBytes(totalSize),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$totalCount files',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _StorageCategory(
                  icon: Icons.image,
                  title: 'Photos',
                  count: photos['count'] ?? 0,
                  size: photos['size'] ?? 0,
                  sizeFormatted: photos['size_formatted'] ?? '0 B',
                  color: Colors.blue,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _StorageCategory(
                  icon: Icons.video_library,
                  title: 'Videos',
                  count: videos['count'] ?? 0,
                  size: videos['size'] ?? 0,
                  sizeFormatted: videos['size_formatted'] ?? '0 B',
                  color: Colors.purple,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _StorageCategory(
                  icon: Icons.audiotrack,
                  title: 'Audio',
                  count: audio['count'] ?? 0,
                  size: audio['size'] ?? 0,
                  sizeFormatted: audio['size_formatted'] ?? '0 B',
                  color: Colors.orange,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _StorageCategory(
                  icon: Icons.description,
                  title: 'Documents',
                  count: documents['count'] ?? 0,
                  size: documents['size'] ?? 0,
                  sizeFormatted: documents['size_formatted'] ?? '0 B',
                  color: Colors.green,
                  isDark: isDark,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading storage usage: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(storageUsageProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes / 1024).floor().toString().length - 1;
    return '${(bytes / (1024 * i.clamp(0, units.length - 1))).toStringAsFixed(2)} ${units[i.clamp(0, units.length - 1)]}';
  }
}

class _StorageCategory extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final int size;
  final String sizeFormatted;
  final Color color;
  final bool isDark;

  const _StorageCategory({
    required this.icon,
    required this.title,
    required this.count,
    required this.size,
    required this.sizeFormatted,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? const Color(0xFF202C33) : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        subtitle: Text(
          '$count files',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
        ),
        trailing: Text(
          sizeFormatted,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

