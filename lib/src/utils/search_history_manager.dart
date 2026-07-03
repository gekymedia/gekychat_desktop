import 'package:shared_preferences/shared_preferences.dart';

/// Manages search history for quick access to recent searches
class SearchHistoryManager {
  static const String _keySearchHistory = 'search_history';
  static const int _maxHistoryItems = 10;

  final SharedPreferences _prefs;

  SearchHistoryManager(this._prefs);

  /// Get recent search queries
  Future<List<String>> getSearchHistory() async {
    final history = _prefs.getStringList(_keySearchHistory) ?? [];
    return history;
  }

  /// Add a search query to history
  Future<void> addSearchQuery(String query) async {
    if (query.isEmpty) return;

    final history = await getSearchHistory();
    
    // Remove if already exists (to move to top)
    history.remove(query);
    
    // Add to beginning
    history.insert(0, query);
    
    // Keep only recent items
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    
    await _prefs.setStringList(_keySearchHistory, history);
  }

  /// Remove a specific search query
  Future<void> removeSearchQuery(String query) async {
    final history = await getSearchHistory();
    history.remove(query);
    await _prefs.setStringList(_keySearchHistory, history);
  }

  /// Clear all search history
  Future<void> clearSearchHistory() async {
    await _prefs.remove(_keySearchHistory);
  }

  /// Get search suggestions based on partial query
  Future<List<String>> getSearchSuggestions(String partial) async {
    if (partial.isEmpty) {
      return getSearchHistory();
    }

    final history = await getSearchHistory();
    return history
        .where((query) => query.toLowerCase().contains(partial.toLowerCase()))
        .toList();
  }
}
