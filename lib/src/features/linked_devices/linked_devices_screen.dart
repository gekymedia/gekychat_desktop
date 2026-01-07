import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'linked_devices_repository.dart';
import 'models.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

final linkedDevicesProvider = FutureProvider<List<LinkedDevice>>((ref) async {
  final repo = ref.read(linkedDevicesRepositoryProvider);
  return await repo.getLinkedDevices();
});

class LinkedDevicesScreen extends ConsumerWidget {
  const LinkedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final devicesAsync = ref.watch(linkedDevicesProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Linked Devices'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
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
      ),
      body: devicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No linked devices',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          _getDeviceIcon(device.name),
                          size: 32,
                          color: device.isCurrentDevice
                              ? AppTheme.primaryGreen
                              : (isDark ? Colors.white70 : Colors.grey[600]),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: device.isCurrentDevice
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (device.isCurrentDevice)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'This device',
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (device.lastUsedAt != null)
                              Text(
                                'Last used: ${_formatDate(device.lastUsedAt!)}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              )
                            else
                              Text(
                                'Created: ${_formatDate(device.createdAt)}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: device.isCurrentDevice
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _showDeleteDialog(context, ref, device, isDark),
                              ),
                      ),
                    );
                  },
                ),
              ),
              if (devices.where((d) => !d.isCurrentDevice).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showDeleteOthersDialog(
                          context, ref, devices.where((d) => !d.isCurrentDevice).length, isDark),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                          'Log out from all other devices (${devices.where((d) => !d.isCurrentDevice).length})'),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading devices',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(linkedDevicesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('windows')) return Icons.laptop_windows;
    if (lower.contains('mac') || lower.contains('ios')) return Icons.laptop_mac;
    if (lower.contains('android')) return Icons.smartphone;
    if (lower.contains('linux')) return Icons.computer;
    if (lower.contains('mobile') || lower.contains('phone'))
      return Icons.smartphone;
    return Icons.devices;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE at h:mm a').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref,
      LinkedDevice device, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: const Text('Remove Device'),
        content: Text('Are you sure you want to remove "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(linkedDevicesRepositoryProvider).deleteDevice(device.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device removed')),
                  );
                }
                ref.invalidate(linkedDevicesProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showDeleteOthersDialog(
      BuildContext context, WidgetRef ref, int count, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: const Text('Log Out from All Other Devices'),
        content: Text(
            'Are you sure you want to log out from $count other device${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(linkedDevicesRepositoryProvider)
                    .deleteOtherDevices();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Logged out from $count device${count == 1 ? '' : 's'}')),
                  );
                }
                ref.invalidate(linkedDevicesProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

