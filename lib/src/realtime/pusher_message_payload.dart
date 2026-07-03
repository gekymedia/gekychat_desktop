/// Laravel often nests the primary message under `message` while attachments,
/// sender, reply metadata, and status references live on the broadcast root.
/// Merging fixes local cache upserts and in-chat [Message.fromJson] missing fields.
Map<String, dynamic> mergeLaravelMessageBroadcastPayload(
  Map<String, dynamic> payload,
) {
  final inner = payload['message'];
  if (inner is! Map) {
    return Map<String, dynamic>.from(payload);
  }
  final m = Map<String, dynamic>.from(inner);
  const keysFromRoot = <String>[
    'attachments',
    'sender',
    'reply_to',
    'reply_to_id',
    'forwarded_from',
    'forwarded_from_id',
    'referenced_status_id',
    'referenced_status',
    'referenced_group_id',
    'referenced_group_message_id',
    'referenced_group',
    'link_previews',
    'call_data',
    'location_data',
    'contact_data',
    'poll_data',
    'type',
    'metadata',
    'is_encrypted',
    'view_once',
    'view_once_opened',
  ];
  for (final k in keysFromRoot) {
    if (payload.containsKey(k) && payload[k] != null) {
      m[k] = payload[k];
    }
  }
  return m;
}
