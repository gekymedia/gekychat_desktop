import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/database/message_queue_service.dart';
import '../../core/device_id.dart';
import '../../core/feature_flags.dart';
import '../../core/session.dart';
import '../../app_router.dart';
import 'account_repository.dart';
import '../chats/chat_repo.dart';

/// PHASE 2: Account Switcher Widget
class AccountSwitcher extends ConsumerStatefulWidget {
  const AccountSwitcher({super.key});

  @override
  ConsumerState<AccountSwitcher> createState() => _AccountSwitcherState();
}

class _AccountSwitcherState extends ConsumerState<AccountSwitcher> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final multiAccountEnabled = featureEnabled(ref, 'multi_account');
    
    if (!multiAccountEnabled) {
      return const SizedBox.shrink();
    }

    final accountsAsync = ref.watch(accountsProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.length <= 1) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<Map<String, dynamic>>(
          icon: const Icon(Icons.account_circle),
          tooltip: 'Switch Account',
          itemBuilder: (context) => accounts.map((account) {
            return PopupMenuItem<Map<String, dynamic>>(
              value: account,
              child: Row(
                children: [
                  if (account['is_active'] == true)
                    const Icon(Icons.check, size: 16, color: Color(0xFF008069)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          account['user']?['name'] ?? 'Account',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (account['account_label'] != null)
                          Text(
                            account['account_label'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onSelected: (account) async {
            if (account['is_active'] == true) return;
            
            final repository = ref.read(accountRepositoryProvider);
            final accountName = account['user']?['name'] ?? 'Unknown';
            final accountId = account['id'] as int;
            
            debugPrint('🔄 Account switch initiated: Switching to account ID $accountId ($accountName)');
            
            try {
              await repository.switchAccount(accountId);
              
              debugPrint('✅ Account switch successful: Now using account ID $accountId ($accountName)');
              
              // Invalidate database provider to use new account's database
              ref.invalidate(appDatabaseProvider);
              ref.invalidate(localStorageServiceProvider);
              ref.invalidate(messageQueueServiceProvider);
              
              // Reload user profile and refresh
              ref.invalidate(currentUserProvider);
              
              // Invalidate chat repository to reload conversations
              ref.invalidate(chatRepositoryProvider);
              
              debugPrint('🔄 Invalidated providers - ready to refresh data');
              
              // Navigate back to chats to refresh
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                // Trigger a rebuild by navigating to the same route
                final router = ref.read(routerProvider);
                router.go('/chats');
                debugPrint('🔄 Navigated to /chats - triggering refresh');
              }
            } catch (e) {
              debugPrint('❌ Account switch failed: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to switch account: $e')),
                );
              }
            }
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

