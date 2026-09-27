import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../services/hidden_chat_service.dart';
import '../../../utils/snackbar_helper.dart';
import '../chat_providers.dart';
import '../models.dart';

/// Lists chats locked/hidden on this device after secret-code unlock.
class HiddenChatsVaultScreen extends ConsumerStatefulWidget {
  const HiddenChatsVaultScreen({super.key});

  @override
  ConsumerState<HiddenChatsVaultScreen> createState() => _HiddenChatsVaultScreenState();
}

class _HiddenChatsVaultScreenState extends ConsumerState<HiddenChatsVaultScreen> {
  bool _loading = true;
  List<ConversationSummary> _hidden = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ids = await ref.read(hiddenChatServiceProvider).hiddenConversationIds();
      final all = await ref.read(chatRepositoryProvider).getConversations();
      final matched = all.where((c) => ids.contains(c.id)).toList();
      // Include ids that may not be in main list anymore still by id only
      if (mounted) {
        setState(() {
          _hidden = matched;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        context.showErrorToast('Failed to load hidden chats: $e');
      }
    }
  }

  Future<void> _open(ConversationSummary c) async {
    ref.read(selectedConversationProvider.notifier).selectConversation(c.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _unhide(ConversationSummary c) async {
    await ref.read(hiddenChatServiceProvider).unhideConversation(c.id);
    if (mounted) {
      context.showInfoToast('Chat moved back to inbox');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2C34),
        title: const Text('Locked chats'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hidden.isEmpty
              ? const Center(
                  child: Text(
                    'No locked chats',
                    style: TextStyle(color: Color(0xFF8696A0)),
                  ),
                )
              : ListView.separated(
                  itemCount: _hidden.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF2A3942)),
                  itemBuilder: (context, index) {
                    final c = _hidden[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          c.otherUser.name.isNotEmpty
                              ? c.otherUser.name[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(c.otherUser.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        c.lastMessage ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF8696A0)),
                      ),
                      trailing: IconButton(
                        tooltip: 'Unlock chat',
                        icon: const Icon(Icons.lock_open, color: Color(0xFF00A884)),
                        onPressed: () => _unhide(c),
                      ),
                      onTap: () => _open(c),
                    );
                  },
                ),
    );
  }
}
