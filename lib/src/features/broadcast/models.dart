class BroadcastList {
  final int id;
  final String name;
  final String? description;
  final int recipientCount;
  final List<BroadcastRecipient> recipients;
  final DateTime createdAt;
  final DateTime updatedAt;

  BroadcastList({
    required this.id,
    required this.name,
    this.description,
    required this.recipientCount,
    required this.recipients,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BroadcastList.fromJson(Map<String, dynamic> json) {
    return BroadcastList(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      recipientCount: json['recipient_count'] ?? (json['recipients'] as List? ?? []).length,
      recipients: (json['recipients'] as List<dynamic>?)
              ?.map((r) => BroadcastRecipient.fromJson(r))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class BroadcastRecipient {
  final int id;
  final String name;
  final String? phone;
  final String? avatarUrl;

  BroadcastRecipient({
    required this.id,
    required this.name,
    this.phone,
    this.avatarUrl,
  });

  factory BroadcastRecipient.fromJson(Map<String, dynamic> json) {
    return BroadcastRecipient(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
    );
  }
}

