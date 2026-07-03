import 'package:flutter/foundation.dart';
import '../../utils/storage_url.dart';

class User {
  final int id;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final bool? isOnline;
  final DateTime? lastSeenAt;

  User({
    required this.id,
    required this.name,
    this.phone,
    this.avatarUrl,
    this.isOnline,
    this.lastSeenAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Get name - prefer non-empty name, fallback to phone, then "Unknown"
    String userName = 'Unknown';
    if (json['name'] != null && json['name'].toString().isNotEmpty && json['name'].toString() != 'Unknown') {
      userName = json['name'].toString();
    } else if (json['phone'] != null && json['phone'].toString().isNotEmpty) {
      userName = json['phone'].toString();
    }
    
    return User(
      id: json['id'] ?? 0,
      name: userName,
      phone: json['phone']?.toString() ?? json['phone_number']?.toString(),
      avatarUrl: resolveStorageUrl(json['avatar_url']?.toString()),
      isOnline: json['is_online'] == true || json['online'] == true,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString())
          : null,
    );
  }
}

class GekyContact {
  final int id;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final bool isRegistered;
  final int? contactUserId; // User ID if registered
  final Map<String, dynamic>? contactUser; // User object if registered

  GekyContact({
    required this.id,
    required this.name,
    this.phone,
    this.avatarUrl,
    required this.isRegistered,
    this.contactUserId,
    this.contactUser,
  });

  factory GekyContact.fromJson(Map<String, dynamic> json) {
    // API can return contact_user_id or user_id (from formatContact)
    final contactUserId = json['contact_user_id'] as int? ?? json['user_id'] as int?;
    final contactUser = json['contact_user'] as Map<String, dynamic>?;
    final isRegistered = contactUserId != null || contactUser != null || (json['is_registered'] == true);
    
    return GekyContact(
      id: json['id'],
      name: json['display_name'] ?? json['name'] ?? json['user_name'] ?? '',
      phone: json['phone'] ?? json['user_phone'],
      avatarUrl: resolveStorageUrl(
          json['avatar_url']?.toString() ??
          (json['contact_user'] as Map<String, dynamic>?)?['avatar_url']?.toString()),
      isRegistered: isRegistered,
      contactUserId: contactUserId,
      contactUser: contactUser,
    );
  }
}

class ConversationSummary {
  final int id;
  final User otherUser;
  final String? lastMessage;
  /// API `last_message.is_from_me` — your message shows read/delivered ticks in the list.
  final bool lastMessageFromMe;
  /// When [lastMessageFromMe]: `sent` | `delivered` | `read` from API `outgoing_status`.
  final String? lastMessageOutgoingStatus;
  final int unreadCount;
  final DateTime? updatedAt;
  final bool isPinned;
  final bool isMuted;
  final DateTime? archivedAt;
  final List<int> labelIds; // List of label IDs assigned to this conversation
  final bool isSavedMessages;

