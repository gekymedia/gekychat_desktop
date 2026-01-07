class CallLog {
  final int id;
  final String type; // 'voice' or 'video'
  final int? duration; // in seconds
  final bool isMissed;
  final bool isOutgoing;
  final CallUser? otherUser;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  CallLog({
    required this.id,
    required this.type,
    this.duration,
    required this.isMissed,
    required this.isOutgoing,
    this.otherUser,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: json['id'],
      type: json['type'] ?? 'voice',
      duration: json['duration'],
      isMissed: json['is_missed'] ?? false,
      isOutgoing: json['is_outgoing'] ?? false,
      otherUser: json['other_user'] != null 
          ? CallUser.fromJson(json['other_user'])
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

  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
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

