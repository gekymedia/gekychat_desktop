import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart' hide Message;
import '../../features/chats/models.dart';

class LocalStorageService {
  final AppDatabase _db;

  LocalStorageService(this._db);

  static Map<String, dynamic> _attachmentToCacheMap(MessageAttachment a) {
    return {
      'id': a.id,
      'url': a.url,
      'mime_type': a.mimeType,
      'is_image': a.isImage,
      'is_video': a.isVideo,
      'is_audio': a.isAudio,
      'is_document': a.isDocument,
      if (a.originalName != null && a.originalName!.trim().isNotEmpty)
        'original_name': a.originalName,
      'shared_as_document': a.sharedAsDocument,
      'is_voicenote': a.isVoicenote,
      if (a.thumbnailUrl != null) 'thumbnail_url': a.thumbnailUrl,
      if (a.compressionStatus != null) 'compression_status': a.compressionStatus,
      if (a.compressedUrl != null) 'compressed_url': a.compressedUrl,
      if (a.originalSize != null) 'original_size': a.originalSize,
      if (a.compressedSize != null) 'compressed_size': a.compressedSize,
      if (a.compressionLevel != null) 'compression_level': a.compressionLevel,
    };
  }

  static String _encodeLabelIds(List<int> ids) => jsonEncode(ids);

