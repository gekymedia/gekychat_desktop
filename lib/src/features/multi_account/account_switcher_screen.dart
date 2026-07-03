import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/colored_avatar.dart';
import '../auth/auth_provider.dart';
import '../chats/chat_providers.dart';
import '../../core/session.dart';
import 'account_repository.dart';

class AccountSwitcherScreen extends ConsumerStatefulWidget {
  const AccountSwitcherScreen({super.key});

  @override
  ConsumerState<AccountSwitcherScreen> createState() => _AccountSwitcherScreenState();
}

int? _accountIdFromMap(Map<String, dynamic> account) {
  final a = account['account_id'];
  final b = account['id'];
  if (a != null) return a is int ? a : (a is num ? a.toInt() : null);
  if (b != null) return b is int ? b : (b is num ? b.toInt() : null);
  return null;
}

class _AccountSwitcherScreenState extends ConsumerState<AccountSwitcherScreen> {
  int? _currentAccountId;

  @override
  void initState() {
    super.initState();
    _loadCurrentAccountId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(accountsProvider);
    });
  }

  Future<void> _loadCurrentAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentAccountId = prefs.getInt('current_account_id');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Switch Account'),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          final currentId = _currentAccountId;
          final list = accounts.map<Map<String, dynamic>>((a) {
            final copy = Map<String, dynamic>.from(a);
            final id = _accountIdFromMap(a);
            copy['is_active'] = (id != null && id == currentId);
            return copy;
          }).toList();

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No accounts available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add an account to switch between them',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.go('/login');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Account'),
                  ),
                ],
              ),
            );
          }

          if (list.length == 1) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_circle,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Only one account available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add another account to switch between them',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.go('/login');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Account'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              if (list.length < 2)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Account'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final account = list[index];
                    final user = account['user'] as Map<String, dynamic>? ?? {};
                    final userName = user['name'] ?? user['phone'] ?? 'Account';
                    final userAvatar = user['avatar_url'] as String?;
                    final isActive = account['is_active'] == true;
                    final accountLabel = account['account_label'] as String?;
                    final accountId = _accountIdFromMap(account);
                    final hasValidId = accountId != null && accountId != 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        leading: ColoredAvatar(
                          name: userName,
                          imageUrl: userAvatar,
                          radius: 20,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                userName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.colorScheme.primary),
                                ),
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: accountLabel != null
                            ? Text(
                                accountLabel,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                ),
                              )
                            : null,
                        trailing: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                          onSelected: (value) async {
                            if (value == 'switch' && !isActive && hasValidId) {
                              await _switchAccount(accountId);
                            } else if (value == 'remove' && !isActive && hasValidId) {
                              await _removeAccount(accountId);
                            }
                          },
                          itemBuilder: (context) => [
                            if (!isActive && hasValidId)
                              const PopupMenuItem(
                                value: 'switch',
                                child: Row(
                                  children: [
                                    Icon(Icons.swap_horiz, size: 20),
                                    SizedBox(width: 12),
                                    Text('Switch to this account'),
                                  ],
                                ),
                              ),
                            if (!isActive && hasValidId)
                              const PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    SizedBox(width: 12),
                                    Text('Remove account', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            if (isActive || !hasValidId)
                              PopupMenuItem(
                                enabled: false,
                                child: Text(isActive ? 'Current account' : 'Invalid account'),
                              ),
                          ],
                        ),
                        onTap: isActive || !hasValidId
                            ? null
                            : () async {
                                await _switchAccount(accountId);
                              },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load accounts',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(accountsProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchAccount(int accountId) async {
    if (accountId == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot switch to this account. Please remove it and add again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      final repository = ref.read(accountRepositoryProvider);
      await repository.switchAccount(accountId);
      await ref.read(authProvider.notifier).refreshTokenFromStorage();
      ref.invalidate(currentUserProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(chatRepositoryProvider);
      if (mounted) {
        context.go('/chats');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account switched successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error switching account: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch account: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _removeAccount(int accountId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Account'),
        content: const Text(
          'Are you sure you want to remove this account? You will need to log in again to use it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = ref.read(accountRepositoryProvider);
        await repository.removeAccount(accountId);
        ref.invalidate(accountsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e, stackTrace) {
        debugPrint('Error removing account: $e\n$stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove account: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }
}
