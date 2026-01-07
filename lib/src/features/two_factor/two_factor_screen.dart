import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'two_factor_repository.dart';
import 'models.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

final twoFactorStatusProvider =
    FutureProvider<TwoFactorStatus>((ref) async {
  final repo = ref.read(twoFactorRepositoryProvider);
  return await repo.getStatus();
});

final twoFactorSetupProvider = FutureProvider.family<TwoFactorSetup, void>((ref, _) async {
  final repo = ref.read(twoFactorRepositoryProvider);
  return await repo.setup();
});

class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showRecoveryCodes = false;
  List<String>? _recoveryCodes;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusAsync = ref.watch(twoFactorStatusProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Two-Step Verification'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: statusAsync.when(
        data: (status) {
          if (status.enabled) {
            return _buildEnabledView(context, isDark, status);
          } else {
            return _buildDisabledView(context, isDark);
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildEnabledView(
      BuildContext context, bool isDark, TwoFactorStatus status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: isDark ? const Color(0xFF202C33) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security,
                          color: AppTheme.primaryGreen, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Two-step verification is enabled',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your account is protected with two-step verification. You\'ll need your password and an authentication code from your authenticator app to sign in.',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (status.recoveryCodesCount > 0)
                    Text(
                      'Recovery codes: ${status.recoveryCodesCount} remaining',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_showRecoveryCodes && _recoveryCodes != null)
            Card(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recovery Codes',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save these codes in a safe place. You can use them to access your account if you lose access to your authenticator app.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._recoveryCodes!.map((code) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: SelectableText(
                            code,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 14),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          if (!_showRecoveryCodes) ...[
            ListTile(
              title: const Text('Regenerate Recovery Codes'),
              subtitle: const Text(
                  'Generate new recovery codes. Old codes will no longer work.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showRegenerateDialog(context, isDark),
            ),
            const Divider(),
            ListTile(
              title: const Text('Disable Two-Step Verification'),
              subtitle: const Text('Turn off two-step verification'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showDisableDialog(context, isDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisabledView(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: isDark ? const Color(0xFF202C33) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Two-step verification is disabled',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Two-step verification adds an extra layer of security to your account. When enabled, you\'ll need your password and an authentication code from your authenticator app to sign in.',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _startSetup(context, isDark),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Enable Two-Step Verification'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSetup(BuildContext context, bool isDark) async {
    try {
      final setup = await ref.read(twoFactorRepositoryProvider).setup();
      if (!mounted) return;

      // Show QR code and setup dialog
      showDialog(
        context: context,
        builder: (context) => _SetupDialog(
          setup: setup,
          isDark: isDark,
          onVerified: (code) async {
            Navigator.pop(context);
            try {
              final codes = await ref
                  .read(twoFactorRepositoryProvider)
                  .enable(code);
              if (!mounted) return;
              setState(() {
                _recoveryCodes = codes;
                _showRecoveryCodes = true;
              });
              ref.invalidate(twoFactorStatusProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Two-step verification enabled!')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to enable: $e')),
                );
              }
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to setup: $e')),
        );
      }
    }
  }

  void _showRegenerateDialog(BuildContext context, bool isDark) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: const Text('Regenerate Recovery Codes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your password to regenerate recovery codes. Old codes will no longer work.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final codes = await ref
                    .read(twoFactorRepositoryProvider)
                    .regenerateRecoveryCodes(_passwordController.text);
                if (!mounted) return;
                setState(() {
                  _recoveryCodes = codes;
                  _showRecoveryCodes = true;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Recovery codes regenerated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  void _showDisableDialog(BuildContext context, bool isDark) {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: const Text('Disable Two-Step Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to disable two-step verification? Your account will be less secure.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
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
                    .read(twoFactorRepositoryProvider)
                    .disable(_passwordController.text);
                if (!mounted) return;
                ref.invalidate(twoFactorStatusProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Two-step verification disabled')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
  }
}

class _SetupDialog extends StatefulWidget {
  final TwoFactorSetup setup;
  final bool isDark;
  final Function(String) onVerified;

  const _SetupDialog({
    required this.setup,
    required this.isDark,
    required this.onVerified,
  });

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF202C33) : Colors.white,
      title: const Text('Set Up Two-Step Verification'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.)',
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: widget.setup.qrCodeUrl,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Or enter this secret manually:',
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 12,
              ),
            ),
            SelectableText(
              widget.setup.secret,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 14, color: Colors.black),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Enter 6-digit code',
                border: OutlineInputBorder(),
                hintText: '000000',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_codeController.text.length == 6) {
              widget.onVerified(_codeController.text);
            }
          },
          child: const Text('Verify'),
        ),
      ],
    );
  }
}