  ConversationSummary({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.lastMessageFromMe = false,
    this.lastMessageOutgoingStatus,
    required this.unreadCount,
    this.updatedAt,
    this.isPinned = false,
    this.isMuted = false,
    this.archivedAt,
    this.labelIds = const [],
    this.isSavedMessages = false,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final j = ConversationSummary._unwrapConversationPayload(json);
    final otherUserJson = j['other_user'];
    User otherUser;
    
    // Try to parse other_user first
    if (otherUserJson != null && otherUserJson is Map) {
      final otherUserMap = Map<String, dynamic>.from(otherUserJson);
      // Even if map is empty, try to parse it (might have null values)
      if (otherUserMap.containsKey('id') || otherUserMap.containsKey('name') || otherUserMap.containsKey('phone')) {
        otherUser = User.fromJson(otherUserMap);
        // If name is still "Unknown" or empty after parsing, try to use title
        if ((otherUser.name == 'Unknown' || otherUser.name.isEmpty) && j['title'] != null) {
          final title = j['title'].toString();
          if (title.isNotEmpty && !title.startsWith('DM #')) {
            otherUser = User(
              id: otherUser.id,
              name: title,
              phone: otherUser.phone,
              avatarUrl: otherUser.avatarUrl,
              isOnline: otherUser.isOnline,
              lastSeenAt: otherUser.lastSeenAt,
            );
          }
        }
      } else {
        // Empty map - use fallback
        otherUser = ConversationSummary._createFallbackUser(j);
      }
    } else {
      // No other_user - use fallback
      otherUser = ConversationSummary._createFallbackUser(j);
    }
    
    Map<String, dynamic>? lastMessageMap;
    final rawLm = j['last_message'];
    if (rawLm is Map) {
      lastMessageMap = Map<String, dynamic>.from(rawLm);
    }

    String? lastMessage = lastMessageMap?['body_preview']?.toString();
    if (lastMessage != null && lastMessage.toLowerCase().contains('scaffold')) {
      lastMessage = null;
    }

    String? outgoingStatus;
    final os = lastMessageMap?['outgoing_status']?.toString();
    if (os == 'read' || os == 'delivered' || os == 'sent') {
      outgoingStatus = os;
    }

    // Parse labels - can be array of objects with 'id' or array of IDs
    List<int> labelIds = [];
    if (j['labels'] != null) {
      if (j['labels'] is List) {
        labelIds = (j['labels'] as List).map((label) {
          if (label is Map) {
            return label['id'] as int? ?? 0;
          } else if (label is int) {
            return label;
          }
          return 0;
        }).where((id) => id > 0).toList();
      }
    }

    int conversationId = 0;
    if (j['id'] is int) {
      conversationId = j['id'] as int;
    } else if (j['id'] != null) {
      conversationId = int.tryParse(j['id'].toString()) ?? 0;
    }

    int unread = 0;
    final rawUnread = j['unread'] ?? j['unread_count'];
    if (rawUnread is int) {
      unread = rawUnread;
    } else if (rawUnread != null) {
      unread = int.tryParse(rawUnread.toString()) ?? 0;
    }
    
    return ConversationSummary(
      id: conversationId,
      otherUser: otherUser,
      lastMessage: lastMessage,
      lastMessageFromMe: lastMessageMap?['is_from_me'] == true,
      lastMessageOutgoingStatus: outgoingStatus,
      unreadCount: unread,
      updatedAt: lastMessageMap?['created_at'] != null
          ? DateTime.parse(lastMessageMap!['created_at'].toString())
          : (j['updated_at'] != null
              ? DateTime.parse(j['updated_at'].toString())
              : null),
      isPinned: j['pinned'] ?? false,
      isMuted: j['muted'] ?? false,
      archivedAt: j['archived_at'] != null
          ? DateTime.parse(j['archived_at'].toString())
          : null,
      labelIds: labelIds,
      isSavedMessages: j['is_saved_messages'] == true,
    );
  }

  /// Laravel wraps `GET /conversations/{id}` as `{ "data": { ... } }`.
  static Map<String, dynamic> _unwrapConversationPayload(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) {
      final d = Map<String, dynamic>.from(data);
      if (d['id'] != null && json['id'] == null) {
        return d;
      }
    }
    return Map<String, dynamic>.from(json);
  }
  
  // Helper method to create fallback user
  static User _createFallbackUser(Map<String, dynamic> json) {
    int otherUserId = 0;
    if (json['other_user_id'] != null) {
      if (json['other_user_id'] is int) {
        otherUserId = json['other_user_id'] as int;
      } else if (json['other_user_id'] is String) {
        otherUserId = int.tryParse(json['other_user_id'] as String) ?? 0;
      }
    }
    
    // Use title if it's not a "DM #X" format, otherwise use "Unknown"
    String fallbackName = 'Unknown';
    final title = json['title']?.toString() ?? '';
    if (title.isNotEmpty && !title.startsWith('DM #')) {
      fallbackName = title;
    } else if (otherUserId > 0) {
      // If we have an ID but no name, use a generic name
      fallbackName = 'User $otherUserId';
    }
    
    return User(
      id: otherUserId,
      name: fallbackName,
      phone: null,
      avatarUrl: null,
      isOnline: null,
      lastSeenAt: null,
    );
  }
}

