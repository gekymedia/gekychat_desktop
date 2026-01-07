class MediaItem {
  final int id;
  final int messageId;
  final String type; // 'image' or 'video'
  final String url;
  final String? thumbnailUrl;
  final String mimeType;
  final int size;
  final MediaSender sender;
  final DateTime createdAt;

  MediaItem({
    required this.id,
    required this.messageId,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    required this.mimeType,
    required this.size,
    required this.sender,
    required this.createdAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      messageId: json['message_id'],
      type: json['type'],
      url: json['url'],
      thumbnailUrl: json['thumbnail_url'],
      mimeType: json['mime_type'],
      size: json['size'] ?? 0,
      sender: MediaSender.fromJson(json['sender']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class MediaSender {
  final int id;
  final String name;
  final String? avatarUrl;

  MediaSender({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory MediaSender.fromJson(Map<String, dynamic> json) {
    return MediaSender(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
    );
  }
}