  static List<int> _decodeLabelIds(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final d = jsonDecode(raw);
      if (d is! List) return [];
      return d
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .where((id) => id > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Embeds [Message.pollData] in the JSON list stored in `link_previews_json` so
  /// offline cache works without a Drift schema migration (poll + real previews supported).
  static const _pollEnvelopeKey = '__gekychat_poll';
  /// Non-column fields (mentions, refs, metadata, etc.) stored alongside poll/previews.
  static const _extrasEnvelopeKey = '__gekychat_extras';

  static Map<String, dynamic>? _extrasPayloadForSave(Message msg) {
    final map = <String, dynamic>{};
    if (msg.messageType != null && msg.messageType!.isNotEmpty) {
      map['message_type'] = msg.messageType;
    }
    if (msg.mentionCount > 0) {
      map['mention_count'] = msg.mentionCount;
    }
    if (msg.mentions != null && msg.mentions!.isNotEmpty) {
      map['mentions'] = msg.mentions;
    }
    if (msg.referencedStatusId != null) {
      map['referenced_status_id'] = msg.referencedStatusId;
    }
    if (msg.referencedStatus != null) {
      map['referenced_status'] = msg.referencedStatus;
    }
    if (msg.referencedGroupId != null) {
      map['referenced_group_id'] = msg.referencedGroupId;
    }
    if (msg.referencedGroupMessageId != null) {
      map['referenced_group_message_id'] = msg.referencedGroupMessageId;
    }
    if (msg.referencedGroup != null) {
      map['referenced_group'] = msg.referencedGroup;
    }
    if (msg.forwardChain != null) {
      map['forward_chain'] = msg.forwardChain;
    }
    if (msg.editedAt != null) {
      map['edited_at'] = msg.editedAt!.toIso8601String();
    }
    if (msg.isViewOnce) {
      map['is_view_once'] = true;
    }
    if (msg.viewOnceOpened) {
      map['view_once_opened'] = true;
    }
    if (msg.scheduledAt != null) {
      map['scheduled_at'] = msg.scheduledAt!.toIso8601String();
    }
    if (msg.sikaTransferData != null) {
      map['sika_transfer_data'] = msg.sikaTransferData;
    }
    if (msg.metadata != null && msg.metadata!.isNotEmpty) {
      map['metadata'] = msg.metadata;
    }
    if (msg.replyToPreview != null && msg.replyToPreview!.isNotEmpty) {
      map['reply_to'] = msg.replyToPreview;
    }
    return map.isEmpty ? null : map;
  }

  static List<dynamic> _linkPreviewsJsonListForSave(Message msg) {
    final previews = List<dynamic>.from(msg.linkPreviews ?? []);
    final out = <dynamic>[];
    if (msg.pollData != null) {
      out.add({_pollEnvelopeKey: true, 'poll': msg.pollData});
    }
    final extras = _extrasPayloadForSave(msg);
    if (extras != null) {
      out.add({_extrasEnvelopeKey: true, 'extras': extras});
    }
    out.addAll(previews);
    return out;
  }

  static ({
    Map<String, dynamic>? pollData,
    Map<String, dynamic>? extras,
    List<dynamic>? linkPreviews
  }) _parseLinkPreviewsJsonField(String? raw) {
    if (raw == null || raw.isEmpty) {
      return (pollData: null, extras: null, linkPreviews: null);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return (pollData: null, extras: null, linkPreviews: null);
      }
      Map<String, dynamic>? pollData;
      Map<String, dynamic>? extras;
      final rest = <dynamic>[];
      for (final item in decoded) {
        if (item is Map &&
            item[_pollEnvelopeKey] == true &&
            item['poll'] is Map) {
          pollData = Map<String, dynamic>.from(item['poll'] as Map);
        } else if (item is Map &&
            item[_extrasEnvelopeKey] == true &&
            item['extras'] is Map) {
          extras = Map<String, dynamic>.from(item['extras'] as Map);
        } else {
          rest.add(item);
        }
      }
      return (
        pollData: pollData,
        extras: extras,
        linkPreviews: rest.isEmpty ? null : rest
      );
    } catch (_) {
      return (pollData: null, extras: null, linkPreviews: null);
    }
  }

  /// Maps a Drift `messages` table row to [Message] (domain model).
  Message _storedRowToChatModel(Object? row) {
    final r = row as dynamic;
    List<MessageAttachment> attachments = [];
    if (r.attachmentsJson != null) {
      try {
        final attList = jsonDecode(r.attachmentsJson as String) as List;
        attachments =
            attList.map((a) => MessageAttachment.fromJson(a)).toList();
      } catch (_) {}
    }

    List<Reaction> reactions = [];
    if (r.reactionsJson != null) {
      try {
        final reactList = jsonDecode(r.reactionsJson as String) as List;
        reactions = reactList.map((x) => Reaction.fromJson(x)).toList();
      } catch (_) {}
    }

    Map<String, dynamic>? sender;
    if (r.senderName != null) {
      sender = {
        'name': r.senderName as String?,
        'avatar_url': r.senderAvatarUrl as String?,
      };
    }

    Map<String, dynamic>? locationData;
    if (r.locationDataJson != null) {
      try {
        locationData =
            jsonDecode(r.locationDataJson as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    Map<String, dynamic>? contactData;
    if (r.contactDataJson != null) {
      try {
        contactData =
            jsonDecode(r.contactDataJson as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    Map<String, dynamic>? callData;
    if (r.callDataJson != null) {
      try {
        callData = jsonDecode(r.callDataJson as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    final parsed = _parseLinkPreviewsJsonField(r.linkPreviewsJson as String?);
    final pollFromPreviews = parsed.pollData;
    final ex = parsed.extras;
    final linkPreviews = parsed.linkPreviews;

    int? intFrom(dynamic v) {
      if (v is int) return v;
      if (v == null) return null;
      return int.tryParse(v.toString());
    }

    DateTime? editedFromExtras;
    final editedRaw = ex?['edited_at'];
    if (editedRaw is String) {
      editedFromExtras = DateTime.tryParse(editedRaw);
    }

    DateTime? scheduledFromExtras;
    final schedRaw = ex?['scheduled_at'];
    if (schedRaw is String) {
      scheduledFromExtras = DateTime.tryParse(schedRaw);
    }

    Map<String, dynamic>? metaFromExtras;
    if (ex?['metadata'] is Map) {
      metaFromExtras = Map<String, dynamic>.from(ex!['metadata'] as Map);
    }

    Map<String, dynamic>? refStatusFromExtras;
    if (ex?['referenced_status'] is Map) {
      refStatusFromExtras =
          Map<String, dynamic>.from(ex!['referenced_status'] as Map);
    }

    Map<String, dynamic>? refGroupFromExtras;
    if (ex?['referenced_group'] is Map) {
      refGroupFromExtras =
          Map<String, dynamic>.from(ex!['referenced_group'] as Map);
    }

    List<dynamic>? mentionsFromExtras;
    if (ex?['mentions'] is List) {
      mentionsFromExtras = List<dynamic>.from(ex!['mentions'] as List);
    }

    List<dynamic>? forwardFromExtras;
    if (ex?['forward_chain'] is List) {
      forwardFromExtras = List<dynamic>.from(ex!['forward_chain'] as List);
    }

    Map<String, dynamic>? sikaFromExtras;
    if (ex?['sika_transfer_data'] is Map) {
      sikaFromExtras =
          Map<String, dynamic>.from(ex!['sika_transfer_data'] as Map);
    }

    final typeFromExtras = ex?['message_type'] as String?;
    final resolvedType = typeFromExtras ??
        (pollFromPreviews != null ? 'poll' : null);

    Map<String, dynamic>? replyToPreviewFromExtras;
    if (ex?['reply_to'] is Map) {
      replyToPreviewFromExtras =
          Map<String, dynamic>.from(ex!['reply_to'] as Map);
    }

    final rawBody = (r.body as String?) ?? '';
    return Message(
      id: r.id as int? ?? 0,
      clientId: r.clientUuid as String?,
      conversationId: r.conversationId as int?,
      groupId: r.groupId as int?,
      senderId: r.senderId as int,
      sender: sender,
      body: Message.normalizeBody(
        rawBody,
        hasAttachments: attachments.isNotEmpty,
      ),
      status: r.status as String?,
      createdAt: r.createdAt as DateTime,
      replyToId: r.replyToId as int?,
      replyToPreview: replyToPreviewFromExtras,
      forwardedFromId: r.forwardedFromId as int?,
      forwardChain: forwardFromExtras,
      attachments: attachments,
      readAt: r.readAt as DateTime?,
      deliveredAt: r.deliveredAt as DateTime?,
      reactions: reactions,
      locationData: locationData,
      contactData: contactData,
      callData: callData,
      linkPreviews: linkPreviews,
      isDeleted: r.isDeleted as bool,
      deletedForMe: r.deletedForMe as bool,
      isSystem: r.isSystem as bool,
      systemAction: r.systemAction as String?,
      messageType: resolvedType,
      pollData: pollFromPreviews,
      mentionCount: intFrom(ex?['mention_count']) ?? 0,
      mentions: mentionsFromExtras,
      referencedStatusId: intFrom(ex?['referenced_status_id']),
      referencedStatus: refStatusFromExtras,
      referencedGroupId: intFrom(ex?['referenced_group_id']),
      referencedGroupMessageId: intFrom(ex?['referenced_group_message_id']),
      referencedGroup: refGroupFromExtras,
      editedAt: editedFromExtras,
      isViewOnce: ex?['is_view_once'] == true,
      viewOnceOpened: ex?['view_once_opened'] == true,
      scheduledAt: scheduledFromExtras,
      sikaTransferData: sikaFromExtras,
      metadata: metaFromExtras,
    );
  }

  // Save conversations
  Future<void> saveConversations(List<ConversationSummary> conversations) async {
    await _db.batch((batch) {
      for (final conv in conversations) {
        batch.insert(
          _db.conversations,
          ConversationsCompanion(
            id: Value(conv.id),
            otherUserId: Value(conv.otherUser.id),
            otherUserName: Value(conv.otherUser.name),
            otherUserPhone: Value(conv.otherUser.phone),
            otherUserAvatarUrl: Value(conv.otherUser.avatarUrl),
            lastMessage: Value(conv.lastMessage),
            lastMessageFromMe: Value(conv.lastMessageFromMe),
            lastMessageOutgoingStatus: Value(conv.lastMessageOutgoingStatus),
            unreadCount: Value(conv.unreadCount),
            updatedAt: Value(conv.updatedAt),
            isPinned: Value(conv.isPinned),
            isMuted: Value(conv.isMuted),
            archivedAt: Value(conv.archivedAt),
            lastSyncedAt: Value(DateTime.now()),
            labelIdsJson: Value(_encodeLabelIds(conv.labelIds)),
          ),
          mode: InsertMode.replace,
        );
      }
    });
  }

  // Load conversations from local storage
  Future<List<ConversationSummary>> loadConversations() async {
    final rows = await _db.select(_db.conversations).get();
    
    return rows.map((row) {
      final otherUser = User(
        id: row.otherUserId ?? 0,
        name: row.otherUserName ?? 'Unknown',
        phone: row.otherUserPhone,
        avatarUrl: row.otherUserAvatarUrl,
      );
      
      return ConversationSummary(
        id: row.id,
        otherUser: otherUser,
        lastMessage: row.lastMessage,
        lastMessageFromMe: row.lastMessageFromMe,
        lastMessageOutgoingStatus: row.lastMessageOutgoingStatus,
        unreadCount: row.unreadCount,
        updatedAt: row.updatedAt,
        isPinned: row.isPinned,
        isMuted: row.isMuted,
        archivedAt: row.archivedAt,
        labelIds: _decodeLabelIds(row.labelIdsJson),
      );
    }).toList();
  }

  /// Mark a conversation as read locally (set unread count to 0). Used when offline so UI/badge update immediately.
  Future<void> markConversationAsReadLocally(int conversationId) async {
    await (_db.update(_db.conversations)..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(unreadCount: const Value(0)));
  }

  /// Mark a group as read locally (set unread count to 0). Used when offline so UI/badge update immediately.
  Future<void> markGroupAsReadLocally(int groupId) async {
    await (_db.update(_db.groups)..where((g) => g.id.equals(groupId)))
        .write(GroupsCompanion(unreadCount: const Value(0)));
  }

  /// Insert or replace a single message from a Pusher inbox event.
  Future<void> upsertMessage(Message msg) async {
    final clientUuid = msg.groupId != null
        ? (msg.clientId ?? 'g${msg.groupId}_m${msg.id}')
        : (msg.clientId ?? 'srv_${msg.id}');
    final body = Message.normalizeBody(
      msg.body,
      hasAttachments: msg.attachments.isNotEmpty,
    );
    await _db.into(_db.messages).insert(
      MessagesCompanion(
        id: Value(msg.id),
        clientUuid: Value(clientUuid),
        conversationId: Value(msg.conversationId),
        groupId: Value(msg.groupId),
        senderId: Value(msg.senderId),
        senderName: Value(msg.sender?['name'] as String?),
        senderAvatarUrl: Value(
            (msg.sender?['avatar'] ?? msg.sender?['avatar_url']) as String?),
        body: Value(body),
        status: Value(msg.status ?? 'delivered'),
        createdAt: Value(msg.createdAt),
        serverCreatedAt: Value(msg.createdAt),
        replyToId: Value(msg.replyToId),
        forwardedFromId: Value(msg.forwardedFromId),
        attachmentsJson: Value(msg.attachments.isNotEmpty
            ? jsonEncode(msg.attachments.map(_attachmentToCacheMap).toList())
            : null),
        readAt: Value(msg.readAt),
        deliveredAt: Value(msg.deliveredAt),
        reactionsJson: Value(msg.reactions.isNotEmpty
            ? jsonEncode(msg.reactions
                .map((r) => {'user_id': r.userId, 'emoji': r.emoji})
                .toList())
            : null),
        locationDataJson: Value(
            msg.locationData != null ? jsonEncode(msg.locationData) : null),
        contactDataJson: Value(
            msg.contactData != null ? jsonEncode(msg.contactData) : null),
        callDataJson: Value(
            msg.callData != null ? jsonEncode(msg.callData) : null),
        linkPreviewsJson: () {
          final list = _linkPreviewsJsonListForSave(msg);
          return Value(list.isNotEmpty ? jsonEncode(list) : null);
        }(),
        isDeleted: Value(msg.isDeleted),
        deletedForMe: Value(msg.deletedForMe),
        isSystem: Value(msg.isSystem),
        systemAction: Value(msg.systemAction),
        lastSyncedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Update conversation preview from an inbox Pusher event.
  Future<void> bumpConversationFromInbox({
    required int conversationId,
    required String lastMessage,
    required bool fromMe,
    required DateTime updatedAt,
    bool incrementUnread = true,
  }) async {
    final row = await (_db.select(_db.conversations)
          ..where((c) => c.id.equals(conversationId))
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return;
    final unread =
        incrementUnread ? row.unreadCount + 1 : row.unreadCount;
    await (_db.update(_db.conversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(
      lastMessage: Value(lastMessage),
      lastMessageFromMe: Value(fromMe),
      updatedAt: Value(updatedAt),
      unreadCount: Value(unread),
      lastSyncedAt: Value(DateTime.now()),
    ));
  }

  /// Update group preview from an inbox Pusher event.
  Future<void> bumpGroupFromInbox({
    required int groupId,
    required String lastMessage,
    required bool fromMe,
    required DateTime updatedAt,
    bool incrementUnread = true,
  }) async {
    final row = await (_db.select(_db.groups)
          ..where((g) => g.id.equals(groupId))
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return;
    final unread =
        incrementUnread ? row.unreadCount + 1 : row.unreadCount;
    await (_db.update(_db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(
        lastMessage: Value(lastMessage),
        lastMessageFromMe: Value(fromMe),
        updatedAt: Value(updatedAt),
        unreadCount: Value(unread),
        lastSyncedAt: Value(DateTime.now()),
      ),
    );
  }

  // Save messages for a conversation (upsert — never wipe the full cache on refresh).
  Future<void> saveMessages(int conversationId, List<Message> messages,
      {int? page}) async {
    if (messages.isEmpty) return;
    await _db.batch((batch) {
      for (final msg in messages) {
        batch.insert(
          _db.messages,
          MessagesCompanion(
            id: Value(msg.id),
            // clientUuid is the PK; fall back to a deterministic key from server id
            clientUuid: Value(msg.clientId ?? 'srv_${msg.id}'),
            conversationId: Value(msg.conversationId ?? conversationId),
            groupId: Value(msg.groupId),
            senderId: Value(msg.senderId),
            senderName: Value(msg.sender?['name'] as String?),
            senderAvatarUrl: Value(
                (msg.sender?['avatar'] ?? msg.sender?['avatar_url']) as String?),
            body: Value(msg.body),
            status: Value(msg.status ?? 'delivered'),
            createdAt: Value(msg.createdAt),
            serverCreatedAt: Value(msg.createdAt),
            replyToId: Value(msg.replyToId),
            forwardedFromId: Value(msg.forwardedFromId),
            attachmentsJson: Value(msg.attachments.isNotEmpty
                ? jsonEncode(
                    msg.attachments.map(_attachmentToCacheMap).toList(),
                  )
                : null),
            readAt: Value(msg.readAt),
            deliveredAt: Value(msg.deliveredAt),
            reactionsJson: Value(msg.reactions.isNotEmpty
                ? jsonEncode(msg.reactions.map((r) => {
                      'user_id': r.userId,
                      'emoji': r.emoji,
                    }).toList())
                : null),
            locationDataJson: Value(
                msg.locationData != null ? jsonEncode(msg.locationData) : null),
            contactDataJson: Value(
                msg.contactData != null ? jsonEncode(msg.contactData) : null),
            callDataJson: Value(
                msg.callData != null ? jsonEncode(msg.callData) : null),
            linkPreviewsJson: () {
              final list = _linkPreviewsJsonListForSave(msg);
              return Value(list.isNotEmpty ? jsonEncode(list) : null);
            }(),
            isDeleted: Value(msg.isDeleted),
            deletedForMe: Value(msg.deletedForMe),
            isSystem: Value(msg.isSystem),
            systemAction: Value(msg.systemAction),
            lastSyncedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.replace,
        );
      }
    });
  }

  /// Highest server message id cached for a DM (for incremental `after_id` sync).
  Future<int?> getMaxMessageIdForConversation(int conversationId) async {
    final row = await (_db.selectOnly(_db.messages)
          ..addColumns([_db.messages.id.max()])
          ..where(_db.messages.conversationId.equals(conversationId))
          ..where(_db.messages.id.isBiggerThanValue(0)))
        .getSingleOrNull();
    return row?.read(_db.messages.id.max());
  }

  /// Highest server message id cached for a group (for incremental `after_id` sync).
  Future<int?> getMaxMessageIdForGroup(int groupId) async {
    final row = await (_db.selectOnly(_db.messages)
          ..addColumns([_db.messages.id.max()])
          ..where(_db.messages.groupId.equals(groupId))
          ..where(_db.messages.id.isBiggerThanValue(0)))
        .getSingleOrNull();
    return row?.read(_db.messages.id.max());
  }

  Future<List<int>> getCachedConversationIds() async {
    final rows = await _db.select(_db.conversations).get();
    return rows.map((r) => r.id).where((id) => id > 0).toList();
  }

  Future<List<int>> getCachedGroupIds() async {
    final rows = await _db.select(_db.groups).get();
    return rows.map((r) => r.id).where((id) => id > 0).toList();
  }

  // Load messages from local storage
  Future<List<Message>> loadMessages(int conversationId) async {
    final rows = await (_db.select(_db.messages)
          ..where((tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.deletedForMe.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .get();

    return rows.map((row) => _storedRowToChatModel(row)).toList();
  }

  /// Persist group chat history (including polls) for offline read — uses
  /// `clientUuid` prefix `g{groupId}_m{id}` so rows do not collide with DM cache.
  Future<void> saveGroupMessages(int groupId, List<Message> messages,
      {int? page}) async {
    if (messages.isEmpty) return;
    await _db.batch((batch) {
      for (final msg in messages) {
        batch.insert(
          _db.messages,
          MessagesCompanion(
            id: Value(msg.id),
            clientUuid: Value(msg.clientId ?? 'g${groupId}_m${msg.id}'),
            conversationId: const Value<int?>(null),
            groupId: Value(msg.groupId ?? groupId),
            senderId: Value(msg.senderId),
            senderName: Value(msg.sender?['name'] as String?),
            senderAvatarUrl: Value(
                (msg.sender?['avatar'] ?? msg.sender?['avatar_url']) as String?),
            body: Value(msg.body),
            status: Value(msg.status ?? 'delivered'),
            createdAt: Value(msg.createdAt),
            serverCreatedAt: Value(msg.createdAt),
            replyToId: Value(msg.replyToId),
            forwardedFromId: Value(msg.forwardedFromId),
            attachmentsJson: Value(msg.attachments.isNotEmpty
                ? jsonEncode(
                    msg.attachments.map(_attachmentToCacheMap).toList(),
                  )
                : null),
            readAt: Value(msg.readAt),
            deliveredAt: Value(msg.deliveredAt),
            reactionsJson: Value(msg.reactions.isNotEmpty
                ? jsonEncode(msg.reactions.map((r) => {
                      'user_id': r.userId,
                      'emoji': r.emoji,
                    }).toList())
                : null),
            locationDataJson: Value(
                msg.locationData != null ? jsonEncode(msg.locationData) : null),
            contactDataJson: Value(
                msg.contactData != null ? jsonEncode(msg.contactData) : null),
            callDataJson: Value(
                msg.callData != null ? jsonEncode(msg.callData) : null),
            linkPreviewsJson: () {
              final list = _linkPreviewsJsonListForSave(msg);
              return Value(list.isNotEmpty ? jsonEncode(list) : null);
            }(),
            isDeleted: Value(msg.isDeleted),
            deletedForMe: Value(msg.deletedForMe),
            isSystem: Value(msg.isSystem),
            systemAction: Value(msg.systemAction),
            lastSyncedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.replace,
        );
      }
    });
  }

  Future<List<Message>> loadGroupMessages(int groupId) async {
    final rows = await (_db.select(_db.messages)
          ..where((tbl) =>
              tbl.groupId.equals(groupId) & tbl.deletedForMe.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .get();

    return rows.map((row) => _storedRowToChatModel(row)).toList();
  }

  // Save groups and drop rows the server no longer returns (e.g. user left the group).
  Future<void> saveGroups(List<GroupSummary> groups) async {
    final activeIds = groups.map((g) => g.id).where((id) => id > 0).toSet();
    await _db.batch((batch) {
      for (final group in groups) {
        batch.insert(
          _db.groups,
          GroupsCompanion(
            id: Value(group.id),
            name: Value(group.name),
            avatarUrl: Value(group.avatarUrl),
            unreadCount: Value(group.unreadCount),
            memberCount: Value(group.memberCount),
            updatedAt: Value(group.updatedAt),
            type: Value(group.type),
            isVerified: Value(group.isVerified),
            lastMessage: Value(group.lastMessage),
            lastMessageFromMe: Value(group.lastMessageFromMe),
            lastMessageOutgoingStatus: Value(group.lastMessageOutgoingStatus),
            isPinned: Value(group.isPinned),
            isMuted: Value(group.isMuted),
            lastSyncedAt: Value(DateTime.now()),
            labelIdsJson: Value(_encodeLabelIds(group.labelIds)),
          ),
          mode: InsertMode.replace,
        );
      }
    });
    if (activeIds.isEmpty) {
      await _db.delete(_db.groups).go();
    } else {
      await (_db.delete(_db.groups)
            ..where((g) => g.id.isNotIn(activeIds)))
          .go();
    }
  }

  Future<void> removeGroup(int groupId) async {
    if (groupId <= 0) return;
    await (_db.delete(_db.groups)..where((g) => g.id.equals(groupId))).go();
  }

  // Load groups from local storage
  Future<List<GroupSummary>> loadGroups() async {
    final rows = await _db.select(_db.groups).get();
    
    return rows.map((row) {
      return GroupSummary(
        id: row.id,
        name: row.name,
        avatarUrl: row.avatarUrl,
        unreadCount: row.unreadCount,
        memberCount: row.memberCount,
        updatedAt: row.updatedAt,
        type: row.type,
        isVerified: row.isVerified,
        lastMessage: row.lastMessage,
        lastMessageFromMe: row.lastMessageFromMe,
        lastMessageOutgoingStatus: row.lastMessageOutgoingStatus,
        isPinned: row.isPinned,
        isMuted: row.isMuted,
        labelIds: _decodeLabelIds(row.labelIdsJson),
      );
    }).toList();
  }

  /// Pusher: remote participant edited a message — keep SQLite aligned.
  Future<void> applyMessageEdit({
    required int messageId,
    required String body,
    DateTime? editedAt,
  }) async {
    final row = await (_db.select(_db.messages)
          ..where((m) => m.id.equals(messageId))
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return;

    final msg = _storedRowToChatModel(row);
    final edited = editedAt ?? DateTime.now();
    final updated = Message(
      id: msg.id,
      clientId: msg.clientId,
      conversationId: msg.conversationId,
      groupId: msg.groupId,
      senderId: msg.senderId,
      sender: msg.sender,
      body: body,
      status: msg.status,
      createdAt: msg.createdAt,
      replyToId: msg.replyToId,
      forwardedFromId: msg.forwardedFromId,
      forwardChain: msg.forwardChain,
      attachments: msg.attachments,
      readAt: msg.readAt,
      deliveredAt: msg.deliveredAt,
      reactions: msg.reactions,
      locationData: msg.locationData,
      contactData: msg.contactData,
      callData: msg.callData,
      linkPreviews: msg.linkPreviews,
      isDeleted: msg.isDeleted,
      deletedForMe: msg.deletedForMe,
      isSystem: msg.isSystem,
      systemAction: msg.systemAction,
      messageType: msg.messageType,
      pollData: msg.pollData,
      mentionCount: msg.mentionCount,
      mentions: msg.mentions,
      referencedStatusId: msg.referencedStatusId,
      referencedStatus: msg.referencedStatus,
      referencedGroupId: msg.referencedGroupId,
      referencedGroupMessageId: msg.referencedGroupMessageId,
      referencedGroup: msg.referencedGroup,
      editedAt: edited,
      isViewOnce: msg.isViewOnce,
      viewOnceOpened: msg.viewOnceOpened,
      scheduledAt: msg.scheduledAt,
      sikaTransferData: msg.sikaTransferData,
      metadata: msg.metadata,
    );

    final list = _linkPreviewsJsonListForSave(updated);
    await (_db.update(_db.messages)..where((m) => m.id.equals(messageId)))
        .write(
      MessagesCompanion(
        body: Value(body),
        linkPreviewsJson: Value(
          list.isNotEmpty ? jsonEncode(list) : row.linkPreviewsJson,
        ),
        lastSyncedAt: Value(DateTime.now()),
      ),
    );
  }

  /// After a successful server delete, keep SQLite aligned so reload/offline lists match UI.
  Future<void> applyMessageDeletion(
    int messageId, {
    required bool deleteForEveryone,
  }) async {
    if (deleteForEveryone) {
      await (_db.update(_db.messages)..where((m) => m.id.equals(messageId)))
          .write(
        MessagesCompanion(
          isDeleted: const Value(true),
          deletedForMe: const Value(false),
          body: const Value(''),
          attachmentsJson: const Value('[]'),
          reactionsJson: const Value<String?>(null),
          locationDataJson: const Value<String?>(null),
          contactDataJson: const Value<String?>(null),
          callDataJson: const Value<String?>(null),
          linkPreviewsJson: const Value<String?>(null),
        ),
      );
    } else {
      await (_db.update(_db.messages)..where((m) => m.id.equals(messageId)))
          .write(
        const MessagesCompanion(deletedForMe: Value(true)),
      );
    }
  }

  // Clear old data (optional cleanup)
  Future<void> clearOldData({Duration? olderThan}) async {
    final cutoff = olderThan != null 
        ? DateTime.now().subtract(olderThan)
        : DateTime.now().subtract(const Duration(days: 30));
    
    await (_db.delete(_db.messages)
          ..where((tbl) => tbl.lastSyncedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return LocalStorageService(db);
});

// Static cache to prevent multiple database instances
AppDatabase? _cachedDatabaseInstance;

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  // Close old instance if it exists (e.g., on account switch)
  if (_cachedDatabaseInstance != null) {
    _cachedDatabaseInstance!.close();
    _cachedDatabaseInstance = null;
  }
  
  // Create new instance
  final database = AppDatabase();
  _cachedDatabaseInstance = database;
  
  // Dispose database when provider is disposed
  ref.onDispose(() {
    if (_cachedDatabaseInstance == database) {
      database.close();
      _cachedDatabaseInstance = null;
    }
  });
  
  return database;
});