class GroupSummary {
  final int id;
  final String name;
  final String? avatarUrl;
  final int unreadCount;
  final int? memberCount;
  final DateTime? updatedAt;
  final String? type; // 'group' or 'channel'
  final bool? isVerified;
  final String? lastMessage;
  final bool lastMessageFromMe;
  final String? lastMessageOutgoingStatus;
  final bool isPinned;
  final bool isMuted;
  final List<int> labelIds;

  GroupSummary({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.unreadCount,
    this.memberCount,
    this.updatedAt,
    this.type,
    this.isVerified,
    this.lastMessage,
    this.lastMessageFromMe = false,
    this.lastMessageOutgoingStatus,
    this.isPinned = false,
    this.isMuted = false,
    this.labelIds = const [],
  });

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    // Handle avatar_url - if it's a relative path, make it absolute
    String? avatarUrl = json['avatar_url'] ?? json['avatar'];
    if (avatarUrl != null && !avatarUrl.startsWith('http')) {
      // If it's a storage path, it should be converted to full URL by backend
      // But if it's just a path like "groups/avatars/xyz.jpg", we need the base URL
      // For now, assume backend returns full URL or null
    }
    
    Map<String, dynamic>? gLastMap;
    final rawGLm = json['last_message'];
    if (rawGLm is Map) {
      gLastMap = Map<String, dynamic>.from(rawGLm);
    }
    String? gOutgoing;
    final gos = gLastMap?['outgoing_status']?.toString();
    if (gos == 'read' || gos == 'delivered' || gos == 'sent') {
      gOutgoing = gos;
    }

    List<int> labelIds = [];
    if (json['labels'] != null && json['labels'] is List) {
      for (final item in json['labels'] as List) {
        if (item is Map && item['id'] != null) {
          final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id'].toString());
          if (id != null && id > 0) labelIds.add(id);
        } else if (item is int && item > 0) {
          labelIds.add(item);
        }
      }
    }

    return GroupSummary(
      id: json['id'],
      name: json['name'],
      avatarUrl: avatarUrl,
      unreadCount: json['unread'] ?? json['unread_count'] ?? 0,
      memberCount: json['member_count'] ?? json['members_count'],
      updatedAt: gLastMap?['created_at'] != null
          ? DateTime.parse(gLastMap!['created_at'].toString())
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'].toString())
              : null),
      type: json['type'],
      isVerified: json['is_verified'],
      lastMessage: gLastMap?['body_preview']?.toString(),
      lastMessageFromMe: gLastMap?['is_from_me'] == true,
      lastMessageOutgoingStatus: gOutgoing,
      isPinned: json['pinned'] ?? false,
      isMuted: json['muted'] ?? false,
      labelIds: labelIds,
    );
  }
}

class MessageAttachment {
  final int id;
  final String url;
  final String mimeType;
  final bool isImage;
  final bool isVideo;
  final bool isAudio;
  final bool isDocument;
  final String? originalName;
  final bool sharedAsDocument;
  final bool isVoicenote;
  // MEDIA COMPRESSION fields
  final String? compressionStatus; // 'pending', 'processing', 'completed', 'failed'
  final String? compressedUrl;
  final String? thumbnailUrl;
  final int? originalSize;
  final int? compressedSize;
  final String? compressionLevel; // 'low', 'medium', 'high'

