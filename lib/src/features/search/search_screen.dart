import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'search_repository.dart';

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
            onPressed: () {
              // TODO: Show filter dialog
            },
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
                  : Text((item['name'] ?? '?')[0].toUpperCase()),
              backgroundImage: item['avatar_url'] != null
                  ? CachedNetworkImageProvider(item['avatar_url'])
                  : null,
            ),
            title: Text(item['name'] ?? item['title'] ?? 'Unknown'),
            subtitle: Text(item['phone'] ?? item['body'] ?? ''),
            onTap: () {
              // TODO: Navigate to appropriate screen
            },
          )),
    ];
  }
}

