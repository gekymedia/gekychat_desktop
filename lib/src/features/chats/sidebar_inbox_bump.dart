import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'chat_providers.dart';
import 'models.dart';

/// Maps in-chat [Message.status] to sidebar tick state.
/// Pending/uploading messages must not show a single check.
String? sidebarOutgoingStatusFromMessage(Message message, {required bool fromMe}) {
  if (!fromMe) return null;
  switch (message.status) {
    case 'queued':
    case 'sending':
      return 'sending';
    case 'failed':
      return 'failed';
    case 'delivered':
      return 'delivered';
    case 'read':
      return 'read';
    case 'sent':
      return 'sent';
    default:
      // Unknown / null: if timestamps say otherwise prefer those, else treat as sent.
      if (message.readAt != null) return 'read';
      if (message.deliveredAt != null) return 'delivered';
      return 'sent';
  }
}

/// Optimistic sidebar preview applied before the conversations API catches up.
class SidebarInboxPatch {
  const SidebarInboxPatch({
    required this.lastMessage,
    required this.updatedAt,
    this.fromMe = true,
    this.outgoingStatus = 'sent',
  });

  final String? lastMessage;
  final DateTime updatedAt;
  final bool fromMe;
  final String? outgoingStatus;
}

final conversationSidebarPatchesProvider =
    StateProvider<Map<int, SidebarInboxPatch>>((ref) => {});

final groupSidebarPatchesProvider =
    StateProvider<Map<int, SidebarInboxPatch>>((ref) => {});

/// Instant unread=0 in sidebar before `/groups/{id}/read` API returns.
final groupUnreadOverridesProvider =
    StateProvider<Map<int, int>>((ref) => {});

/// Groups created locally that are not yet returned by `/groups`.
final sidebarPendingGroupsProvider =
    StateProvider<List<GroupSummary>>((ref) => []);

final conversationUnreadOverridesProvider =
    StateProvider<Map<int, int>>((ref) => {});

/// Merges API list with optimistic patches and re-sorts (pinned first, then updatedAt).
final sidebarConversationsProvider =
    Provider<AsyncValue<List<ConversationSummary>>>((ref) {
  final base = ref.watch(optimizedConversationsProvider);
  final patches = ref.watch(conversationSidebarPatchesProvider);
  final unreadOverrides = ref.watch(conversationUnreadOverridesProvider);
  return base.when(
    data: (list) => AsyncData(
      mergeConversationSidebarPatches(list, patches, unreadOverrides),
    ),
    loading: () => base,
    error: (error, stack) => base,
  );
});

final sidebarGroupsProvider = Provider<AsyncValue<List<GroupSummary>>>((ref) {
  final base = ref.watch(optimizedGroupsProvider);
  final patches = ref.watch(groupSidebarPatchesProvider);
  final unreadOverrides = ref.watch(groupUnreadOverridesProvider);
  final pending = ref.watch(sidebarPendingGroupsProvider);
  return base.when(
    data: (list) {
      var merged =
          mergeGroupSidebarPatches(list, patches, unreadOverrides);
      if (pending.isNotEmpty) {
        for (final group in pending) {
          if (!merged.any((g) => g.id == group.id)) {
            merged = [...merged, group];
          }
        }
        _sortGroups(merged);
      }
      return AsyncData(merged);
    },
    loading: () {
      if (pending.isEmpty) return base;
      return AsyncData(List<GroupSummary>.from(pending));
    },
    error: (error, stack) => base,
  );
});

String sidebarPreviewFromMessage(Message message) {
  final text = (message.body ?? '').trim();
  if (text.isNotEmpty) {
    return text.length > 120 ? '${text.substring(0, 117)}...' : text;
  }
  if (message.attachments.isNotEmpty) {
    return sidebarPreviewFromAttachments(message.attachments);
  }
  return 'New message';
}

