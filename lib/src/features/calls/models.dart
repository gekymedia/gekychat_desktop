import 'call_duration_format.dart';

class CallLog {
  final int id;
  final String type; // 'voice' or 'video'
  final int? duration; // in seconds
  final bool isMissed;
  final bool isOutgoing;
  final int? groupId;
  final CallUser? otherUser;
  final CallGroup? group;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  CallLog({
    required this.id,
    required this.type,
    this.duration,
    required this.isMissed,
    required this.isOutgoing,
    this.groupId,
    this.otherUser,
    this.group,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  bool get isGroupCall => groupId != null || group != null;

  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: json['id'],
      type: json['type'] ?? 'voice',
      duration: parseCallDurationSeconds(json['duration']),
      isMissed: json['is_missed'] ?? false,
      isOutgoing: json['is_outgoing'] ?? false,
      groupId: json['group_id'] as int?,
      otherUser: json['other_user'] != null
          ? CallUser.fromJson(json['other_user'])
          : null,
      group: json['group'] != null
          ? CallGroup.fromJson(json['group'])
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get formattedDuration => formatCallDurationLabel(duration ?? 0);
}

class CallGroup {
  final int id;
  final String name;
  final String? avatarUrl;

  CallGroup({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory CallGroup.fromJson(Map<String, dynamic> json) {
    return CallGroup(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Group call',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class CallUser {
  final int id;
  final String name;
  final String? phone;
  final String? avatarUrl;

  CallUser({
    required this.id,
    required this.name,
    this.phone,
    this.avatarUrl,
  });

  factory CallUser.fromJson(Map<String, dynamic> json) {
    return CallUser(
      id: json['id'],
      name: json['name'] ?? 'Unknown',
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
    );
  }
}

