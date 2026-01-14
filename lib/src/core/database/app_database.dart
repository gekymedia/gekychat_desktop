import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

// Messages table
class Messages extends Table {
  IntColumn get id => integer()();
  IntColumn get conversationId => integer().nullable()();
  IntColumn get groupId => integer().nullable()();
  IntColumn get senderId => integer()();
  TextColumn get senderName => text().nullable()();
  TextColumn get senderAvatarUrl => text().nullable()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get replyToId => integer().nullable()();
  IntColumn get forwardedFromId => integer().nullable()();
  TextColumn get attachmentsJson => text().nullable()(); // JSON string of attachments
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  TextColumn get reactionsJson => text().nullable()(); // JSON string of reactions
  TextColumn get locationDataJson => text().nullable()(); // JSON string of location data
  TextColumn get contactDataJson => text().nullable()(); // JSON string of contact data
  TextColumn get callDataJson => text().nullable()(); // JSON string of call data
  TextColumn get linkPreviewsJson => text().nullable()(); // JSON string of link previews
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedForMe => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
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
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

// Offline message queue table
class OfflineMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get conversationId => integer().nullable()();
  IntColumn get groupId => integer().nullable()();
  TextColumn get body => text()();
  IntColumn get replyToId => integer().nullable()();
  IntColumn get forwardFromId => integer().nullable()();
  TextColumn get attachmentsJson => text().nullable()(); // JSON array of file paths
  TextColumn get locationDataJson => text().nullable()(); // JSON string of location data
  TextColumn get contactDataJson => text().nullable()(); // JSON string of contact data
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle migrations here
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