/// WhatsApp-style attachment-only last-message preview.
String sidebarPreviewFromAttachments(List<MessageAttachment> attachments) {
  if (attachments.isEmpty) return 'New message';

  final imageCount = attachments.where((a) {
    final mime = a.mimeType.toLowerCase();
    final name = (a.originalName ?? '').toLowerCase();
    return a.isImage ||
        mime.startsWith('image/') ||
        _looksLikeImageName(name);
  }).length;
  final videoCount = attachments.where((a) {
    final mime = a.mimeType.toLowerCase();
    final name = (a.originalName ?? '').toLowerCase();
    return a.isVideo ||
        mime.startsWith('video/') ||
        _looksLikeVideoName(name);
  }).length;
  final hasAudio = attachments.any((a) {
    final mime = a.mimeType.toLowerCase();
    final name = (a.originalName ?? '').toLowerCase();
    return a.isAudio ||
        a.isVoicenote ||
        mime.startsWith('audio/') ||
        _looksLikeAudioName(name);
  });

  if (imageCount > 0 && videoCount == 0 && !hasAudio) {
    return imageCount == 1 ? '📷 Photo' : '📷 $imageCount photos';
  }
  if (videoCount > 0 && imageCount == 0 && !hasAudio) {
    return videoCount == 1 ? '🎬 Video' : '🎬 $videoCount videos';
  }
  if (hasAudio && imageCount == 0 && videoCount == 0) {
    return '🎤 Voice message';
  }
  if (imageCount > 0 || videoCount > 0 || hasAudio) {
    return '📎 ${attachments.length} attachments';
  }
  return '📎 Attachment';
}

bool _looksLikeImageName(String name) =>
    name.endsWith('.jpg') ||
    name.endsWith('.jpeg') ||
    name.endsWith('.png') ||
    name.endsWith('.gif') ||
    name.endsWith('.webp') ||
    name.endsWith('.bmp') ||
    name.endsWith('.heic') ||
    name.endsWith('.heif');

bool _looksLikeVideoName(String name) =>
    name.endsWith('.mp4') ||
    name.endsWith('.mov') ||
    name.endsWith('.m4v') ||
    name.endsWith('.webm') ||
    name.endsWith('.mkv') ||
    name.endsWith('.avi');

bool _looksLikeAudioName(String name) =>
    name.endsWith('.m4a') ||
    name.endsWith('.aac') ||
    name.endsWith('.mp3') ||
    name.endsWith('.ogg') ||
    name.endsWith('.wav') ||
    name.endsWith('.opus');


/// In-memory sidebar patch for realtime inbox events (local DB already updated).
void patchConversationSidebarFromInbox(
  Ref ref, {
  required int conversationId,
  required String preview,
  required DateTime updatedAt,
  required bool fromMe,
}) {
  ref.read(conversationSidebarPatchesProvider.notifier).update((patches) {
    final next = Map<int, SidebarInboxPatch>.from(patches);
    next[conversationId] = SidebarInboxPatch(
      lastMessage: preview,
      updatedAt: updatedAt,
      fromMe: fromMe,
      outgoingStatus: fromMe ? 'sent' : null,
    );
    return next;
  });
}

void patchGroupSidebarFromInbox(
  Ref ref, {
  required int groupId,
  required String preview,
  required DateTime updatedAt,
  required bool fromMe,
}) {
  ref.read(groupSidebarPatchesProvider.notifier).update((patches) {
    final next = Map<int, SidebarInboxPatch>.from(patches);
    next[groupId] = SidebarInboxPatch(
      lastMessage: preview,
      updatedAt: updatedAt,
      fromMe: fromMe,
      outgoingStatus: fromMe ? 'sent' : null,
    );
    return next;
  });
}

Message? newestNonSystemMessage(Iterable<Message> messages) {
  Message? newest;
  for (final message in messages) {
    if (message.isSystem) continue;
    if (newest == null || message.createdAt.isAfter(newest.createdAt)) {
      newest = message;
    }
  }
  return newest;
}

void _applyConversationSidebarPatch(
  WidgetRef ref, {
  required int conversationId,
  required String preview,
  required DateTime updatedAt,
  required bool fromMe,
  String? outgoingStatus,
  bool refreshInboxList = false,
}) {
  ref.read(conversationSidebarPatchesProvider.notifier).update((patches) {
    final next = Map<int, SidebarInboxPatch>.from(patches);
    next[conversationId] = SidebarInboxPatch(
      lastMessage: preview,
      updatedAt: updatedAt,
      fromMe: fromMe,
      outgoingStatus: outgoingStatus,
    );
    return next;
  });
  if (refreshInboxList) {
    ref.read(inboxListRefreshTickProvider.notifier).state++;
  }
}

void _applyGroupSidebarPatch(
  WidgetRef ref, {
  required int groupId,
  required String preview,
  required DateTime updatedAt,
  required bool fromMe,
  String? outgoingStatus,
  bool refreshInboxList = false,
}) {
  ref.read(groupSidebarPatchesProvider.notifier).update((patches) {
    final next = Map<int, SidebarInboxPatch>.from(patches);
    next[groupId] = SidebarInboxPatch(
      lastMessage: preview,
      updatedAt: updatedAt,
      fromMe: fromMe,
      outgoingStatus: outgoingStatus,
    );
    return next;
  });
  if (refreshInboxList) {
    ref.read(inboxListRefreshTickProvider.notifier).state++;
  }
}