  MessageAttachment({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.isImage,
    required this.isVideo,
    required this.isAudio,
    required this.isDocument,
    this.originalName,
    this.sharedAsDocument = false,
    this.isVoicenote = false,
    this.compressionStatus,
    this.compressedUrl,
    this.thumbnailUrl,
    this.originalSize,
    this.compressedSize,
    this.compressionLevel,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    int? intField(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    return MessageAttachment(
      id: intField(json['id']) ?? 0,
      url: json['url']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? 'application/octet-stream',
      isImage: json['is_image'] ?? false,
      isVideo: json['is_video'] ?? false,
      isAudio: json['is_audio'] ?? false,
      isDocument: json['is_document'] ?? false,
      originalName: json['original_name'] as String?,
      sharedAsDocument: json['shared_as_document'] == true,
      isVoicenote: json['is_voicenote'] == true,
      // MEDIA COMPRESSION fields
      compressionStatus: json['compression_status'] as String?,
      compressedUrl: json['compressed_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      originalSize: intField(json['original_size']),
      compressedSize: intField(json['compressed_size']),
      compressionLevel: json['compression_level'] as String?,
    );
  }

  /// Get the best available URL (compressed if available, otherwise original)
  String get displayUrl => compressedUrl ?? url;

  /// Check if compression is complete
  bool get isCompressed => compressionStatus == 'completed' && compressedUrl != null;

  /// Check if compression is in progress
  bool get isCompressing => compressionStatus == 'processing' || compressionStatus == 'pending';
}

class Reaction {
  final int userId;
  final String emoji;

  Reaction({required this.userId, required this.emoji});

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      userId: json['user_id'] ?? 0,
      emoji: json['emoji']?.toString() ?? '👍', // Default to thumbs up if null
    );
  }
}

DateTime _parseMessageDate(dynamic raw, int messageId) {
  if (raw == null || raw.toString().trim().isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
  }
  try {
    return DateTime.parse(raw.toString());
  } catch (_) {
    debugPrint('Message $messageId: invalid created_at "$raw", using epoch');
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
  }
}

List<dynamic>? _linkPreviewsFromJson(dynamic raw) {
  if (raw == null) return null;
  if (raw is List) return List<dynamic>.from(raw);
  return null;
}

class Message {
  final int id;
  /// Client-generated UUID used for idempotency and offline-first deduplication.
  final String? clientId;
  final int? conversationId;
  final int? groupId;
  final int senderId;
  final Map<String, dynamic>? sender;
  final String body;
  final DateTime createdAt;
  final int? replyToId;
  /// Nested preview from API `reply_to: { id, sender_id, body_preview }`.
  final Map<String, dynamic>? replyToPreview;
  final int? forwardedFromId;
  final List<dynamic>? forwardChain;
  final List<MessageAttachment> attachments;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  final List<Reaction> reactions;
  final Map<String, dynamic>? locationData;
  final Map<String, dynamic>? contactData;
  final Map<String, dynamic>? callData;
  final List<dynamic>? linkPreviews;
  final bool isDeleted;
  final bool deletedForMe;
  final String? status;
  final bool isSystem;
  final String? systemAction;
  final int mentionCount;
  final List<dynamic>? mentions;
  final String? messageType;
  final int? referencedStatusId;
  final Map<String, dynamic>? referencedStatus;
  final int? referencedGroupId;
  final int? referencedGroupMessageId;
  final Map<String, dynamic>? referencedGroup;
  /// When the message body was last edited (shows "Edited" label in UI).
  final DateTime? editedAt;
  /// View-once media: after the recipient opens it once, it becomes inaccessible.
  final bool isViewOnce;
  final bool viewOnceOpened;
  /// Sika coin transfer payload (from `sika_transfer_data` or `metadata.sika_transfer`).
  final Map<String, dynamic>? sikaTransferData;
  /// Scheduled send time (returned from API; null for regular messages).
  final DateTime? scheduledAt;
  /// Server poll payload (`poll_data` / `poll`); required for poll UI when offline on desktop cache.
  final Map<String, dynamic>? pollData;
  /// DM-only JSON metadata from the API (parity with Laravel `messages.metadata`).
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    this.clientId,
    this.conversationId,
    this.groupId,
    required this.senderId,
    this.sender,
    required this.body,
    required this.createdAt,
    this.replyToId,
    this.replyToPreview,
    this.forwardedFromId,
    this.forwardChain,
    required this.attachments,
    this.readAt,
    this.deliveredAt,
    required this.reactions,
    this.locationData,
    this.contactData,
    this.callData,
    this.linkPreviews,
    this.isDeleted = false,
    this.deletedForMe = false,
    this.status,
    this.isSystem = false,
    this.systemAction,
    this.mentionCount = 0,
    this.mentions,
    this.messageType,
    this.referencedStatusId,
    this.referencedStatus,
    this.referencedGroupId,
    this.referencedGroupMessageId,
    this.referencedGroup,
    this.editedAt,
    this.isViewOnce = false,
    this.viewOnceOpened = false,
    this.sikaTransferData,
    this.scheduledAt,
    this.pollData,
    this.metadata,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Handle attachments - could be List, null, or other type
    List<MessageAttachment> attachments = [];
    final attachmentsData = json['attachments'];
    if (attachmentsData is List) {
      attachments = attachmentsData
          .map((attachment) {
            try {
              return MessageAttachment.fromJson(
                attachment is Map<String, dynamic>
                    ? attachment
                    : Map<String, dynamic>.from(attachment as Map),
              );
            } catch (e) {
              debugPrint('Error parsing attachment: $e');
              return null;
            }
          })
          .whereType<MessageAttachment>()
          .toList();
    }
    
