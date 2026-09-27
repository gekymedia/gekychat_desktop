import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/hidden_chat_service.dart';
import '../../../utils/snackbar_helper.dart';
import 'hidden_chats_vault_screen.dart';

/// WhatsApp-style intro + secret-code setup for Hidden Chat.
class HiddenChatSetupFlow {
  HiddenChatSetupFlow._();

  static Future<void> start(
    BuildContext context,
    WidgetRef ref, {
    int? conversationIdToHide,
  }) async {
    final service = ref.read(hiddenChatServiceProvider);
    final hasCode = await service.hasSecretCode();
    if (!context.mounted) return;

    if (!hasCode) {
      final continueSetup = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1F2C34),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => const _HiddenChatIntroSheet(),
      );
      if (continueSetup != true || !context.mounted) return;

      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const HiddenChatCodeScreen(mode: HiddenChatCodeMode.create)),
      );
      if (code == null || code.isEmpty || !context.mounted) return;
      try {
        await service.setSecretCode(code);
      } catch (e) {
        if (context.mounted) context.showErrorToast('$e');
        return;
      }
    }

    if (conversationIdToHide != null && conversationIdToHide > 0) {
      await service.hideConversation(conversationIdToHide);
      if (context.mounted) {
        context.showInfoToast('Chat locked and hidden on this device');
      }
    } else if (context.mounted) {
      await openVault(context, ref);
    }
  }

  static Future<void> openVault(BuildContext context, WidgetRef ref) async {
    final service = ref.read(hiddenChatServiceProvider);
    final hasCode = await service.hasSecretCode();
    if (!context.mounted) return;
    if (!hasCode) {
      await start(context, ref);
      return;
    }
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const HiddenChatCodeScreen(mode: HiddenChatCodeMode.unlock),
      ),
    );
    if (ok == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HiddenChatsVaultScreen()),
      );
    }
  }
}

class _HiddenChatIntroSheet extends StatelessWidget {
  const _HiddenChatIntroSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00A884).withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.lock, size: 56, color: Color(0xFF00A884)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Keep this chat locked and hidden',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Use a secret code on this device to open locked chats. Locked chats stay separate from your main inbox.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum HiddenChatCodeMode { create, unlock }

class HiddenChatCodeScreen extends ConsumerStatefulWidget {
  const HiddenChatCodeScreen({super.key, required this.mode});

  final HiddenChatCodeMode mode;

  @override
  ConsumerState<HiddenChatCodeScreen> createState() => _HiddenChatCodeScreenState();
}

class _HiddenChatCodeScreenState extends ConsumerState<HiddenChatCodeScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final code = _controller.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter at least 4 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.mode == HiddenChatCodeMode.create) {
        if (!mounted) return;
        Navigator.pop(context, code);
        return;
      }
      final ok = await ref.read(hiddenChatServiceProvider).verifySecretCode(code);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _busy = false;
          _error = 'Incorrect secret code';
        });
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == HiddenChatCodeMode.create;
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B141A),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Chat lock'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _busy ? null : _continue,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 72, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              isCreate ? 'Create your secret code' : 'Enter your secret code',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Secret code',
                hintStyle: const TextStyle(color: Color(0xFF8696A0)),
                filled: true,
                fillColor: const Color(0xFF1F2C34),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _continue(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            if (!isCreate) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  context.showInfoToast(
                    'If you forget the code, clear app data to reset Hidden Chat on this device.',
                  );
                },
                child: const Text(
                  'Forgot secret code?',
                  style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
