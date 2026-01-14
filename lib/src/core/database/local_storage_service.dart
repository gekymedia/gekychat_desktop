import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart' hide Message;
import '../../features/chats/models.dart';

class LocalStorageService {
  final AppDatabase _db;

  LocalStorageService(this._db);

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
            unreadCount: Value(conv.unreadCount),
            updatedAt: Value(conv.updatedAt),
            isPinned: Value(conv.isPinned),
            isMuted: Value(conv.isMuted),
            archivedAt: Value(conv.archivedAt),
            lastSyncedAt: Value(DateTime.now()),
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
        unreadCount: row.unreadCount,
        updatedAt: row.updatedAt,
        isPinned: row.isPinned,
        isMuted: row.isMuted,
        archivedAt: row.archivedAt,
      );
    }).toList();
  }

  // Save messages for a conversation
  Future<void> saveMessages(int conversationId, List<Message> messages) async {
    await _db.batch((batch) {
      for (final msg in messages) {
        batch.insert(
          _db.messages,
          MessagesCompanion(
            id: Value(msg.id),
            conversationId: Value(msg.conversationId ?? conversationId),
            groupId: Value(msg.groupId),
            senderId: Value(msg.senderId),
            senderName: Value(msg.sender?['name']),
            senderAvatarUrl: Value(msg.sender?['avatar_url']),
            body: Value(msg.body),
            createdAt: Value(msg.createdAt),
            replyToId: Value(msg.replyToId),
            forwardedFromId: Value(msg.forwardedFromId),
            attachmentsJson: Value(msg.attachments.isNotEmpty 
                ? jsonEncode(msg.attachments.map((a) => {
                  'id': a.id,
                  'url': a.url,
                  'mime_type': a.mimeType,
                  'is_image': a.isImage,
                  'is_video': a.isVideo,
                  'is_document': a.isDocument,
                }).toList())
                : null),
            readAt: Value(msg.readAt),
            deliveredAt: Value(msg.deliveredAt),
            reactionsJson: Value(msg.reactions.isNotEmpty
                ? jsonEncode(msg.reactions.map((r) => {
                  'user_id': r.userId,
                  'emoji': r.emoji,
                }).toList())
                : null),
            locationDataJson: Value(msg.locationData != null 
                ? jsonEncode(msg.locationData) 
                : null),
            contactDataJson: Value(msg.contactData != null 
                ? jsonEncode(msg.contactData) 
                : null),
            callDataJson: Value(msg.callData != null 
                ? jsonEncode(msg.callData) 
                : null),
            linkPreviewsJson: Value(msg.linkPreviews != null 
                ? jsonEncode(msg.linkPreviews) 
                : null),
            isDeleted: Value(msg.isDeleted),
            deletedForMe: Value(msg.deletedForMe),
            lastSyncedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.replace,
        );
      }
    });
  }

  // Load messages from local storage
  Future<List<Message>> loadMessages(int conversationId) async {
    final rows = await (_db.select(_db.messages)
          ..where((tbl) => tbl.conversationId.equals(conversationId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .get();
    
    return rows.map((row) {
      // Parse attachments
      List<MessageAttachment> attachments = [];
      if (row.attachmentsJson != null) {
        try {
          final attList = jsonDecode(row.attachmentsJson!) as List;
          attachments = attList.map((a) => MessageAttachment.fromJson(a)).toList();
        } catch (e) {
          // Ignore parse errors
        }
      }
      
      // Parse reactions
      List<Reaction> reactions = [];
      if (row.reactionsJson != null) {
        try {
          final reactList = jsonDecode(row.reactionsJson!) as List;
          reactions = reactList.map((r) => Reaction.fromJson(r)).toList();
        } catch (e) {
          // Ignore parse errors
        }
      }
      
      // Parse sender info
      Map<String, dynamic>? sender;
      if (row.senderName != null) {
        sender = {
          'name': row.senderName,
          'avatar_url': row.senderAvatarUrl,
        };
      }
      
      return Message(
        id: row.id,
        conversationId: row.conversationId,
        groupId: row.groupId,
        senderId: row.senderId,
        sender: sender,
        body: row.body,
        createdAt: row.createdAt,
        replyToId: row.replyToId,
        forwardedFromId: row.forwardedFromId,
        attachments: attachments,
        readAt: row.readAt,
        deliveredAt: row.deliveredAt,
        reactions: reactions,
        locationData: row.locationDataJson != null 
            ? jsonDecode(row.locationDataJson!) as Map<String, dynamic>
            : null,
        contactData: row.contactDataJson != null 
            ? jsonDecode(row.contactDataJson!) as Map<String, dynamic>
            : null,
        callData: row.callDataJson != null 
            ? jsonDecode(row.callDataJson!) as Map<String, dynamic>
            : null,
        linkPreviews: row.linkPreviewsJson != null 
            ? jsonDecode(row.linkPreviewsJson!) as List
            : null,
        isDeleted: row.isDeleted,
        deletedForMe: row.deletedForMe,
      );
    }).toList();
  }

  // Save groups
  Future<void> saveGroups(List<GroupSummary> groups) async {
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
            isPinned: Value(group.isPinned),
            isMuted: Value(group.isMuted),
            lastSyncedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.replace,
        );
      }
    });
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
        isPinned: row.isPinned,
        isMuted: row.isMuted,
      );
    }).toList();
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