    // Handle reactions - could be List, null, or other type
    List<Reaction> reactions = [];
    final reactionsData = json['reactions'];
    if (reactionsData is List) {
      reactions = reactionsData
          .map((reaction) {
            try {
              return Reaction.fromJson(
                reaction is Map<String, dynamic>
                    ? reaction
                    : Map<String, dynamic>.from(reaction as Map),
              );
            } catch (e) {
              debugPrint('Error parsing reaction: $e');
              return null;
            }
          })
          .whereType<Reaction>()
          .toList();
    }
    
    // System messages don't have a sender_id, so we need to handle that case
    final isSystem =
        json['is_system'] == true || json['is_system'] == 1;
    final senderId = json['sender_id'] ?? json['sender']?['id'];
    if (senderId == null && !isSystem) {
      throw FormatException('Message missing sender_id', json);
    }
    
    // Extract sender info for group messages
    Map<String, dynamic>? senderInfo;
    if (json['sender'] != null && json['sender'] is Map) {
      senderInfo = Map<String, dynamic>.from(json['sender'] as Map);
    }

    int? conversationId;
    final convRaw = json['conversation_id'];
    if (convRaw is int) {
      conversationId = convRaw;
    } else if (convRaw != null) {
      conversationId = int.tryParse(convRaw.toString());
    }

    int? groupId;
    final groupRaw = json['group_id'];
    if (groupRaw is int) {
      groupId = groupRaw;
    } else if (groupRaw != null) {
      groupId = int.tryParse(groupRaw.toString());
    }

    int? replyToId;
    Map<String, dynamic>? replyToPreview;
    if (json['reply_to_id'] != null) {
      final raw = json['reply_to_id'];
      replyToId = raw is int ? raw : int.tryParse(raw.toString());
    } else if (json['reply_to'] is int) {
      replyToId = json['reply_to'] as int;
    } else if (json['reply_to'] is String) {
      replyToId = int.tryParse(json['reply_to'] as String);
    } else if (json['reply_to'] is Map) {
      final replyMap = Map<String, dynamic>.from(json['reply_to'] as Map);
      replyToPreview = replyMap;
      final rawId = replyMap['id'];
      replyToId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    }

    int? forwardedFromId;
    final fwdRaw = json['forwarded_from_id'];
    if (fwdRaw is int) {
      forwardedFromId = fwdRaw;
    } else if (fwdRaw != null) {
      forwardedFromId = int.tryParse(fwdRaw.toString());
    }

    String? clientId;
    final rawClient =
        json['client_message_id'] ?? json['client_uuid'] ?? json['client_id'];
    if (rawClient is String) {
      clientId = rawClient;
    } else if (rawClient != null) {
      clientId = rawClient.toString();
    }

    int? referencedStatusId;
    final refRaw = json['referenced_status_id'];
    if (refRaw is int) {
      referencedStatusId = refRaw;
    } else if (refRaw != null) {
      referencedStatusId = int.tryParse(refRaw.toString());
    }
    Map<String, dynamic>? referencedStatus;
    if (json['referenced_status'] is Map) {
      referencedStatus = Map<String, dynamic>.from(json['referenced_status'] as Map);
    }

