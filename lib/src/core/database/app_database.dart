import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

part 'app_database.g.dart';

// Conversations table
class Conversations extends Table {
  IntColumn get id => integer()();
  IntColumn get otherUserId => integer().nullable()();
  TextColumn get otherUserName => text().nullable()();
  TextColumn get otherUserPhone => text().nullable()();
  TextColumn get otherUserAvatarUrl => text().nullable()();
  TextColumn get lastMessage => text().nullable()();
  BoolColumn get lastMessageFromMe =>
      boolean().withDefault(const Constant(false))();
  TextColumn get lastMessageOutgoingStatus => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  /// JSON array of label IDs (parity with API `labels` / mobile `labelIdsJson`).
  TextColumn get labelIdsJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}

// Messages table
class Messages extends Table {
  IntColumn get id => integer().nullable()(); // Nullable for pending messages
  TextColumn get clientUuid => text()(); // Client-side UUID for offline-first support (PK)
  IntColumn get conversationId => integer().nullable()();
  IntColumn get groupId => integer().nullable()();
  IntColumn get senderId => integer()();
  TextColumn get senderName => text().nullable()();
  TextColumn get senderAvatarUrl => text().nullable()();
  TextColumn get body => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, sending, sent, delivered, read, failed
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get serverCreatedAt => dateTime().nullable()();
  IntColumn get replyToId => integer().nullable()();
  IntColumn get forwardedFromId => integer().nullable()();
  TextColumn get attachmentsJson => text().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  TextColumn get reactionsJson => text().nullable()();
  TextColumn get locationDataJson => text().nullable()();
  TextColumn get contactDataJson => text().nullable()();
  TextColumn get callDataJson => text().nullable()();
  TextColumn get linkPreviewsJson => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedForMe => boolean().withDefault(const Constant(false))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get systemAction => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

// Groups table
class Groups extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get avatarUrl => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get memberCount => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get type => text().nullable()(); // 'group' or 'channel'
  BoolColumn get isVerified => boolean().nullable()();
  TextColumn get lastMessage => text().nullable()();
  BoolColumn get lastMessageFromMe =>
      boolean().withDefault(const Constant(false))();
  TextColumn get lastMessageOutgoingStatus => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get labelIdsJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}

// Offline message queue table
class OfflineMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Stable client UUID generated when the message is first queued.
  /// This same UUID is sent to the server for idempotency so retries don't create duplicates.
  TextColumn get clientUuid => text().nullable()();
  IntColumn get conversationId => integer().nullable()();
  IntColumn get groupId => integer().nullable()();
  TextColumn get body => text()();
  IntColumn get replyToId => integer().nullable()();
  IntColumn get forwardFromId => integer().nullable()();
  TextColumn get attachmentsJson => text().nullable()(); // JSON array of file paths
  TextColumn get locationDataJson => text().nullable()(); // JSON string of location data
  TextColumn get contactDataJson => text().nullable()(); // JSON string of contact data
  TextColumn get messageType => text().nullable()();
  BoolColumn get viewOnce => boolean().withDefault(const Constant(false))();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  IntColumn get expiresInHours => integer().nullable()();
  /// DM reply-to-status / reply-to-group-message (API fields).
  IntColumn get referencedStatusId => integer().nullable()();
  IntColumn get referencedGroupId => integer().nullable()();
  IntColumn get referencedGroupMessageId => integer().nullable()();
  /// JSON: optional `referenced_status` / `referenced_group` maps for optimistic UI replay.
  TextColumn get referencedContextJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSent => boolean().withDefault(const Constant(false))();
  IntColumn get serverMessageId => integer().nullable()(); // ID from server after sending
  TextColumn get errorMessage => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [Conversations, Messages, Groups, OfflineMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7;

  Future<void> _recreateMessagesTable(Migrator m) async {
    await customStatement('DROP TABLE IF EXISTS messages;');
    await m.createTable(messages);
  }

  /// Older desktop builds created `messages` without `client_uuid` (PK). Drift
  /// then fails every INSERT — chats look empty even when the API returns data.
  Future<void> _ensureMessagesTableHasClientUuid(Migrator m) async {
    final cols = await customSelect(
      "SELECT name FROM pragma_table_info('messages')",
    ).map((row) => row.read<String>('name')).get();
    if (cols.isEmpty) {
      await m.createTable(messages);
      return;
    }
    if (!cols.contains('client_uuid')) {
      debugPrint(
        '🔄 Recreating messages table: legacy schema missing client_uuid',
      );
      await _recreateMessagesTable(m);
    }
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (OpeningDetails details) async {
        if (!details.hadUpgrade) {
          await _ensureMessagesTableHasClientUuid(Migrator(this));
        }
      },
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          await m.addColumn(offlineMessages, offlineMessages.referencedStatusId);
          await m.addColumn(offlineMessages, offlineMessages.referencedGroupId);
          await m.addColumn(
              offlineMessages, offlineMessages.referencedGroupMessageId);
          await m.addColumn(
              offlineMessages, offlineMessages.referencedContextJson);
        }
        if (from < 4) {
          await m.addColumn(conversations, conversations.lastMessageFromMe);
          await m.addColumn(
              conversations, conversations.lastMessageOutgoingStatus);
          await m.addColumn(groups, groups.lastMessageFromMe);
          await m.addColumn(groups, groups.lastMessageOutgoingStatus);
        }
        if (from < 5) {
          await m.addColumn(offlineMessages, offlineMessages.clientUuid);
          await m.addColumn(offlineMessages, offlineMessages.messageType);
          await m.addColumn(offlineMessages, offlineMessages.viewOnce);
          await m.addColumn(offlineMessages, offlineMessages.scheduledAt);
          await m.addColumn(offlineMessages, offlineMessages.expiresInHours);
          await m.addColumn(messages, messages.isSystem);
          await m.addColumn(messages, messages.systemAction);
        }
        if (from < 6) {
          await m.addColumn(conversations, conversations.labelIdsJson);
          await m.addColumn(groups, groups.labelIdsJson);
        }
        if (from < 7) {
          await _ensureMessagesTableHasClientUuid(m);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    
    // Get phone number from SharedPreferences for account-specific database
    String dbFileName;
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('user_phone');
      
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        // Sanitize phone number for use in filename (remove special characters)
        final sanitizedPhone = phoneNumber.replaceAll(RegExp(r'[^\w]'), '_');
        dbFileName = 'gekychat_offline_$sanitizedPhone.db';
      } else {
        // Fallback to default database if no phone number
        dbFileName = 'gekychat_offline.db';
      }
    } catch (e) {
      // If we can't get phone number, use default database
      dbFileName = 'gekychat_offline.db';
    }
    
    final file = File(p.join(dbFolder.path, dbFileName));
    return NativeDatabase(file);
  });
}
