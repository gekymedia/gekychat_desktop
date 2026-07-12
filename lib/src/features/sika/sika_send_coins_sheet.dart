import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'sika_providers.dart';
import 'sika_repository.dart';
import '../../utils/snackbar_helper.dart';

class SikaSendCoinsSheet extends ConsumerStatefulWidget {
  final bool isGift;
  final int? preselectedUserId;
  final String? preselectedUserName;
  final int? postId;
  final int? messageId;

  const SikaSendCoinsSheet({
    super.key,
    this.isGift = false,
    this.preselectedUserId,
    this.preselectedUserName,
    this.postId,
    this.messageId,
  });

  @override
  ConsumerState<SikaSendCoinsSheet> createState() => _SikaSendCoinsSheetState();
}

class _SikaSendCoinsSheetState extends ConsumerState<SikaSendCoinsSheet> {
  final _coinsController = TextEditingController();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();

  int? _selectedUserId;
  String? _selectedUserName;
  bool _isSending = false;
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

  final List<int> _quickAmounts = [10, 50, 100, 500, 1000];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedUserId != null) {
      _selectedUserId = widget.preselectedUserId;
      _selectedUserName = widget.preselectedUserName;
    }
  }

  @override
  void dispose() {
    _coinsController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(sikaWalletProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    widget.isGift ? 'Send Gift' : 'Send Coins',
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
            const SizedBox(height: 8),
            walletAsync.when(
              data: (data) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'Balance: ${_formatNumber(data.wallet.balance)} coins',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  if (_selectedUserId == null) ...[
                    Text(
                      'Recipient',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                      ),
                      onChanged: _searchContacts,
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final contact = _searchResults[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: contact['avatar'] != null
                                    ? NetworkImage(contact['avatar'])
                                    : null,
                                child: contact['avatar'] == null
                                    ? Text(
                                        (contact['name'] as String? ?? 'U')[0]
                                            .toUpperCase(),
                                      )
                                    : null,
                              ),
                              title: Text(contact['name'] ?? 'Unknown'),
                              subtitle: Text(contact['phone'] ?? ''),
                              onTap: () {
                                setState(() {
                                  _selectedUserId = contact['id'];
                                  _selectedUserName = contact['name'];
                                  _searchResults = [];
                                  _searchController.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.primary,
                            child: Text(
                              (_selectedUserName ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sending to',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  _selectedUserName ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.preselectedUserId == null)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _selectedUserId = null;
                                  _selectedUserName = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _coinsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('🪙', style: TextStyle(fontSize: 20)),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAmounts.map((amount) {
                      final isSelected =
                          _coinsController.text == amount.toString();
                      return ChoiceChip(
                        label: Text('$amount'),
                        selected: isSelected,
                        onSelected: (_) {
                          _coinsController.text = amount.toString();
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Note (optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: widget.isGift
                          ? 'Add a message with your gift...'
                          : 'Add a note...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + (keyboardHeight > 0 ? 0 : MediaQuery.of(context).padding.bottom),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSend() && !_isSending ? _sendCoins : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: widget.isGift ? Colors.pink : null,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isGift
                                  ? Icons.card_giftcard
                                  : Icons.send,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isGift ? 'Send Gift' : 'Send Coins',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canSend() {
    if (_selectedUserId == null) return false;
    final coins = int.tryParse(_coinsController.text) ?? 0;
    return coins > 0;
  }

  Future<void> _searchContacts(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/contacts', queryParameters: {
        'search': query,
        'limit': 10,
      });

      if (!mounted) return;

      setState(() {
        _searchResults = response.data['data'] as List? ?? [];
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendCoins() async {
    if (!_canSend()) return;

    final coins = int.parse(_coinsController.text);

    setState(() {
      _isSending = true;
    });

    try {
      final repo = ref.read(sikaRepositoryProvider);

      if (widget.isGift) {
        final result = await repo.gift(
          toUserId: _selectedUserId,
          postId: widget.postId,
          messageId: widget.messageId,
          coins: coins,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );

        ref.read(sikaWalletNotifierProvider.notifier).updateBalance(result.newBalance);
      } else {
        final result = await repo.transfer(
          toUserId: _selectedUserId!,
          coins: coins,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );

        ref.read(sikaWalletNotifierProvider.notifier).updateBalance(result.newBalance);
      }

      ref.invalidate(sikaWalletProvider);

      if (!mounted) return;

      Navigator.pop(context);

            context.showSuccessToast(
            widget.isGift
                ? 'Gift of $coins coins sent to $_selectedUserName!'
                : '$coins coins sent to $_selectedUserName!',
          );    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Failed to send coins. Please try again.';
      Color backgroundColor = Colors.red;
      
      if (e is SikaApiException) {
        if (e.isInsufficientBalance) {
          errorMessage = 'Insufficient coin balance. You don\'t have enough Sika Coins.';
          backgroundColor = Colors.orange.shade700;
        } else if (e.errorCode == 'SELF_TRANSFER') {
          errorMessage = 'You cannot send coins to yourself.';
        } else {
          errorMessage = e.message;
        }
      } else if (e.toString().contains('INSUFFICIENT_BALANCE') ||
          e.toString().contains('Insufficient balance')) {
        errorMessage = 'Insufficient coin balance. You don\'t have enough Sika Coins.';
        backgroundColor = Colors.orange.shade700;
      } else if (e.toString().contains('SELF_TRANSFER')) {
        errorMessage = 'You cannot send coins to yourself.';
      }

            context.showErrorToast(errorMessage);    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
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
