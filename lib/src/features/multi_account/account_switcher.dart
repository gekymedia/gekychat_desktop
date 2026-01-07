import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/device_id.dart';
import '../../core/feature_flags.dart';
import '../../core/session.dart';
import 'account_repository.dart';

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
            try {
              await repository.switchAccount(account['id'] as int);
              // Reload user profile and refresh
              ref.invalidate(currentUserProvider);
              // Navigate back to chats to refresh
              Navigator.of(context).popUntil((route) => route.isFirst);
            } catch (e) {
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

