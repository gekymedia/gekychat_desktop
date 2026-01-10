enum StatusType {
  text,
  image,
  video,
}

enum StatusPrivacy {
  everyone,
  contacts,
  contactsExcept,
  onlyShareWith,
}

class StatusUpdate {
  final int id;
  final int userId;
  final StatusType type;
  final String? text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? backgroundColor;
  final String? fontFamily;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final bool viewed;
  final bool? allowDownload;

  StatusUpdate({
    required this.id,
    required this.userId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.allowDownload,
    this.backgroundColor,
    this.fontFamily,
    required this.createdAt,
    required this.expiresAt,
    required this.viewCount,
    this.viewed = false,
  });

  factory StatusUpdate.fromJson(Map<String, dynamic> json) {
    return StatusUpdate(
      id: json['id'],
      userId: json['user_id'],
      type: StatusType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StatusType.text,
      ),
      text: json['text'],
      mediaUrl: json['media_url'],
      thumbnailUrl: json['thumbnail_url'],
      backgroundColor: json['background_color'],
      fontFamily: json['font_family'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      viewCount: json['view_count'] ?? 0,
      viewed: json['viewed'] ?? false,
      allowDownload: json['allow_download'],
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get timeRemaining => expiresAt.difference(DateTime.now());
}

class StatusSummary {
  final int userId;
  final String userName;
  final String? userAvatar;
  final List<StatusUpdate> updates;
  final DateTime lastUpdatedAt;
  final bool hasUnviewed;
  final bool isMuted;

  StatusSummary({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.updates,
    required this.lastUpdatedAt,
    required this.hasUnviewed,
    this.isMuted = false,
  });

  factory StatusSummary.fromJson(Map<String, dynamic> json) {
    return StatusSummary(
      userId: json['user_id'],
      userName: json['user_name'],
      userAvatar: json['user_avatar'],
      updates: (json['updates'] as List<dynamic>?)
              ?.map((u) => StatusUpdate.fromJson(u))
              .toList() ??
          [],
      lastUpdatedAt: DateTime.parse(json['last_updated_at']),
      hasUnviewed: json['has_unviewed'] ?? false,
      isMuted: json['is_muted'] ?? false,
    );
  }

  int get unviewedCount => updates.where((u) => !u.viewed).length;
  StatusUpdate? get latestUpdate => updates.isNotEmpty ? updates.last : null;
  List<StatusUpdate> get activeUpdates => updates.where((u) => !u.isExpired).toList();
}

class StatusViewer {
  final int userId;
  final String userName;
  final String? userAvatar;
  final DateTime viewedAt;

  StatusViewer({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.viewedAt,
  });

  factory StatusViewer.fromJson(Map<String, dynamic> json) {
    return StatusViewer(
      userId: json['user_id'],
      userName: json['user_name'],
      userAvatar: json['user_avatar'],
      viewedAt: DateTime.parse(json['viewed_at']),
    );
  }
}

class MyStatus {
  final List<StatusUpdate> updates;
  final DateTime? lastUpdatedAt;
  final int totalViews;

  MyStatus({
    required this.updates,
    this.lastUpdatedAt,
    this.totalViews = 0,
  });

  factory MyStatus.fromJson(Map<String, dynamic> json) {
    return MyStatus(
      updates: (json['updates'] as List<dynamic>?)
              ?.map((u) => StatusUpdate.fromJson(u))
              .toList() ??
          [],
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.parse(json['last_updated_at'])
          : null,
      totalViews: json['total_views'] ?? 0,
    );
  }

  bool get hasActiveStatus => activeUpdates.isNotEmpty;
  List<StatusUpdate> get activeUpdates => updates.where((u) => !u.isExpired).toList();
}

class StatusComment {
  final int id;
  final int statusId;
  final String comment;
  final Map<String, dynamic> user;
  final DateTime createdAt;

  StatusComment({
    required this.id,
    required this.statusId,
    required this.comment,
    required this.user,
    required this.createdAt,
  });

  factory StatusComment.fromJson(Map<String, dynamic> json) {
    return StatusComment(
      id: json['id'],
      statusId: json['status_id'] ?? json['statusId'],
      comment: json['comment'],
      user: json['user'] is Map ? Map<String, dynamic>.from(json['user']) : {},
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