    int? referencedGroupId;
    final rgIdRaw = json['referenced_group_id'];
    if (rgIdRaw is int) {
      referencedGroupId = rgIdRaw;
    } else if (rgIdRaw != null) {
      referencedGroupId = int.tryParse(rgIdRaw.toString());
    }
    int? referencedGroupMessageId;
    final rgmRaw = json['referenced_group_message_id'];
    if (rgmRaw is int) {
      referencedGroupMessageId = rgmRaw;
    } else if (rgmRaw != null) {
      referencedGroupMessageId = int.tryParse(rgmRaw.toString());
    }
    Map<String, dynamic>? referencedGroup;
    if (json['referenced_group'] is Map) {
      referencedGroup = Map<String, dynamic>.from(json['referenced_group'] as Map);
    }
    
    // Parse sika transfer data from top-level key or metadata fallback
    Map<String, dynamic>? sikaTransferData;
    if (json['sika_transfer_data'] is Map) {
      sikaTransferData = Map<String, dynamic>.from(json['sika_transfer_data'] as Map);
    } else if (json['metadata'] is Map) {
      final meta = Map<String, dynamic>.from(json['metadata'] as Map);
      if (meta['sika_transfer'] == true) {
        sikaTransferData = meta;
      }
    }

    Map<String, dynamic>? pollData;
    if (json['poll_data'] is Map) {
      pollData = Map<String, dynamic>.from(json['poll_data'] as Map);
    } else if (json['poll'] is Map) {
      pollData = Map<String, dynamic>.from(json['poll'] as Map);
    }

    Map<String, dynamic>? metadata;
    if (json['metadata'] is Map) {
      metadata = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    final messageIdRaw = json['id'];
    var messageId = messageIdRaw is int
        ? messageIdRaw
        : int.tryParse(messageIdRaw?.toString() ?? '') ?? 0;
    if (messageId <= 0) {
      final rawClient =
          json['client_message_id'] ?? json['client_uuid'] ?? json['client_id'];
      if (rawClient != null) {
        messageId = rawClient.hashCode.abs();
      } else if (json['created_at'] != null) {
        messageId = json['created_at'].toString().hashCode.abs();
      }
    }

    String? resolvedType = json['type'] as String? ?? json['message_type'] as String?;
    if (resolvedType == null || resolvedType.isEmpty) {
      if (pollData != null) {
        resolvedType = 'poll';
      }
    }

    return Message(
      id: messageId,
      clientId: clientId,
      conversationId: conversationId,
      groupId: groupId,
      senderId: senderId is int
          ? senderId
          : int.tryParse(senderId?.toString() ?? '') ?? 0,
      sender: senderInfo,
      body: json['body'] ?? '',
      createdAt: _parseMessageDate(json['created_at'], messageId),
      replyToId: replyToId,
      replyToPreview: replyToPreview,
      forwardedFromId: forwardedFromId,
      forwardChain: json['forward_chain'],
      attachments: attachments,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'].toString())
          : null,
      editedAt: json['edited_at'] != null ? DateTime.tryParse(json['edited_at'].toString()) : null,
      isViewOnce: json['view_once'] == true || json['is_view_once'] == true,
      viewOnceOpened: json['view_once_opened'] == true,
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at'].toString()) : null,
      sikaTransferData: sikaTransferData,
      reactions: reactions,
      locationData: json['location_data'] != null
          ? Map<String, dynamic>.from(json['location_data'] as Map)
          : null,
      contactData: json['contact_data'] != null
          ? Map<String, dynamic>.from(json['contact_data'] as Map)
          : null,
      callData: json['call_data'] != null
          ? Map<String, dynamic>.from(json['call_data'] as Map)
          : null,
      linkPreviews: _linkPreviewsFromJson(json['link_previews']),
      isDeleted: json['deleted_for_everyone_at'] != null ||
          json['is_deleted'] == true ||
          json['is_deleted'] == 1,
      deletedForMe: json['deleted_at'] != null ||
          json['deleted_for_me'] == true ||
          json['deleted_for_me'] == 1,
      status: json['status']?.toString(),
      isSystem: isSystem,
      systemAction: json['system_action'] as String?,
      mentionCount: json['mention_count'] ?? 0,
      mentions: json['mentions'] is List
          ? List<dynamic>.from(json['mentions'] as List)
          : null,
      messageType: resolvedType,
      referencedStatusId: referencedStatusId,
      referencedStatus: referencedStatus,
      referencedGroupId: referencedGroupId,
      referencedGroupMessageId: referencedGroupMessageId,
      referencedGroup: referencedGroup,
      pollData: pollData,
      metadata: metadata,
    );
  }

