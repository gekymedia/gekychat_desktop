import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Note: Without build_runner, we'll use manual queries instead of generated code
class Conversations extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get avatarUrl => text().nullable()();
  IntColumn get unread => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  IntColumn get id => integer().nullable()();
  TextColumn get clientId => text()();
  IntColumn get conversationId => integer()();
  IntColumn get senderId => integer().nullable()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get attachmentsJson => text().withDefault(const Constant('[]'))();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get serverCreatedAt => dateTime().nullable()();
  BoolColumn get isOutgoing => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {clientId};
}

class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRunAt => dateTime().withDefault(currentDateAndTime)();
}

// Simplified database class (full implementation would require build_runner)
class AppDb {
  final LazyDatabase _database;
  
  AppDb() : _database = _open();
  
  static LazyDatabase _open() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/gekychat.db');
      return NativeDatabase.createInBackground(file);
    });
  }
  
  // Database connection access (simplified - full implementation requires generated code)
  // For now, return a placeholder - actual implementation would use generated code
  dynamic get connection => throw UnimplementedError('Use raw SQL or generate code with build_runner');
  
  // Tables - manual reference (would be generated)
  GeneratedDatabase get conversations => throw UnimplementedError('Use raw SQL queries');
  GeneratedDatabase get messages => throw UnimplementedError('Use raw SQL queries');
  GeneratedDatabase get outbox => throw UnimplementedError('Use raw SQL queries');
  
  int get schemaVersion => 2;
}

