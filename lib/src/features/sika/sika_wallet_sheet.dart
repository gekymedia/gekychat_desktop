import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/snackbar_helper.dart';
import 'sika_providers.dart';
import 'sika_repository.dart';
import 'sika_send_coins_sheet.dart';

const _sikaTermsAcceptedKey = 'sika_wallet_terms_accepted_v1';
const _sikaTermsUrl = 'https://gekychat.com/terms-of-service';

/// Wallet hub opened from the chat attachment menu.
class SikaWalletSheet extends ConsumerStatefulWidget {
  final int? preselectedUserId;
  final String? preselectedUserName;

  const SikaWalletSheet({
    super.key,
    this.preselectedUserId,
    this.preselectedUserName,
  });

  @override
  ConsumerState<SikaWalletSheet> createState() => _SikaWalletSheetState();
}

class _SikaWalletSheetState extends ConsumerState<SikaWalletSheet> {
  bool _termsAccepted = false;
  bool _termsLoaded = false;
  bool _isPurchasing = false;
  int? _selectedPackId;

  @override
  void initState() {
    super.initState();
    _loadTermsAcceptance();
  }

  Future<void> _loadTermsAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _termsAccepted = prefs.getBool(_sikaTermsAcceptedKey) ?? false;
      _termsLoaded = true;
    });
  }

  Future<void> _setTermsAccepted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sikaTermsAcceptedKey, value);
    if (!mounted) return;
    setState(() => _termsAccepted = value);
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse(_sikaTermsUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openSend({bool isGift = false}) {
    if (!_termsAccepted) {
      context.showInfoToast('Please accept the Sika Wallet terms first');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, _) => SikaSendCoinsSheet(
          isGift: isGift,
          preselectedUserId: widget.preselectedUserId,
          preselectedUserName: widget.preselectedUserName,
        ),
      ),
    );
  }

  Future<void> _purchasePack(int packId) async {
    if (!_termsAccepted) {
      context.showInfoToast('Please accept the Sika Wallet terms first');
      return;
    }
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _selectedPackId = packId;
    });

    try {
      final repo = ref.read(sikaRepositoryProvider);
      await repo.purchasePack(packId);
      ref.invalidate(sikaWalletProvider);
      ref.invalidate(sikaPacksProvider);
      if (!mounted) return;
      context.showSuccessToast('Coins purchased successfully');
    } catch (e) {
      if (!mounted) return;
      final message = e is SikaApiException
          ? e.message
          : 'Purchase failed. Please try again.';
      context.showErrorToast(message);
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _selectedPackId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final walletAsync = ref.watch(sikaWalletProvider);
    final packsAsync = ref.watch(sikaPacksProvider);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Sika Wallet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  walletAsync.when(
                    data: (data) => _BalanceCard(
                      balance: data.wallet.balance,
                      status: data.wallet.status,
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const _BalanceCard(balance: 0, status: 'unknown'),
                  ),
                  const SizedBox(height: 16),
                  if (_termsLoaded)
                    _TermsCard(
                      accepted: _termsAccepted,
                      onChanged: _setTermsAccepted,
                      onOpenTerms: _openTerms,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openSend(isGift: false),
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openSend(isGift: true),
                          icon: const Icon(Icons.card_giftcard_rounded),
                          label: const Text('Gift'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Buy Coin Packs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Paid with Priority Bank on web. Apple Pay and Google Pay will be available through App Store / Play Billing on mobile builds.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 12),
                  packsAsync.when(
                    data: (packs) {
                      if (packs.isEmpty) {
                        return Text(
                          'No coin packs available right now.',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        );
                      }
                      return Column(
                        children: packs.map((pack) {
                          final busy =
                              _isPurchasing && _selectedPackId == pack.id;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const Icon(
                                Icons.monetization_on_rounded,
                                color: Color(0xFFFFB300),
                              ),
                              title: Text(
                                '${_formatNumber(pack.coins)} coins',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                pack.bonusCoins > 0
                                    ? 'GHS ${pack.priceGhs.toStringAsFixed(2)} · +${pack.bonusCoins} bonus'
                                    : 'GHS ${pack.priceGhs.toStringAsFixed(2)}',
                              ),
                              trailing: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : FilledButton(
                                      onPressed: _termsAccepted && !_isPurchasing
                                          ? () => _purchasePack(pack.id)
                                          : null,
                                      child: const Text('Buy'),
                                    ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => Text(
                      'Could not load coin packs.',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.status});

  final int balance;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Your Balance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _format(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sika Coins · ${status.isEmpty ? 'active' : status}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _format(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({
    required this.accepted,
    required this.onChanged,
    required this.onOpenTerms,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: accepted,
            onChanged: (value) => onChanged(value ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'I agree to the Sika Wallet terms: coins are virtual, non-refundable except where required by law, and purchases are final.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onOpenTerms,
                    child: Text(
                      'View full Terms',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
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
}
