import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

/// AUTO-REPLY: Auto-reply rule model
class AutoReplyRule {
  final int id;
  final String keyword;
  final String replyText;
  final int? delaySeconds;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AutoReplyRule({
    required this.id,
    required this.keyword,
    required this.replyText,
    this.delaySeconds,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AutoReplyRule.fromJson(Map<String, dynamic> json) {
    return AutoReplyRule(
      id: json['id'] as int,
      keyword: json['keyword'] as String,
      replyText: json['reply_text'] as String,
      delaySeconds: json['delay_seconds'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// AUTO-REPLY: Repository for auto-reply rules
class AutoReplyRepository {
  final apiService;

  AutoReplyRepository(this.apiService);

  Future<List<AutoReplyRule>> getAutoReplyRules() async {
    try {
      final response = await apiService.get('/auto-replies');
      final data = response.data['data'] as List;
      return data.map((json) => AutoReplyRule.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load auto-reply rules: $e');
    }
  }

  Future<AutoReplyRule> createAutoReplyRule({
    required String keyword,
    required String replyText,
    int? delaySeconds,
    bool isActive = true,
  }) async {
    try {
      final response = await apiService.post('/auto-replies', data: {
        'keyword': keyword,
        'reply_text': replyText,
        if (delaySeconds != null) 'delay_seconds': delaySeconds,
        'is_active': isActive,
      });
      return AutoReplyRule.fromJson(response.data['data']);
    } catch (e) {
      throw Exception('Failed to create auto-reply rule: $e');
    }
  }

  Future<AutoReplyRule> updateAutoReplyRule({
    required int id,
    String? keyword,
    String? replyText,
    int? delaySeconds,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (keyword != null) data['keyword'] = keyword;
      if (replyText != null) data['reply_text'] = replyText;
      if (delaySeconds != null) data['delay_seconds'] = delaySeconds;
      if (isActive != null) data['is_active'] = isActive;

      final response = await apiService.put('/auto-replies/$id', data: data);
      return AutoReplyRule.fromJson(response.data['data']);
    } catch (e) {
      throw Exception('Failed to update auto-reply rule: $e');
    }
  }

  Future<void> deleteAutoReplyRule(int id) async {
    try {
      await apiService.delete('/auto-replies/$id');
    } catch (e) {
      throw Exception('Failed to delete auto-reply rule: $e');
    }
  }
}

final autoReplyRepositoryProvider = Provider<AutoReplyRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AutoReplyRepository(apiService);
});

