import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers.dart';
import '../../../core/api_service.dart';
import '../models.dart';
import '../chat_repo.dart';
import 'message_bubble.dart';
import '../../../theme/app_theme.dart';

final searchInConversationProvider =
    FutureProvider.family<List<Message>, Map<String, dynamic>>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.searchInConversation(
    params['conversationId'] as int,
    params['query'] as String,
  );
  final raw = response.data;
  final data = raw is Map && raw['data'] is List
      ? raw['data'] as List<dynamic>
      : (raw is List ? raw : []);
  return data.map((json) => Message.fromJson(json)).toList();
});

final searchInGroupProvider =
    FutureProvider.family<List<Message>, Map<String, dynamic>>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.searchInGroup(
    params['groupId'] as int,
    params['query'] as String,
  );
  final raw = response.data;
  final data = raw is Map && raw['data'] is List
      ? raw['data'] as List<dynamic>
      : (raw is List ? raw : []);
  return data.map((json) => Message.fromJson(json)).toList();
});

class SearchInChatScreen extends ConsumerStatefulWidget {
  final int? conversationId;
  final int? groupId;
  final String? title;

  const SearchInChatScreen({
    super.key,
    this.conversationId,
    this.groupId,
    this.title,
  }) : assert(conversationId != null || groupId != null);

  @override
  ConsumerState<SearchInChatScreen> createState() => _SearchInChatScreenState();
}

class _SearchInChatScreenState extends ConsumerState<SearchInChatScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final searchAsync = _query.isNotEmpty
        ? (widget.conversationId != null
            ? ref.watch(searchInConversationProvider({
                'conversationId': widget.conversationId!,
                'query': _query,
              }))
            : ref.watch(searchInGroupProvider({
                'groupId': widget.groupId!,
                'query': _query,
              })))
        : null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.title ?? 'Search'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _query = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              onSubmitted: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
          ),
        ),
      ),
      body: _query.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for messages',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : searchAsync == null
              ? const SizedBox.shrink()
              : searchAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: isDark ? Colors.white38 : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages found',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return MessageBubble(
                          message: message,
                          currentUserId: _currentUserId ?? 0,
                          onDelete: () {},
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text('Error searching: $error'),
                  ),
                ),
    );
  }
}

