import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/feature_flags.dart';
import '../../core/providers.dart';
import '../chats/chat_repo.dart' show chatRepositoryProvider;

/// PHASE 2: AI Chat Screen - Enhanced AI assistant
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  bool _isStarting = false;

  Future<void> _startChatWithAI() async {
    if (_isStarting) return;
    
    setState(() => _isStarting = true);
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final chatRepo = ref.read(chatRepositoryProvider);
      
      // Search for the bot user by phone (0000000000)
      // The bot user has phone number 0000000000
      final searchResponse = await apiService.search(query: '0000000000');
      final searchData = searchResponse.data;
      
      int? botUserId;
      if (searchData is Map && searchData['data'] != null) {
        final users = searchData['data'] as List<dynamic>;
        // Find user with phone 0000000000
        for (final user in users) {
          if (user is Map && (user['phone'] == '0000000000' || user['phone'] == '+2330000000000')) {
            final id = user['id'];
            if (id is int) {
              botUserId = id;
            } else if (id is num) {
              botUserId = id.toInt();
            }
            break;
          }
        }
      }
      
      // If not found via search, try to find in existing conversations
      if (botUserId == null) {
        final conversations = await chatRepo.getConversations();
        for (final conv in conversations) {
          final phone = conv.otherUser.phone;
          if (phone != null && (phone == '0000000000' || phone == '+2330000000000')) {
            // Navigate to existing conversation
            if (mounted) {
              context.go('/chats');
              // Select the conversation - this will be handled by DesktopChatScreen
              // We need to trigger a conversation selection
              await Future.delayed(const Duration(milliseconds: 100));
              // The conversation should already be in the list, user can click it
            }
            return;
          }
        }
        
        // If still not found, try to resolve by phone
        try {
          final resolveResponse = await apiService.post('/contacts/resolve', data: {
            'phones': ['0000000000']
          });
          final resolveData = resolveResponse.data;
          if (resolveData is Map && resolveData['data'] != null) {
            final resolved = resolveData['data'] as List<dynamic>;
            if (resolved.isNotEmpty && resolved[0] is Map) {
              botUserId = resolved[0]['user_id'] as int?;
            }
          }
        } catch (e) {
          debugPrint('Failed to resolve bot user by phone: $e');
        }
      }
      
      if (botUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI assistant not found. Please contact support.')),
          );
        }
        return;
      }
      
      // Start conversation with bot user
      final conversationId = await chatRepo.startConversation(botUserId);
      
      // Navigate to chats - the conversation will appear in the list
      if (mounted) {
        context.go('/chats');
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI chat started! Conversation ID: $conversationId'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                // The conversation should appear in the list automatically
                // User can click on it to open
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting AI chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start AI chat: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final advancedAiEnabled = featureEnabled(ref, 'advanced_ai');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: advancedAiEnabled
          ? _buildEmptyState(context, isDark)
          : _buildFeatureDisabledState(context, isDark),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Your AI assistant',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[800],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask questions, write messages, or get help anytime.',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isStarting ? null : _startChatWithAI,
              icon: _isStarting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.chat),
              label: Text(_isStarting ? 'Starting...' : 'Start Chat with AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008069),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureDisabledState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
    );
  }
}

