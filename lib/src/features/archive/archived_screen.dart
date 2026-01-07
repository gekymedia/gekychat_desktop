import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chats/chat_repo.dart';
import '../chats/models.dart';
import '../chats/widgets/conversation_list_item.dart';
import '../chats/widgets/chat_view.dart';

final archivedConversationsProvider = FutureProvider<List<ConversationSummary>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  return await repo.getArchivedConversations();
});

class ArchivedConversationsScreen extends ConsumerStatefulWidget {
  const ArchivedConversationsScreen({super.key});

  @override
  ConsumerState<ArchivedConversationsScreen> createState() => _ArchivedConversationsScreenState();
}

class _ArchivedConversationsScreenState extends ConsumerState<ArchivedConversationsScreen> {
  ConversationSummary? _selectedConversation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final archivedAsync = ref.watch(archivedConversationsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Archived Chats'),
      ),
      body: archivedAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No archived chats',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Long press a chat to archive it',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return Row(
            children: [
              // Sidebar with archived conversations
              Container(
                width: 400,
                color: isDark ? const Color(0xFF111B21) : Colors.white,
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF202C33) : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Archived',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Conversations list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(archivedConversationsProvider);
                        },
                        child: ListView.builder(
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            return ConversationListItem(
                              conversation: conversation,
                              isSelected: _selectedConversation?.id == conversation.id,
                              onTap: () {
                                setState(() {
                                  _selectedConversation = conversation;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                width: 1,
                color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
              ),
              // Chat view
              Expanded(
                child: _selectedConversation != null
                    ? ChatView(
                        conversationId: _selectedConversation!.id,
                        contactName: _selectedConversation!.otherUser.name,
                        contactAvatar: _selectedConversation!.otherUser.avatarUrl,
                      )
                    : Center(
                        child: Text(
                          'Select a conversation',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading archived conversations',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(archivedConversationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

