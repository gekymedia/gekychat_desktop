import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class SearchResult {
  final String type;
  final Map<String, dynamic> data;

  SearchResult({required this.type, required this.data});

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      type: json['type'] ?? 'unknown',
      data: json['data'] ?? json,
    );
  }
}

class SearchRepository {
  final apiService;

  SearchRepository(this.apiService);

  Future<Map<String, dynamic>> search({
    String? query,
    List<String>? filters,
    int? limit,
  }) async {
    try {
      final response = await apiService.search(
        query: query,
        filters: filters,
        limit: limit,
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to search: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSearchFilters() async {
    try {
      final response = await apiService.getSearchFilters();
      return List<Map<String, dynamic>>.from(
        response.data['available_filters'] ?? [],
      );
    } catch (e) {
      throw Exception('Failed to get search filters: $e');
    }
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return SearchRepository(apiService);
});