Future<void> bumpConversationInSidebar(
  WidgetRef ref, {
  required int conversationId,
  required Message message,
  bool? fromMe,
  bool refreshInboxList = false,
}) async {
  final preview = sidebarPreviewFromMessage(message);
  final isFromMe = fromMe ?? true;
  _applyConversationSidebarPatch(
    ref,
    conversationId: conversationId,
    preview: preview,
    updatedAt: message.createdAt,
    fromMe: isFromMe,
    outgoingStatus: sidebarOutgoingStatusFromMessage(message, fromMe: isFromMe),
    refreshInboxList: refreshInboxList,
  );

  try {
    await ref.read(localStorageServiceProvider).bumpConversationFromInbox(
          conversationId: conversationId,
          lastMessage: preview,
          fromMe: isFromMe,
          updatedAt: message.createdAt,
          incrementUnread: false,
        );
  } catch (_) {}
}

/// Align sidebar preview/sort with the newest message in an open chat thread.
Future<void> syncConversationSidebarFromLoadedMessages(
  WidgetRef ref, {
  required int conversationId,
  required List<Message> messages,
  required int? currentUserId,
}) async {
  final newest = newestNonSystemMessage(messages);
  if (newest == null) return;
  final fromMe = currentUserId != null && newest.senderId == currentUserId;
  await bumpConversationInSidebar(
    ref,
    conversationId: conversationId,
    message: newest,
    fromMe: fromMe,
    refreshInboxList: false,
  );
}

Future<void> clearGroupUnreadInSidebar(WidgetRef ref, int groupId) async {
  ref.read(groupUnreadOverridesProvider.notifier).update((overrides) {
    final next = Map<int, int>.from(overrides);
    next[groupId] = 0;
    return next;
  });
  try {
    await ref.read(localStorageServiceProvider).markGroupAsReadLocally(groupId);
  } catch (_) {}
}

Future<void> clearConversationUnreadInSidebar(
  WidgetRef ref,
  int conversationId,
) async {
  ref.read(conversationUnreadOverridesProvider.notifier).update((overrides) {
    final next = Map<int, int>.from(overrides);
    next[conversationId] = 0;
    return next;
  });
  try {
    await ref
        .read(localStorageServiceProvider)
        .markConversationAsReadLocally(conversationId);
  } catch (_) {}
}

Future<void> bumpGroupInSidebar(
  WidgetRef ref, {
  required int groupId,
  required Message message,
  bool? fromMe,
  bool refreshInboxList = false,
}) async {
  final preview = sidebarPreviewFromMessage(message);
  final isFromMe = fromMe ?? true;
  _applyGroupSidebarPatch(
    ref,
    groupId: groupId,
    preview: preview,
    updatedAt: message.createdAt,
    fromMe: isFromMe,
    outgoingStatus: sidebarOutgoingStatusFromMessage(message, fromMe: isFromMe),
    refreshInboxList: refreshInboxList,
  );

  try {
    await ref.read(localStorageServiceProvider).bumpGroupFromInbox(
          groupId: groupId,
          lastMessage: preview,
          fromMe: isFromMe,
          updatedAt: message.createdAt,
          incrementUnread: false,
        );
  } catch (_) {}
}

/// Align sidebar preview/sort with the newest message in an open group thread.
Future<void> syncGroupSidebarFromLoadedMessages(
  WidgetRef ref, {
  required int groupId,
  required List<Message> messages,
  required int? currentUserId,
}) async {
  final newest = newestNonSystemMessage(messages);
  if (newest == null) return;
  final fromMe = currentUserId != null && newest.senderId == currentUserId;
  await bumpGroupInSidebar(
    ref,
    groupId: groupId,
    message: newest,
    fromMe: fromMe,
    refreshInboxList: false,
  );
}

