// Models for starred messages feature

class StarredMessage {
  final int id;
  final int? messageId;
  final int? groupMessageId;
  final String body;
  final String type;
  final DateTime createdAt;
  final DateTime starredAt;
  final SenderInfo sender;
  final List<AttachmentInfo> attachments;
  final ConversationInfo? conversation;
  final GroupInfo? group;

  StarredMessage({
    required this.id,
    this.messageId,
    this.groupMessageId,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.starredAt,
    required this.sender,
    required this.attachments,
    this.conversation,
    this.group,
  });

  factory StarredMessage.fromJson(Map<String, dynamic> json) {
    return StarredMessage(
      id: json['id'] as int,
      messageId: json['conversation'] != null ? json['id'] : null,
      groupMessageId: json['group'] != null ? json['id'] : null,
      body: json['body'] ?? '',
      type: json['type'] ?? 'text',
      createdAt: DateTime.parse(json['created_at']),
      starredAt: DateTime.parse(json['starred_at']),
      sender: SenderInfo.fromJson(json['sender']),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((a) => AttachmentInfo.fromJson(a))
          .toList() ?? [],
      conversation: json['conversation'] != null
          ? ConversationInfo.fromJson(json['conversation'])
          : null,
      group: json['group'] != null
          ? GroupInfo.fromJson(json['group'])
          : null,
    );
  }
}

class SenderInfo {
  final int id;
  final String name;
  final String? avatarUrl;

  SenderInfo({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory SenderInfo.fromJson(Map<String, dynamic> json) {
    return SenderInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class AttachmentInfo {
  final int id;
  final String type;
  final String? url;
  final String? thumbnailUrl;
  final String? name;
  final int? size;

  AttachmentInfo({
    required this.id,
    required this.type,
    this.url,
    this.thumbnailUrl,
    this.name,
    this.size,
  });

  factory AttachmentInfo.fromJson(Map<String, dynamic> json) {
    return AttachmentInfo(
      id: json['id'] as int,
      type: json['type'] as String,
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      name: json['name'] as String?,
      size: json['size'] as int?,
    );
  }
}

class ConversationInfo {
  final int id;
  final String type;
  final String? title;

  ConversationInfo({
    required this.id,
    required this.type,
    this.title,
  });

  factory ConversationInfo.fromJson(Map<String, dynamic> json) {
    return ConversationInfo(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String?,
    );
  }
}

class GroupInfo {
  final int id;
  final String type;
  final String name;

  GroupInfo({
    required this.id,
    required this.type,
    required this.name,
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      id: json['id'] as int,
      type: json['type'] as String,
      name: json['name'] as String,
    );
  }
}

