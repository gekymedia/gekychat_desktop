import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'call_duration_format.dart';
import '../chats/models.dart';
import 'call_repository.dart';
import 'join_call_from_link.dart';
import 'providers.dart';

bool isTerminalCallStatus(String? status) {
  final s = status?.toLowerCase() ?? '';
  return s == 'ended' ||
      s == 'cancelled' ||
      s == 'canceled' ||
      s == 'declined' ||
      s == 'missed' ||
      s == 'failed' ||
      s == 'no_answer' ||
      s == 'busy' ||
      s == 'completed';
}

bool isJoinableCallDataStatus(String? status) {
  if (isTerminalCallStatus(status)) return false;
  final st = status?.toLowerCase() ?? '';
  return st == 'calling' || st == 'ongoing';
}

bool serverCallStatusIsJoinable(String? status) {
  if (status == null) return false;
  final s = status.toLowerCase();
  if (isTerminalCallStatus(s)) return false;
  return s == 'active' ||
      s == 'pending' ||
      s == 'calling' ||
      s == 'ongoing';
}

int? sessionIdFromCallData(Map<String, dynamic> callData) {
  final raw = callData['session_id'];
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

int? callDurationSecondsFromData(Map<String, dynamic> data) {
  return parseCallDurationSeconds(data['duration']);
}

Map<String, dynamic> mergeCallDataMaps(
  Map<String, dynamic>? existing,
  Map<String, dynamic>? incoming, {
  bool forceEnded = false,
}) {
  if (incoming == null && existing == null) return <String, dynamic>{};
  if (incoming == null) return Map<String, dynamic>.from(existing!);
  final merged = Map<String, dynamic>.from(incoming);
  if (existing != null) {
    final prevStatus = existing['status'] as String?;
    final incStatus = incoming['status'] as String?;
    if (isTerminalCallStatus(prevStatus) && !isTerminalCallStatus(incStatus)) {
      merged['status'] = prevStatus;
      if (existing['duration'] != null) {
        merged['duration'] = existing['duration'];
      }
    } else if (!isTerminalCallStatus(incStatus)) {
      final prevDur = callDurationSecondsFromData(existing);
      if (prevDur != null && prevDur > 0) {
        merged['status'] = 'ended';
        merged['duration'] = prevDur;
      }
    }
  }
  final incDur = callDurationSecondsFromData(merged);
  if (incDur != null &&
      incDur > 0 &&
      !isTerminalCallStatus(merged['status'] as String?)) {
    merged['status'] = 'ended';
  }
  if (forceEnded && !isTerminalCallStatus(merged['status'] as String?)) {
    merged['status'] = 'ended';
  }
  return merged;
}

Message _messageWithCallData(Message m, Map<String, dynamic> callData) {
  return Message(
    id: m.id,
    clientId: m.clientId,
    conversationId: m.conversationId,
    groupId: m.groupId,
    senderId: m.senderId,
    sender: m.sender,
    body: m.body,
    createdAt: m.createdAt,
    replyToId: m.replyToId,
    forwardedFromId: m.forwardedFromId,
    forwardChain: m.forwardChain,
    attachments: m.attachments,
    readAt: m.readAt,
    deliveredAt: m.deliveredAt,
    reactions: m.reactions,
    locationData: m.locationData,
    contactData: m.contactData,
    callData: callData,
    linkPreviews: m.linkPreviews,
    isDeleted: m.isDeleted,
    deletedForMe: m.deletedForMe,
    status: m.status,
    isSystem: m.isSystem,
    systemAction: m.systemAction,
    mentionCount: m.mentionCount,
    mentions: m.mentions,
    messageType: m.messageType,
    referencedStatusId: m.referencedStatusId,
    referencedStatus: m.referencedStatus,
    referencedGroupId: m.referencedGroupId,
    referencedGroupMessageId: m.referencedGroupMessageId,
    referencedGroup: m.referencedGroup,
    editedAt: m.editedAt,
    isViewOnce: m.isViewOnce,
    viewOnceOpened: m.viewOnceOpened,
    sikaTransferData: m.sikaTransferData,
    scheduledAt: m.scheduledAt,
    pollData: m.pollData,
    metadata: m.metadata,
  );
}

/// Patch stale local call rows when the server says the session ended.
Future<List<Message>> reconcileStaleJoinableCallMessages({
  required List<Message> messages,
  required CallRepository repo,
  required ProviderContainer container,
  int maxCandidates = 3,
}) async {
  var changed = false;
  final out = List<Message>.from(messages);
  var checked = 0;

  for (var i = out.length - 1; i >= 0 && checked < maxCandidates; i--) {
    final m = out[i];
    final cd = m.callData;
    if (cd == null) continue;
    if (!isJoinableCallDataStatus(cd['status'] as String?)) continue;

    final sid = sessionIdFromCallData(cd);
    if (sid == null || sid <= 0) continue;
    checked++;

    final serverStatus = await repo.fetchCallSessionStatus(sid);
    if (serverCallStatusIsJoinable(serverStatus)) continue;

    final link = cd['call_link'];
    if (link is String && link.isNotEmpty) {
      rememberDismissedDeadCall(container, link, cd);
    } else {
      rememberDismissedDeadCall(
        container,
        'https://chat.gekychat.com/calls/join/$sid',
        cd,
      );
    }

    final patched =
        mergeCallDataMaps(cd, const {'status': 'ended'}, forceEnded: true);
    out[i] = _messageWithCallData(m, patched);
    changed = true;
  }

  return changed ? out : messages;
}

Message? newestJoinableActiveCallMessage(
  List<Message> messages, {
  required ProviderContainer container,
  int? conversationId,
  int? groupId,
}) {
  for (var i = messages.length - 1; i >= 0; i--) {
    final m = messages[i];
    final cd = m.callData;
    if (cd == null) continue;

    if (groupId != null) {
      final msgGid = m.groupId;
      if (msgGid != null && msgGid != groupId) continue;
      final cgid = cd['group_id'];
      if (cgid != null) {
        final parsed = int.tryParse(cgid.toString());
        if (parsed != null && parsed > 0 && parsed != groupId) continue;
      }
    } else if (conversationId != null) {
      if (m.groupId != null) continue;
      final gRaw = cd['group_id'];
      if (gRaw != null) {
        final g = int.tryParse(gRaw.toString());
        if (g != null && g > 0) continue;
      }
      if (cd['is_group'] == true) continue;
    }

    if (ongoingCallBannerSuppressed(container, cd)) continue;
    if (!isJoinableCallDataStatus(cd['status'] as String?)) continue;
    final link = cd['call_link'];
    if (link is! String || link.trim().isEmpty) continue;
    return m;
  }
  return null;
}

final callSessionJoinableProvider =
    FutureProvider.autoDispose.family<bool, int>((ref, sessionId) async {
  final repo = ref.read(callRepositoryProvider);
  final status = await repo.fetchCallSessionStatus(sessionId);
  return serverCallStatusIsJoinable(status);
});
