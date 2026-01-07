// lib/src/features/calls/call_session.dart

class CallSession {
  final int id;
  final int callerId;
  final int? calleeId;
  final int? groupId;
  final int? conversationId;
  final String type; // 'voice' or 'video'
  final String status; // 'pending', 'ongoing', 'ended'
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? callLink;

  CallSession({
    required this.id,
    required this.callerId,
    this.calleeId,
    this.groupId,
    this.conversationId,
    required this.type,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.callLink,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: json['id'] as int,
      callerId: json['caller_id'] as int,
      calleeId: json['callee_id'] as int?,
      groupId: json['group_id'] as int?,
      conversationId: json['conversation_id'] as int?,
      type: json['type'] as String,
      status: json['status'] as String,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      callLink: json['call_link'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caller_id': callerId,
      'callee_id': calleeId,
      'group_id': groupId,
      'conversation_id': conversationId,
      'type': type,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'call_link': callLink,
    };
  }
}

