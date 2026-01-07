import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class QuickReply {
  final int id;
  final String title;
  final String message;
  final int order;
  final int usageCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  QuickReply({
    required this.id,
    required this.title,
    required this.message,
    required this.order,
    required this.usageCount,
    this.lastUsedAt,
    required this.createdAt,
  });

  factory QuickReply.fromJson(Map<String, dynamic> json) {
    return QuickReply(
      id: json['id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      order: json['order'] as int? ?? 0,
      usageCount: json['usage_count'] as int? ?? 0,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class QuickRepliesRepository {
  final apiService;

  QuickRepliesRepository(this.apiService);

  Future<List<QuickReply>> getQuickReplies() async {
    try {
      final response = await apiService.getQuickReplies();
      final data = response.data['quick_replies'] as List;
      return data.map((json) => QuickReply.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load quick replies: $e');
    }
  }

  Future<QuickReply> createQuickReply(String title, String message) async {
    try {
      final response = await apiService.createQuickReply(title, message);
      return QuickReply.fromJson(response.data['quick_reply']);
    } catch (e) {
      throw Exception('Failed to create quick reply: $e');
    }
  }

  Future<QuickReply> updateQuickReply(int id, String title, String message) async {
    try {
      final response = await apiService.updateQuickReply(id, title, message);
      return QuickReply.fromJson(response.data['quick_reply']);
    } catch (e) {
      throw Exception('Failed to update quick reply: $e');
    }
  }

  Future<void> deleteQuickReply(int id) async {
    try {
      await apiService.deleteQuickReply(id);
    } catch (e) {
      throw Exception('Failed to delete quick reply: $e');
    }
  }

  Future<void> recordUsage(int id) async {
    try {
      await apiService.recordQuickReplyUsage(id);
    } catch (e) {
      // Don't throw - usage tracking is not critical
    }
  }
}

final quickRepliesRepositoryProvider = Provider<QuickRepliesRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return QuickRepliesRepository(apiService);
});


