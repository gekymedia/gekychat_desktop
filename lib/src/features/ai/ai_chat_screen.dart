import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/feature_flags.dart';
import '../../core/providers.dart';
import '../chats/chat_providers.dart';
import '../chats/models.dart';
import '../chats/widgets/chat_view.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/gekychat_ai_icon.dart';

/// Opens directly into the GekyChat AI conversation (no intermediate start screen).
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  bool _isLoading = true;
  ConversationSummary? _conversation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAiChat();
    });
  }

  Future<void> _initializeAiChat() async {
    if (!featureEnabled(ref, 'advanced_ai')) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/ai/conversation');
      final data = response.data;

      final payload = data is Map
          ? (data['data'] is Map ? data['data'] : data)
          : null;

      final conversationIdRaw = payload?['conversation_id'];
      final conversationId = conversationIdRaw is int
          ? conversationIdRaw
          : (conversationIdRaw is num
              ? conversationIdRaw.toInt()
              : int.tryParse('$conversationIdRaw'));

      if (conversationId == null) {
        throw StateError('Invalid response');
      }

      final chatRepo = ref.read(chatRepositoryProvider);
      final conversation = await chatRepo.getConversation(conversationId);

      if (!mounted) return;

      ref
          .read(selectedConversationProvider.notifier)
          .selectConversation(conversationId);

      setState(() {
        _conversation = conversation;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing AI chat: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to start AI chat. Please try again.';
        });
        context.showErrorToast('Failed to start AI chat. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final advancedAiEnabled = featureEnabled(ref, 'advanced_ai');

    if (!advancedAiEnabled) {
      return _buildFeatureDisabledState(context, isDark);
    }

    if (_isLoading) {
      return ColoredBox(
        color: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_conversation != null) {
      final conversation = _conversation!;
      return ChatView(
        key: ValueKey('ai-chat-${conversation.id}'),
        conversationId: conversation.id,
        contactName: conversation.otherUser.name.isNotEmpty
            ? conversation.otherUser.name
            : 'GekyChat AI',
        contactAvatar: conversation.otherUser.avatarUrl,
        otherUser: conversation.otherUser,
      );
    }

    return _buildErrorState(context, isDark);
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return ColoredBox(
      color: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GekyChatAiIcon(size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Failed to start AI chat',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[800],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeAiChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008069),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureDisabledState(BuildContext context, bool isDark) {
    return ColoredBox(
      color: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'AI Assistant is unavailable',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[800],
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This feature is not available at the moment.',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
