import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage search history and suggestions
class SearchHistoryService {
  static const String _searchHistoryKey = 'world_search_history';
  static const String _searchClicksKey = 'world_search_clicks';
  static const int _maxHistoryItems = 50;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save a search query
  Future<void> saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;

    final p = await prefs;
    final history = await getSearchHistory();

    // Remove if already exists (to move to top)
    history.remove(query);

    // Add to beginning
    history.insert(0, query);

    // Limit size
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    await p.setStringList(_searchHistoryKey, history);
  }

  /// Get search history
  Future<List<String>> getSearchHistory() async {
    final p = await prefs;
    return p.getStringList(_searchHistoryKey) ?? [];
  }

  /// Clear search history
  Future<void> clearSearchHistory() async {
    final p = await prefs;
    await p.remove(_searchHistoryKey);
  }

  /// Remove one recent search (TikTok-style X on history row).
  Future<void> removeSearchQuery(String query) async {
    final p = await prefs;
    final history = await getSearchHistory();
    history.removeWhere((q) => q == query);
    await p.setStringList(_searchHistoryKey, history);
  }

  /// Save what user clicked after searching
  Future<void> saveSearchClick({
    required String query,
    required String clickedType, // 'user', 'video', 'hashtag', 'post'
    required String clickedId,
  }) async {
    final p = await prefs;
    final clicks = await _getSearchClicks();

    final key = '${query.toLowerCase()}:$clickedType:$clickedId';
    clicks[key] = (clicks[key] ?? 0) + 1;

    // Convert to string list for storage
    final clicksList = clicks.entries
        .map((e) => '${e.key}=${e.value}')
        .toList();

    await p.setStringList(_searchClicksKey, clicksList);
  }

  /// Get search suggestions based on history and clicks
  Future<List<SearchSuggestion>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      // Return recent searches
      final history = await getSearchHistory();
      return history
          .take(10)
          .map(
            (q) => SearchSuggestion(
              text: q,
              type: SearchSuggestionType.recent,
              score: 0,
            ),
          )
          .toList();
    }

    final history = await getSearchHistory();
    final clicks = await _getSearchClicks();
    final suggestions = <SearchSuggestion>[];

    // Filter history by query
    for (final item in history) {
      if (item.toLowerCase().contains(query.toLowerCase())) {
        // Calculate score based on clicks
        int score = 0;
        clicks.forEach((key, count) {
          if (key.startsWith('${item.toLowerCase()}:')) {
            score += count;
          }
        });

        suggestions.add(
          SearchSuggestion(
            text: item,
            type: SearchSuggestionType.history,
            score: score,
          ),
        );
      }
    }

    // Sort by score (most clicked first)
    suggestions.sort((a, b) => b.score.compareTo(a.score));

    return suggestions.take(10).toList();
  }

  /// Get trending searches (most clicked)
  Future<List<String>> getTrendingSearches({int limit = 10}) async {
    final clicks = await _getSearchClicks();

    // Group by query
    final queryScores = <String, int>{};
    clicks.forEach((key, count) {
      final query = key.split(':').first;
      queryScores[query] = (queryScores[query] ?? 0) + count;
    });

    // Sort by score
    final sorted = queryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  Future<Map<String, int>> _getSearchClicks() async {
    final p = await prefs;
    final clicksList = p.getStringList(_searchClicksKey) ?? [];

    final clicks = <String, int>{};
    for (final item in clicksList) {
      final parts = item.split('=');
      if (parts.length == 2) {
        clicks[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }

    return clicks;
  }
}

class SearchSuggestion {
  final String text;
  final SearchSuggestionType type;
  final int score;

  SearchSuggestion({
    required this.text,
    required this.type,
    required this.score,
  });
}

enum SearchSuggestionType { recent, history, trending }
