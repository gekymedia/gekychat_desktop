import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_repository.dart';
import '../../core/providers.dart';
import '../chats/chat_providers.dart';
import '../../utils/search_history_manager.dart';
import '../../widgets/skeleton_loader.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Map<String, dynamic>? _searchResults;
  bool _isLoading = false;
  List<String> _selectedFilters = [];
  List<String> _searchHistory = [];
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;
  SearchHistoryManager? _historyManager;

  @override
  void initState() {
    super.initState();
    _initSearchHistory();
    _focusNode.addListener(_onFocusChange);
    final iq = widget.initialQuery?.trim();
    if (iq != null && iq.isNotEmpty) {
      _searchController.text = iq;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _performSearch(iq);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() {
        _showSuggestions = true;
      });
    }
  }

  Future<void> _initSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _historyManager = SearchHistoryManager(prefs);
    final history = await _historyManager!.getSearchHistory();
    setState(() {
      _searchHistory = history;
      _searchSuggestions = history;
    });
  }

  Future<void> _updateSuggestions(String query) async {
    if (_historyManager == null) return;
    
    final suggestions = await _historyManager!.getSearchSuggestions(query);
    setState(() {
      _searchSuggestions = suggestions;
      _showSuggestions = true;
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _showSuggestions = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });

    // Add to search history
    if (_historyManager != null) {
      await _historyManager!.addSearchQuery(query);
    }

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
          focusNode: _focusNode,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Search messages, contacts, groups...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: isDark ? Colors.white : Colors.black),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = null;
                        _showSuggestions = true;
                      });
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            _updateSuggestions(value);
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_searchController.text == value) {
                _performSearch(value);
              }
            });
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _performSearch(value);
            }
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
          ? const SkeletonList(
              skeletonItem: SkeletonContactItem(),
              itemCount: 8,
            )
          : _showSuggestions && _searchController.text.isEmpty
              ? _buildSearchHistory(context, isDark)
              : _searchResults == null
                  ? _buildEmptyState(context, isDark)
                  : _buildResults(context, isDark),
    );
  }

  Widget _buildResults(BuildContext context, bool isDark) {
    final results = _normalizeSearchResults(_searchResults);

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedFilters.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedFilters.clear();
                  });
                  _performSearch(_searchController.text);
                },
                icon: const Icon(Icons.filter_list_off),
                label: const Text('Clear Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF008069),
                ),
              ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (results['conversations'] != null &&
            results['conversations']!.isNotEmpty)
          ..._buildSection(
            'Conversations',
            Icons.chat,
            results['conversations']!,
            isDark,
          ),
        if (results['contacts'] != null && results['contacts']!.isNotEmpty)
          ..._buildSection('Contacts', Icons.person, results['contacts']!, isDark),
        if (results['users'] != null && results['users']!.isNotEmpty)
          ..._buildSection('People', Icons.people, results['users']!, isDark),
        if (results['groups'] != null && results['groups']!.isNotEmpty)
          ..._buildSection('Groups', Icons.group, results['groups']!, isDark),
        if (results['messages'] != null && results['messages']!.isNotEmpty)
          ..._buildSection('Messages', Icons.message, results['messages']!, isDark),
      ],
    );
  }

  /// API returns a flat scored list; older clients used a grouped map.
  Map<String, List<dynamic>> _normalizeSearchResults(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return {};
    final resultsRaw = raw['results'];
    if (resultsRaw is List) {
      final grouped = <String, List<dynamic>>{};
      for (final item in resultsRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final type = map['type']?.toString() ?? 'unknown';
        final bucket = switch (type) {
          'contact' => 'contacts',
          'user' => 'users',
          'group' => 'groups',
          'message' => 'messages',
          'conversation' => 'conversations',
          _ => 'other',
        };
        grouped.putIfAbsent(bucket, () => []).add(map);
      }
      return grouped;
    }
    if (resultsRaw is Map) {
      return Map<String, List<dynamic>>.from(
        resultsRaw.map(
          (key, value) => MapEntry(
            key.toString(),
            value is List ? value : [value],
          ),
        ),
      );
    }
    return {};
  }

  String _itemName(Map<String, dynamic> item) {
    var name = item['name']?.toString() ??
        item['display_name']?.toString() ??
        item['title']?.toString();
    if ((name == null || name.isEmpty) && item['user'] is Map) {
      name = (item['user'] as Map)['name']?.toString();
    }
    if ((name == null || name.isEmpty) && item['contact'] is Map) {
      name = (item['contact'] as Map)['display_name']?.toString();
    }
    if ((name == null || name.isEmpty) && item['group'] is Map) {
      name = (item['group'] as Map)['name']?.toString();
    }
    return name?.isNotEmpty == true ? name! : 'Unknown';
  }

  String _itemSubtitle(Map<String, dynamic> item) {
    final body = item['body']?.toString() ??
        item['snippet']?.toString() ??
        item['last_message']?.toString();
    if (body != null && body.isNotEmpty) return body;
    final phone = item['phone']?.toString();
    if (phone != null && phone.isNotEmpty) return phone;
    if (item['user'] is Map) {
      return (item['user'] as Map)['phone']?.toString() ?? '';
    }
    return '';
  }

  String? _itemAvatar(Map<String, dynamic> item) {
    final direct = item['avatar_url']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    if (item['user'] is Map) {
      return (item['user'] as Map)['avatar_url']?.toString();
    }
    if (item['group'] is Map) {
      return (item['group'] as Map)['avatar_url']?.toString();
    }
    return null;
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
      ...items.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        final name = _itemName(item);
        final subtitle = _itemSubtitle(item);
        final avatarUrl = _itemAvatar(item);
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(name),
          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
          onTap: () => _navigateToItem(context, ref, item, title),
        );
      }),
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
      final type = item['type']?.toString();
      if (type == 'group' || section == 'Groups') {
        final groupId = _parseGroupId(item);
        if (groupId != null) {
          _navigateToGroup(context, ref, groupId);
        }
        return;
      }

      if (type == 'message' || section == 'Messages') {
        final groupId = _asInt(item['group_id']);
        final conversationId = _asInt(item['conversation_id']);
        if (groupId != null) {
          _navigateToGroup(context, ref, groupId);
        } else if (conversationId != null) {
          _navigateToConversation(context, ref, conversationId);
        }
        return;
      }

      final conversationId = _parseConversationId(item);
      if (conversationId != null) {
        _navigateToConversation(context, ref, conversationId);
        return;
      }

      final userId = _parseUserId(item);
      if (userId != null) {
        _startConversation(context, ref, userId, _itemName(item));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to navigate: $e')),
      );
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  int? _parseConversationId(Map<String, dynamic> item) {
    final direct = _asInt(item['conversation_id']);
    if (direct != null) return direct;
    if (item['conversation'] is Map) {
      return _asInt((item['conversation'] as Map)['id']);
    }
    final id = item['id']?.toString();
    if (id != null && id.startsWith('conversation_')) {
      return int.tryParse(id.replaceFirst('conversation_', ''));
    }
    return null;
  }

  int? _parseGroupId(Map<String, dynamic> item) {
    final direct = _asInt(item['group_id']);
    if (direct != null) return direct;
    if (item['group'] is Map) {
      return _asInt((item['group'] as Map)['id']);
    }
    final id = item['id']?.toString();
    if (id != null && id.startsWith('group_')) {
      return int.tryParse(id.replaceFirst('group_', ''));
    }
    return _asInt(item['id']);
  }

  int? _parseUserId(Map<String, dynamic> item) {
    if (item['user'] is Map) {
      final id = _asInt((item['user'] as Map)['id']);
      if (id != null) return id;
    }
    final id = item['id']?.toString();
    if (id != null && id.startsWith('user_')) {
      return int.tryParse(id.replaceFirst('user_', ''));
    }
    return _asInt(item['user_id'] ?? item['id']);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _navigateToGroup(BuildContext context, WidgetRef ref, int groupId) async {
    try {
      ref.read(currentSectionProvider.notifier).setSection('/chats');
      ref.read(pendingDesktopGroupSelectProvider.notifier).state = groupId;
      context.go('/chats');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to navigate to group: $e')),
        );
      }
    }
  }

  Widget _buildSearchHistory(BuildContext context, bool isDark) {
    if (_searchHistory.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () async {
                await _historyManager?.clearSearchHistory();
                setState(() {
                  _searchHistory = [];
                  _searchSuggestions = [];
                });
              },
              child: const Text(
                'Clear All',
                style: TextStyle(
                  color: Color(0xFF008069),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._searchHistory.map((query) => ListTile(
          leading: const Icon(Icons.history, color: Colors.grey),
          title: Text(
            query,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () async {
              await _historyManager?.removeSearchQuery(query);
              final history = await _historyManager?.getSearchHistory() ?? [];
              setState(() {
                _searchHistory = history;
                _searchSuggestions = history;
              });
            },
          ),
          onTap: () {
            _searchController.text = query;
            _performSearch(query);
          },
        )),
        const SizedBox(height: 24),
        _buildQuickFilters(context, isDark),
      ],
    );
  }

  Widget _buildQuickFilters(BuildContext context, bool isDark) {
    final filters = [
      {'label': 'Messages', 'icon': Icons.message, 'value': 'messages'},
      {'label': 'Contacts', 'icon': Icons.person, 'value': 'contacts'},
      {'label': 'Groups', 'icon': Icons.group, 'value': 'groups'},
      {'label': 'Media', 'icon': Icons.photo, 'value': 'media'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search in',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((filter) {
            final isSelected = _selectedFilters.contains(filter['value']);
            return FilterChip(
              avatar: Icon(
                filter['icon'] as IconData,
                size: 18,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
              ),
              label: Text(
                filter['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF008069),
              backgroundColor: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedFilters.add(filter['value'] as String);
                  } else {
                    _selectedFilters.remove(filter['value']);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Search GekyChat',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find messages, contacts, groups, and more',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

