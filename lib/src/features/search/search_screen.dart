import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'search_repository.dart';
import '../../core/providers.dart';
import '../chats/chat_repo.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Map<String, dynamic>? _searchResults;
  bool _isLoading = false;
  List<String> _selectedFilters = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final searchRepo = ref.read(searchRepositoryProvider);
      final results = await searchRepo.search(
        query: query,
        filters: _selectedFilters.isEmpty ? null : _selectedFilters,
        limit: 50,
      );
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_searchController.text == value) {
                _performSearch(value);
              }
            });
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _showFilterDialog(context, ref),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults == null
              ? Center(
                  child: Text(
                    'Start typing to search...',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                )
              : _buildResults(context, isDark),
    );
  }

  Widget _buildResults(BuildContext context, bool isDark) {
    final results = _searchResults?['results'] as Map<String, dynamic>? ?? {};

    if (results.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (results['contacts'] != null && (results['contacts'] as List).isNotEmpty)
          ..._buildSection('Contacts', Icons.person, results['contacts'] as List, isDark),
        if (results['users'] != null && (results['users'] as List).isNotEmpty)
          ..._buildSection('People', Icons.people, results['users'] as List, isDark),
        if (results['groups'] != null && (results['groups'] as List).isNotEmpty)
          ..._buildSection('Groups', Icons.group, results['groups'] as List, isDark),
        if (results['messages'] != null && (results['messages'] as List).isNotEmpty)
          ..._buildSection('Messages', Icons.message, results['messages'] as List, isDark),
      ],
    );
  }

  List<Widget> _buildSection(String title, IconData icon, List items, bool isDark) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
      ...items.map((item) => ListTile(
            leading: CircleAvatar(
              child: item['avatar_url'] != null
                  ? null
                  : Text((item['name'] ?? item['title'] ?? '?')[0].toUpperCase()),
              backgroundImage: item['avatar_url'] != null
                  ? CachedNetworkImageProvider(item['avatar_url'])
                  : null,
            ),
            title: Text(item['name'] ?? item['title'] ?? 'Unknown'),
            subtitle: Text(item['phone'] ?? item['body'] ?? ''),
            onTap: () => _navigateToItem(context, ref, item, title),
          )),
    ];
  }

  Future<void> _showFilterDialog(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<String> selectedFilters = List.from(_selectedFilters);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getSearchFilters();
      final availableFilters = (response.data['available_filters'] as List?) ?? [];

      final result = await showDialog<List<String>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
            title: Text(
              'Search Filters',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: availableFilters.map<Widget>((filter) {
                  final key = filter['key'] as String;
                  final label = filter['label'] as String;
                  final isSelected = selectedFilters.contains(key);
                  
                  return CheckboxListTile(
                    title: Text(
                      label,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedFilters.add(key);
                        } else {
                          selectedFilters.remove(key);
                        }
                      });
                    },
                    activeColor: const Color(0xFF008069),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, selectedFilters),
                child: const Text('Apply', style: TextStyle(color: Color(0xFF008069))),
              ),
            ],
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _selectedFilters = result;
        });
        
        // Re-perform search with new filters
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load filters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToItem(BuildContext context, WidgetRef ref, Map<String, dynamic> item, String section) {
    try {
      if (section == 'Contacts' || section == 'People') {
        // Navigate to conversation or user profile
        final userId = item['id'] ?? item['user_id'];
        if (userId != null) {
          // Try to start conversation
          _startConversation(context, ref, userId, item['name'] ?? 'User');
        }
      } else if (section == 'Groups') {
        // Navigate to group chat
        final groupId = item['id'];
        if (groupId != null) {
          _navigateToGroup(context, ref, groupId);
        }
      } else if (section == 'Messages') {
        // Navigate to conversation and scroll to message
        final conversationId = item['conversation_id'];
        final groupId = item['group_id'];
        if (groupId != null) {
          _navigateToGroup(context, ref, groupId);
        } else if (conversationId != null) {
          _navigateToConversation(context, ref, conversationId);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to navigate: $e')),
      );
    }
  }

  Future<void> _startConversation(BuildContext context, WidgetRef ref, int userId, String userName) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      // Try to find existing conversation first
      final conversations = await chatRepo.getConversations();
      try {
        final existingConversation = conversations.firstWhere(
          (c) => c.otherUser.id == userId,
        );
        _navigateToConversation(context, ref, existingConversation.id);
      } catch (e) {
        // If no conversation exists, create one
        final conversationId = await chatRepo.startConversation(userId);
        _navigateToConversation(context, ref, conversationId);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start conversation: $e')),
        );
      }
    }
  }

  void _navigateToConversation(BuildContext context, WidgetRef ref, int conversationId) {
    ref.read(currentSectionProvider.notifier).setSection('/chats');
    ref.read(selectedConversationProvider.notifier).selectConversation(conversationId);
    context.go('/chats');
  }

  Future<void> _navigateToGroup(BuildContext context, WidgetRef ref, int groupId) async {
    try {
      ref.read(currentSectionProvider.notifier).setSection('/chats');
      // Select group - this will be handled by DesktopChatScreen
      context.go('/chats');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select the group from the groups list'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to navigate to group: $e')),
        );
      }
    }
  }
}