List<ConversationSummary> mergeConversationSidebarPatches(
  List<ConversationSummary> list,
  Map<int, SidebarInboxPatch> patches,
  Map<int, int> unreadOverrides,
) {
  if (patches.isEmpty && unreadOverrides.isEmpty) return list;

  final merged = list.map((conversation) {
    final patch = patches[conversation.id];
    final unreadOverride = unreadOverrides[conversation.id];
    if (patch == null && unreadOverride == null) return conversation;
    if (patch != null &&
        conversation.updatedAt != null &&
        conversation.updatedAt!.isAfter(patch.updatedAt)) {
      return ConversationSummary(
        id: conversation.id,
        otherUser: conversation.otherUser,
        lastMessage: conversation.lastMessage,
        lastMessageFromMe: conversation.lastMessageFromMe,
        lastMessageOutgoingStatus: conversation.lastMessageOutgoingStatus,
        unreadCount: unreadOverride ?? conversation.unreadCount,
        updatedAt: conversation.updatedAt,
        isPinned: conversation.isPinned,
        isMuted: conversation.isMuted,
        archivedAt: conversation.archivedAt,
        labelIds: conversation.labelIds,
      );
    }
    return ConversationSummary(
      id: conversation.id,
      otherUser: conversation.otherUser,
      lastMessage: patch?.lastMessage ?? conversation.lastMessage,
      lastMessageFromMe: patch?.fromMe ?? conversation.lastMessageFromMe,
      lastMessageOutgoingStatus: patch?.outgoingStatus ??
          conversation.lastMessageOutgoingStatus,
      unreadCount: unreadOverride ?? conversation.unreadCount,
      updatedAt: patch?.updatedAt ?? conversation.updatedAt,
      isPinned: conversation.isPinned,
      isMuted: conversation.isMuted,
      archivedAt: conversation.archivedAt,
      labelIds: conversation.labelIds,
    );
  }).toList();

  _sortConversations(merged);
  return merged;
}

List<GroupSummary> mergeGroupSidebarPatches(
  List<GroupSummary> list,
  Map<int, SidebarInboxPatch> patches,
  Map<int, int> unreadOverrides,
) {
  if (patches.isEmpty && unreadOverrides.isEmpty) return list;

  final merged = list.map((group) {
    final patch = patches[group.id];
    final unreadOverride = unreadOverrides[group.id];
    if (patch == null && unreadOverride == null) return group;
    if (patch != null &&
        group.updatedAt != null &&
        group.updatedAt!.isAfter(patch.updatedAt)) {
      return GroupSummary(
        id: group.id,
        name: group.name,
        avatarUrl: group.avatarUrl,
        unreadCount: unreadOverride ?? group.unreadCount,
        memberCount: group.memberCount,
        updatedAt: group.updatedAt,
        type: group.type,
        isVerified: group.isVerified,
        lastMessage: group.lastMessage,
        lastMessageFromMe: group.lastMessageFromMe,
        lastMessageOutgoingStatus: group.lastMessageOutgoingStatus,
        isPinned: group.isPinned,
        isMuted: group.isMuted,
        labelIds: group.labelIds,
      );
    }
    return GroupSummary(
      id: group.id,
      name: group.name,
      avatarUrl: group.avatarUrl,
      unreadCount: unreadOverride ?? group.unreadCount,
      memberCount: group.memberCount,
      updatedAt: patch?.updatedAt ?? group.updatedAt,
      type: group.type,
      isVerified: group.isVerified,
      lastMessage: patch?.lastMessage ?? group.lastMessage,
      lastMessageFromMe: patch?.fromMe ?? group.lastMessageFromMe,
      lastMessageOutgoingStatus:
          patch?.outgoingStatus ?? group.lastMessageOutgoingStatus,
      isPinned: group.isPinned,
      isMuted: group.isMuted,
      labelIds: group.labelIds,
    );
  }).toList();

  _sortGroups(merged);
  return merged;
}

/// Unread total aligned with the main sidebar (excludes archived DMs and channels).
int computeSidebarUnreadTotal(
  List<ConversationSummary> conversations,
  List<GroupSummary> groups,
) {
  var total = 0;
  for (final c in conversations) {
    if (c.archivedAt == null && c.unreadCount > 0) {
      total += c.unreadCount;
    }
  }
  for (final g in groups) {
    if (g.type != 'channel' && g.unreadCount > 0) {
      total += g.unreadCount;
    }
  }
  return total;
}

/// Same unread count the sidebar "Unread" filter and list badges use.
final sidebarUnreadTotalProvider = Provider<int>((ref) {
  final conversations = ref.watch(sidebarConversationsProvider).valueOrNull;
  final groups = ref.watch(sidebarGroupsProvider).valueOrNull;
  if (conversations == null || groups == null) return 0;
  return computeSidebarUnreadTotal(conversations, groups);
});

void _sortConversations(List<ConversationSummary> list) {
  list.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });
}

void _sortGroups(List<GroupSummary> list) {
  list.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });
}
