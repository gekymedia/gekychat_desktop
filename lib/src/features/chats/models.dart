import 'package:flutter/foundation.dart';

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
    return User(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      isOnline: json['online'] as bool?,
      lastSeenAt: json['last_seen_at'] != null 
          ? DateTime.parse(json['last_seen_at'])
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
      avatarUrl: json['avatar_url'],
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
  final int unreadCount;
  final DateTime? updatedAt;
  final bool isPinned;
  final bool isMuted;
  final DateTime? archivedAt;

  ConversationSummary({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    required this.unreadCount,
    this.updatedAt,
    this.isPinned = false,
    this.isMuted = false,
    this.archivedAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final otherUserJson = json['other_user'];
    User otherUser;
    if (otherUserJson != null && otherUserJson is Map && otherUserJson.isNotEmpty) {
      otherUser = User.fromJson(Map<String, dynamic>.from(otherUserJson));
    } else {
      // Fallback: create a minimal user object
      otherUser = User(
        id: json['other_user_id'] ?? 0,
        name: json['title'] ?? 'Unknown',
        phone: null,
        avatarUrl: null,
        isOnline: null,
        lastSeenAt: null,
      );
    }
    
    // Filter out scaffold/test messages from preview
    String? lastMessage = json['last_message']?['body_preview'];
    if (lastMessage != null && lastMessage.toLowerCase().contains('scaffold')) {
      lastMessage = null; // Hide scaffold messages
    }
    
    return ConversationSummary(
      id: json['id'],
      otherUser: otherUser,
      lastMessage: lastMessage,
      unreadCount: json['unread'] ?? json['unread_count'] ?? 0,
      updatedAt: json['last_message']?['created_at'] != null
          ? DateTime.parse(json['last_message']['created_at'])
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null),
      isPinned: json['pinned'] ?? false,
      isMuted: json['muted'] ?? false,
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'])
          : null,
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
  final bool isPinned;
  final bool isMuted;

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
    this.isPinned = false,
    this.isMuted = false,
  });

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    // Handle avatar_url - if it's a relative path, make it absolute
    String? avatarUrl = json['avatar_url'] ?? json['avatar'];
    if (avatarUrl != null && !avatarUrl.startsWith('http')) {
      // If it's a storage path, it should be converted to full URL by backend
      // But if it's just a path like "groups/avatars/xyz.jpg", we need the base URL
      // For now, assume backend returns full URL or null
    }
    
    return GroupSummary(
      id: json['id'],
      name: json['name'],
      avatarUrl: avatarUrl,
      unreadCount: json['unread'] ?? json['unread_count'] ?? 0,
      memberCount: json['member_count'] ?? json['members_count'],
      updatedAt: json['last_message']?['created_at'] != null
          ? DateTime.parse(json['last_message']['created_at'])
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null),
      type: json['type'],
      isVerified: json['is_verified'],
      lastMessage: json['last_message']?['body_preview'],
      isPinned: json['pinned'] ?? false,
      isMuted: json['muted'] ?? false,
    );
  }
}

class MessageAttachment {
  final int id;
  final String url;
  final String mimeType;
  final bool isImage;
  final bool isVideo;
  final bool isDocument;

  MessageAttachment({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.isImage,
    required this.isVideo,
    required this.isDocument,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'],
      url: json['url'],
      mimeType: json['mime_type'],
      isImage: json['is_image'] ?? false,
      isVideo: json['is_video'] ?? false,
      isDocument: json['is_document'] ?? false,
    );
  }
}

class Reaction {
  final int userId;
  final String emoji;

  Reaction({required this.userId, required this.emoji});

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      userId: json['user_id'],
      emoji: json['emoji'],
    );
  }
}

class Message {
  final int id;
  final int? conversationId; // Nullable because group messages don't have conversation_id
  final int? groupId; // Nullable because DM messages don't have group_id
  final int senderId;
  final String body;
  final DateTime createdAt;
  final int? replyToId;
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

  Message({
    required this.id,
    this.conversationId,
    this.groupId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.replyToId,
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
    
    // Safely get sender_id - can be direct or from sender object
    final senderId = json['sender_id'] ?? json['sender']?['id'];
    if (senderId == null) {
      throw FormatException('Message missing sender_id', json);
    }
    
    return Message(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int?,
      groupId: json['group_id'] as int?,
      senderId: senderId as int,
      body: json['body'] ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      replyToId: json['reply_to_id'] as int?,
      forwardedFromId: json['forwarded_from_id'] as int?,
      forwardChain: json['forward_chain'],
      attachments: attachments,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
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
      linkPreviews: json['link_previews'] != null
          ? List<dynamic>.from(json['link_previews'] as List)
          : null,
    );
  }
}