  Message copyWith({
    bool? viewOnceOpened,
    List<Reaction>? reactions,
    Map<String, dynamic>? replyToPreview,
    String? messageType,
    Map<String, dynamic>? pollData,
  }) {
    return Message(
      id: id,
      clientId: clientId,
      conversationId: conversationId,
      groupId: groupId,
      senderId: senderId,
      sender: sender,
      body: body,
      createdAt: createdAt,
      replyToId: replyToId,
      replyToPreview: replyToPreview ?? this.replyToPreview,
      forwardedFromId: forwardedFromId,
      forwardChain: forwardChain,
      attachments: attachments,
      readAt: readAt,
      deliveredAt: deliveredAt,
      reactions: reactions ?? this.reactions,
      locationData: locationData,
      contactData: contactData,
      callData: callData,
      linkPreviews: linkPreviews,
      isDeleted: isDeleted,
      deletedForMe: deletedForMe,
      status: status,
      isSystem: isSystem,
      systemAction: systemAction,
      mentionCount: mentionCount,
      mentions: mentions,
      messageType: messageType ?? this.messageType,
      referencedStatusId: referencedStatusId,
      referencedStatus: referencedStatus,
      referencedGroupId: referencedGroupId,
      referencedGroupMessageId: referencedGroupMessageId,
      referencedGroup: referencedGroup,
      editedAt: editedAt,
      isViewOnce: isViewOnce,
      viewOnceOpened: viewOnceOpened ?? this.viewOnceOpened,
      sikaTransferData: sikaTransferData,
      scheduledAt: scheduledAt,
      pollData: pollData ?? this.pollData,
      metadata: metadata,
    );
  }
}

/// Next DM message can reference a status (opened from status viewer).
class PendingStatusReply {
  final int statusId;
  final int ownerUserId;
  final String statusType;
  final String? textPreview;
  final String? thumbnailUrl;

  const PendingStatusReply({
    required this.statusId,
    required this.ownerUserId,
    required this.statusType,
    this.textPreview,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toPreviewMap() => {
        'id': statusId,
        'user_id': ownerUserId,
        'type': statusType,
        if (textPreview != null && textPreview!.trim().isNotEmpty) 'text': textPreview,
        if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty) 'thumbnail_url': thumbnailUrl,
        'expired': false,
      };
}

/// Private reply to a specific group message from a DM.
class PendingGroupMessageReply {
  final int groupId;
  final int groupMessageId;
  final String groupName;
  final String? bodyPreview;

  const PendingGroupMessageReply({
    required this.groupId,
    required this.groupMessageId,
    required this.groupName,
    this.bodyPreview,
  });

  Map<String, dynamic> toPreviewMap() => {
        'group_id': groupId,
        'group_message_id': groupMessageId,
        'group_name': groupName,
        if (bodyPreview != null && bodyPreview!.trim().isNotEmpty) 'body_preview': bodyPreview,
      };
}

/// Desktop: open chats and attach [reply] when [conversationId] is selected.
class DesktopPendingStatusChatOpen {
  final int conversationId;
  final PendingStatusReply reply;

  const DesktopPendingStatusChatOpen({
    required this.conversationId,
    required this.reply,
  });
}

/// Desktop: open DM after "Reply privately" with group reference payload.
class DesktopPendingGroupPrivateOpen {
  final int conversationId;
  final int groupId;
  final int groupMessageId;
  final String groupName;
  final String? bodyPreview;

  const DesktopPendingGroupPrivateOpen({
    required this.conversationId,
    required this.groupId,
    required this.groupMessageId,
    required this.groupName,
    this.bodyPreview,
  });

  PendingGroupMessageReply toPendingReply() => PendingGroupMessageReply(
        groupId: groupId,
        groupMessageId: groupMessageId,
        groupName: groupName,
        bodyPreview: bodyPreview,
      );
}

