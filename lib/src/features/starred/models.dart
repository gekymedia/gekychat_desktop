// Models for starred messages feature
// This will integrate with the backend API when available

class StarredMessage {
  final int messageId;
  final int conversationId;
  final int? groupId;
  final String body;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;
  final List<String>? attachmentUrls;

  StarredMessage({
    required this.messageId,
    required this.conversationId,
    this.groupId,
    required this.body,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
    this.attachmentUrls,
  });

  factory StarredMessage.fromJson(Map<String, dynamic> json) {
    return StarredMessage(
      messageId: json['message_id'],
      conversationId: json['conversation_id'],
      groupId: json['group_id'],
      body: json['body'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      senderName: json['sender_name'],
      senderAvatar: json['sender_avatar'],
      attachmentUrls: json['attachments'] != null
          ? (json['attachments'] as List).map((a) => a['url'] as String).toList()
          : null,
    );
  }
}

