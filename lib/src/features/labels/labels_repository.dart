import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class Label {
  final int id;
  final String name;

  Label({
    required this.id,
    required this.name,
  });

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

final labelsRepositoryProvider = Provider<LabelsRepository>((ref) {
  return LabelsRepository(ref.read(apiServiceProvider));
});

class LabelsRepository {
  final apiService;

  LabelsRepository(this.apiService);

  Future<List<Label>> getLabels() async {
    try {
      final response = await apiService.getLabels();
      final data = response.data['data'] as List;
      return data.map((json) => Label.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load labels: $e');
    }
  }

  Future<Label> createLabel(String name) async {
    try {
      final response = await apiService.createLabel(name);
      final data = response.data['data'] as Map<String, dynamic>;
      return Label.fromJson(data);
    } catch (e) {
      throw Exception('Failed to create label: $e');
    }
  }

  Future<Label> updateLabel(int id, String name) async {
    try {
      final response = await apiService.updateLabel(id, name);
      final data = response.data['data'] as Map<String, dynamic>;
      return Label.fromJson(data);
    } catch (e) {
      throw Exception('Failed to update label: $e');
    }
  }

  Future<void> deleteLabel(int id) async {
    try {
      await apiService.deleteLabel(id);
    } catch (e) {
      throw Exception('Failed to delete label: $e');
    }
  }

  Future<void> attachLabelToConversation(int labelId, int conversationId) async {
    try {
      await apiService.attachLabelToConversation(labelId, conversationId);
    } catch (e) {
      throw Exception('Failed to attach label: $e');
    }
  }

  Future<void> detachLabelFromConversation(int labelId, int conversationId) async {
    try {
      await apiService.detachLabelFromConversation(labelId, conversationId);
    } catch (e) {
      throw Exception('Failed to detach label: $e');
    }
  }
}
