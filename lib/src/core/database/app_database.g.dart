// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _otherUserIdMeta =
      const VerificationMeta('otherUserId');
  @override
  late final GeneratedColumn<int> otherUserId = GeneratedColumn<int>(
      'other_user_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _otherUserNameMeta =
      const VerificationMeta('otherUserName');
  @override
  late final GeneratedColumn<String> otherUserName = GeneratedColumn<String>(
      'other_user_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherUserPhoneMeta =
      const VerificationMeta('otherUserPhone');
  @override
  late final GeneratedColumn<String> otherUserPhone = GeneratedColumn<String>(
      'other_user_phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherUserAvatarUrlMeta =
      const VerificationMeta('otherUserAvatarUrl');
  @override
  late final GeneratedColumn<String> otherUserAvatarUrl =
      GeneratedColumn<String>('other_user_avatar_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMessageMeta =
      const VerificationMeta('lastMessage');
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
      'last_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unread_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isMutedMeta =
      const VerificationMeta('isMuted');
  @override
  late final GeneratedColumn<bool> isMuted = GeneratedColumn<bool>(
      'is_muted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_muted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _archivedAtMeta =
      const VerificationMeta('archivedAt');
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
      'archived_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastSyncedAtMeta =
      const VerificationMeta('lastSyncedAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
      'last_synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        otherUserId,
        otherUserName,
        otherUserPhone,
        otherUserAvatarUrl,
        lastMessage,
        unreadCount,
        updatedAt,
        isPinned,
        isMuted,
        archivedAt,
        lastSyncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(Insertable<Conversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('other_user_id')) {
      context.handle(
          _otherUserIdMeta,
          otherUserId.isAcceptableOrUnknown(
              data['other_user_id']!, _otherUserIdMeta));
    }
    if (data.containsKey('other_user_name')) {
      context.handle(
          _otherUserNameMeta,
          otherUserName.isAcceptableOrUnknown(
              data['other_user_name']!, _otherUserNameMeta));
    }
    if (data.containsKey('other_user_phone')) {
      context.handle(
          _otherUserPhoneMeta,
          otherUserPhone.isAcceptableOrUnknown(
              data['other_user_phone']!, _otherUserPhoneMeta));
    }
    if (data.containsKey('other_user_avatar_url')) {
      context.handle(
          _otherUserAvatarUrlMeta,
          otherUserAvatarUrl.isAcceptableOrUnknown(
              data['other_user_avatar_url']!, _otherUserAvatarUrlMeta));
    }
    if (data.containsKey('last_message')) {
      context.handle(
          _lastMessageMeta,
          lastMessage.isAcceptableOrUnknown(
              data['last_message']!, _lastMessageMeta));
    }
    if (data.containsKey('unread_count')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unread_count']!, _unreadCountMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('is_muted')) {
      context.handle(_isMutedMeta,
          isMuted.isAcceptableOrUnknown(data['is_muted']!, _isMutedMeta));
    }
    if (data.containsKey('archived_at')) {
      context.handle(
          _archivedAtMeta,
          archivedAt.isAcceptableOrUnknown(
              data['archived_at']!, _archivedAtMeta));
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
          _lastSyncedAtMeta,
          lastSyncedAt.isAcceptableOrUnknown(
              data['last_synced_at']!, _lastSyncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      otherUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}other_user_id']),
      otherUserName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}other_user_name']),
      otherUserPhone: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}other_user_phone']),
      otherUserAvatarUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}other_user_avatar_url']),
      lastMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_message']),
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unread_count'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      isMuted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_muted'])!,
      archivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}archived_at']),
      lastSyncedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_synced_at']),
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final int id;
  final int? otherUserId;
  final String? otherUserName;
  final String? otherUserPhone;
  final String? otherUserAvatarUrl;
  final String? lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;
  final bool isPinned;
  final bool isMuted;
  final DateTime? archivedAt;
  final DateTime? lastSyncedAt;
  const Conversation(
      {required this.id,
      this.otherUserId,
      this.otherUserName,
      this.otherUserPhone,
      this.otherUserAvatarUrl,
      this.lastMessage,
      required this.unreadCount,
      this.updatedAt,
      required this.isPinned,
      required this.isMuted,
      this.archivedAt,
      this.lastSyncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || otherUserId != null) {
      map['other_user_id'] = Variable<int>(otherUserId);
    }
    if (!nullToAbsent || otherUserName != null) {
      map['other_user_name'] = Variable<String>(otherUserName);
    }
    if (!nullToAbsent || otherUserPhone != null) {
      map['other_user_phone'] = Variable<String>(otherUserPhone);
    }
    if (!nullToAbsent || otherUserAvatarUrl != null) {
      map['other_user_avatar_url'] = Variable<String>(otherUserAvatarUrl);
    }
    if (!nullToAbsent || lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_muted'] = Variable<bool>(isMuted);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      otherUserId: otherUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserId),
      otherUserName: otherUserName == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserName),
      otherUserPhone: otherUserPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserPhone),
      otherUserAvatarUrl: otherUserAvatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUserAvatarUrl),
      lastMessage: lastMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessage),
      unreadCount: Value(unreadCount),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isPinned: Value(isPinned),
      isMuted: Value(isMuted),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<int>(json['id']),
      otherUserId: serializer.fromJson<int?>(json['otherUserId']),
      otherUserName: serializer.fromJson<String?>(json['otherUserName']),
      otherUserPhone: serializer.fromJson<String?>(json['otherUserPhone']),
      otherUserAvatarUrl:
          serializer.fromJson<String?>(json['otherUserAvatarUrl']),
      lastMessage: serializer.fromJson<String?>(json['lastMessage']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isMuted: serializer.fromJson<bool>(json['isMuted']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'otherUserId': serializer.toJson<int?>(otherUserId),
      'otherUserName': serializer.toJson<String?>(otherUserName),
      'otherUserPhone': serializer.toJson<String?>(otherUserPhone),
      'otherUserAvatarUrl': serializer.toJson<String?>(otherUserAvatarUrl),
      'lastMessage': serializer.toJson<String?>(lastMessage),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isMuted': serializer.toJson<bool>(isMuted),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  Conversation copyWith(
          {int? id,
          Value<int?> otherUserId = const Value.absent(),
          Value<String?> otherUserName = const Value.absent(),
          Value<String?> otherUserPhone = const Value.absent(),
          Value<String?> otherUserAvatarUrl = const Value.absent(),
          Value<String?> lastMessage = const Value.absent(),
          int? unreadCount,
          Value<DateTime?> updatedAt = const Value.absent(),
          bool? isPinned,
          bool? isMuted,
          Value<DateTime?> archivedAt = const Value.absent(),
          Value<DateTime?> lastSyncedAt = const Value.absent()}) =>
      Conversation(
        id: id ?? this.id,
        otherUserId: otherUserId.present ? otherUserId.value : this.otherUserId,
        otherUserName:
            otherUserName.present ? otherUserName.value : this.otherUserName,
        otherUserPhone:
            otherUserPhone.present ? otherUserPhone.value : this.otherUserPhone,
        otherUserAvatarUrl: otherUserAvatarUrl.present
            ? otherUserAvatarUrl.value
            : this.otherUserAvatarUrl,
        lastMessage: lastMessage.present ? lastMessage.value : this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        isPinned: isPinned ?? this.isPinned,
        isMuted: isMuted ?? this.isMuted,
        archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
        lastSyncedAt:
            lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
      );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      otherUserId:
          data.otherUserId.present ? data.otherUserId.value : this.otherUserId,
      otherUserName: data.otherUserName.present
          ? data.otherUserName.value
          : this.otherUserName,
      otherUserPhone: data.otherUserPhone.present
          ? data.otherUserPhone.value
          : this.otherUserPhone,
      otherUserAvatarUrl: data.otherUserAvatarUrl.present
          ? data.otherUserAvatarUrl.value
          : this.otherUserAvatarUrl,
      lastMessage:
          data.lastMessage.present ? data.lastMessage.value : this.lastMessage,
      unreadCount:
          data.unreadCount.present ? data.unreadCount.value : this.unreadCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isMuted: data.isMuted.present ? data.isMuted.value : this.isMuted,
      archivedAt:
          data.archivedAt.present ? data.archivedAt.value : this.archivedAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('otherUserId: $otherUserId, ')
          ..write('otherUserName: $otherUserName, ')
          ..write('otherUserPhone: $otherUserPhone, ')
          ..write('otherUserAvatarUrl: $otherUserAvatarUrl, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isMuted: $isMuted, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      otherUserId,
      otherUserName,
      otherUserPhone,
      otherUserAvatarUrl,
      lastMessage,
      unreadCount,
      updatedAt,
      isPinned,
      isMuted,
      archivedAt,
      lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.otherUserId == this.otherUserId &&
          other.otherUserName == this.otherUserName &&
          other.otherUserPhone == this.otherUserPhone &&
          other.otherUserAvatarUrl == this.otherUserAvatarUrl &&
          other.lastMessage == this.lastMessage &&
          other.unreadCount == this.unreadCount &&
          other.updatedAt == this.updatedAt &&
          other.isPinned == this.isPinned &&
          other.isMuted == this.isMuted &&
          other.archivedAt == this.archivedAt &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<int> id;
  final Value<int?> otherUserId;
  final Value<String?> otherUserName;
  final Value<String?> otherUserPhone;
  final Value<String?> otherUserAvatarUrl;
  final Value<String?> lastMessage;
  final Value<int> unreadCount;
  final Value<DateTime?> updatedAt;
  final Value<bool> isPinned;
  final Value<bool> isMuted;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> lastSyncedAt;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.otherUserId = const Value.absent(),
    this.otherUserName = const Value.absent(),
    this.otherUserPhone = const Value.absent(),
    this.otherUserAvatarUrl = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  });
  ConversationsCompanion.insert({
    this.id = const Value.absent(),
    this.otherUserId = const Value.absent(),
    this.otherUserName = const Value.absent(),
    this.otherUserPhone = const Value.absent(),
    this.otherUserAvatarUrl = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  });
  static Insertable<Conversation> custom({
    Expression<int>? id,
    Expression<int>? otherUserId,
    Expression<String>? otherUserName,
    Expression<String>? otherUserPhone,
    Expression<String>? otherUserAvatarUrl,
    Expression<String>? lastMessage,
    Expression<int>? unreadCount,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isPinned,
    Expression<bool>? isMuted,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? lastSyncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (otherUserId != null) 'other_user_id': otherUserId,
      if (otherUserName != null) 'other_user_name': otherUserName,
      if (otherUserPhone != null) 'other_user_phone': otherUserPhone,
      if (otherUserAvatarUrl != null)
        'other_user_avatar_url': otherUserAvatarUrl,
      if (lastMessage != null) 'last_message': lastMessage,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isMuted != null) 'is_muted': isMuted,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    });
  }

  ConversationsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? otherUserId,
      Value<String?>? otherUserName,
      Value<String?>? otherUserPhone,
      Value<String?>? otherUserAvatarUrl,
      Value<String?>? lastMessage,
      Value<int>? unreadCount,
      Value<DateTime?>? updatedAt,
      Value<bool>? isPinned,
      Value<bool>? isMuted,
      Value<DateTime?>? archivedAt,
      Value<DateTime?>? lastSyncedAt}) {
    return ConversationsCompanion(
      id: id ?? this.id,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserPhone: otherUserPhone ?? this.otherUserPhone,
      otherUserAvatarUrl: otherUserAvatarUrl ?? this.otherUserAvatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      archivedAt: archivedAt ?? this.archivedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (otherUserId.present) {
      map['other_user_id'] = Variable<int>(otherUserId.value);
    }
    if (otherUserName.present) {
      map['other_user_name'] = Variable<String>(otherUserName.value);
    }
    if (otherUserPhone.present) {
      map['other_user_phone'] = Variable<String>(otherUserPhone.value);
    }
    if (otherUserAvatarUrl.present) {
      map['other_user_avatar_url'] = Variable<String>(otherUserAvatarUrl.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isMuted.present) {
      map['is_muted'] = Variable<bool>(isMuted.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('otherUserId: $otherUserId, ')
          ..write('otherUserName: $otherUserName, ')
          ..write('otherUserPhone: $otherUserPhone, ')
          ..write('otherUserAvatarUrl: $otherUserAvatarUrl, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isMuted: $isMuted, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
      'conversation_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
      'group_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<int> senderId = GeneratedColumn<int>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _senderNameMeta =
      const VerificationMeta('senderName');
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
      'sender_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _senderAvatarUrlMeta =
      const VerificationMeta('senderAvatarUrl');
  @override
  late final GeneratedColumn<String> senderAvatarUrl = GeneratedColumn<String>(
      'sender_avatar_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _replyToIdMeta =
      const VerificationMeta('replyToId');
  @override
  late final GeneratedColumn<int> replyToId = GeneratedColumn<int>(
      'reply_to_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _forwardedFromIdMeta =
      const VerificationMeta('forwardedFromId');
  @override
  late final GeneratedColumn<int> forwardedFromId = GeneratedColumn<int>(
      'forwarded_from_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _attachmentsJsonMeta =
      const VerificationMeta('attachmentsJson');
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
      'attachments_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
      'read_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deliveredAtMeta =
      const VerificationMeta('deliveredAt');
  @override
  late final GeneratedColumn<DateTime> deliveredAt = GeneratedColumn<DateTime>(
      'delivered_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _reactionsJsonMeta =
      const VerificationMeta('reactionsJson');
  @override
  late final GeneratedColumn<String> reactionsJson = GeneratedColumn<String>(
      'reactions_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationDataJsonMeta =
      const VerificationMeta('locationDataJson');
  @override
  late final GeneratedColumn<String> locationDataJson = GeneratedColumn<String>(
      'location_data_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactDataJsonMeta =
      const VerificationMeta('contactDataJson');
  @override
  late final GeneratedColumn<String> contactDataJson = GeneratedColumn<String>(
      'contact_data_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _callDataJsonMeta =
      const VerificationMeta('callDataJson');
  @override
  late final GeneratedColumn<String> callDataJson = GeneratedColumn<String>(
      'call_data_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _linkPreviewsJsonMeta =
      const VerificationMeta('linkPreviewsJson');
  @override
  late final GeneratedColumn<String> linkPreviewsJson = GeneratedColumn<String>(
      'link_previews_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedForMeMeta =
      const VerificationMeta('deletedForMe');
  @override
  late final GeneratedColumn<bool> deletedForMe = GeneratedColumn<bool>(
      'deleted_for_me', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("deleted_for_me" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastSyncedAtMeta =
      const VerificationMeta('lastSyncedAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
      'last_synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        groupId,
        senderId,
        senderName,
        senderAvatarUrl,
        body,
        createdAt,
        replyToId,
        forwardedFromId,
        attachmentsJson,
        readAt,
        deliveredAt,
        reactionsJson,
        locationDataJson,
        contactDataJson,
        callDataJson,
        linkPreviewsJson,
        isDeleted,
        deletedForMe,
        lastSyncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('sender_name')) {
      context.handle(
          _senderNameMeta,
          senderName.isAcceptableOrUnknown(
              data['sender_name']!, _senderNameMeta));
    }
    if (data.containsKey('sender_avatar_url')) {
      context.handle(
          _senderAvatarUrlMeta,
          senderAvatarUrl.isAcceptableOrUnknown(
              data['sender_avatar_url']!, _senderAvatarUrlMeta));
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
          _replyToIdMeta,
          replyToId.isAcceptableOrUnknown(
              data['reply_to_id']!, _replyToIdMeta));
    }
    if (data.containsKey('forwarded_from_id')) {
      context.handle(
          _forwardedFromIdMeta,
          forwardedFromId.isAcceptableOrUnknown(
              data['forwarded_from_id']!, _forwardedFromIdMeta));
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
          _attachmentsJsonMeta,
          attachmentsJson.isAcceptableOrUnknown(
              data['attachments_json']!, _attachmentsJsonMeta));
    }
    if (data.containsKey('read_at')) {
      context.handle(_readAtMeta,
          readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta));
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
          _deliveredAtMeta,
          deliveredAt.isAcceptableOrUnknown(
              data['delivered_at']!, _deliveredAtMeta));
    }
    if (data.containsKey('reactions_json')) {
      context.handle(
          _reactionsJsonMeta,
          reactionsJson.isAcceptableOrUnknown(
              data['reactions_json']!, _reactionsJsonMeta));
    }
    if (data.containsKey('location_data_json')) {
      context.handle(
          _locationDataJsonMeta,
          locationDataJson.isAcceptableOrUnknown(
              data['location_data_json']!, _locationDataJsonMeta));
    }
    if (data.containsKey('contact_data_json')) {
      context.handle(
          _contactDataJsonMeta,
          contactDataJson.isAcceptableOrUnknown(
              data['contact_data_json']!, _contactDataJsonMeta));
    }
    if (data.containsKey('call_data_json')) {
      context.handle(
          _callDataJsonMeta,
          callDataJson.isAcceptableOrUnknown(
              data['call_data_json']!, _callDataJsonMeta));
    }
    if (data.containsKey('link_previews_json')) {
      context.handle(
          _linkPreviewsJsonMeta,
          linkPreviewsJson.isAcceptableOrUnknown(
              data['link_previews_json']!, _linkPreviewsJsonMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('deleted_for_me')) {
      context.handle(
          _deletedForMeMeta,
          deletedForMe.isAcceptableOrUnknown(
              data['deleted_for_me']!, _deletedForMeMeta));
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
          _lastSyncedAtMeta,
          lastSyncedAt.isAcceptableOrUnknown(
              data['last_synced_at']!, _lastSyncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}conversation_id']),
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}group_id']),
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sender_id'])!,
      senderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_name']),
      senderAvatarUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}sender_avatar_url']),
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      replyToId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reply_to_id']),
      forwardedFromId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}forwarded_from_id']),
      attachmentsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}attachments_json']),
      readAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}read_at']),
      deliveredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}delivered_at']),
      reactionsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reactions_json']),
      locationDataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_data_json']),
      contactDataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_data_json']),
      callDataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}call_data_json']),
      linkPreviewsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}link_previews_json']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      deletedForMe: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted_for_me'])!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_synced_at']),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final int? conversationId;
  final int? groupId;
  final int senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String body;
  final DateTime createdAt;
  final int? replyToId;
  final int? forwardedFromId;
  final String? attachmentsJson;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  final String? reactionsJson;
  final String? locationDataJson;
  final String? contactDataJson;
  final String? callDataJson;
  final String? linkPreviewsJson;
  final bool isDeleted;
  final bool deletedForMe;
  final DateTime? lastSyncedAt;
  const Message(
      {required this.id,
      this.conversationId,
      this.groupId,
      required this.senderId,
      this.senderName,
      this.senderAvatarUrl,
      required this.body,
      required this.createdAt,
      this.replyToId,
      this.forwardedFromId,
      this.attachmentsJson,
      this.readAt,
      this.deliveredAt,
      this.reactionsJson,
      this.locationDataJson,
      this.contactDataJson,
      this.callDataJson,
      this.linkPreviewsJson,
      required this.isDeleted,
      required this.deletedForMe,
      this.lastSyncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<int>(conversationId);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    map['sender_id'] = Variable<int>(senderId);
    if (!nullToAbsent || senderName != null) {
      map['sender_name'] = Variable<String>(senderName);
    }
    if (!nullToAbsent || senderAvatarUrl != null) {
      map['sender_avatar_url'] = Variable<String>(senderAvatarUrl);
    }
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<int>(replyToId);
    }
    if (!nullToAbsent || forwardedFromId != null) {
      map['forwarded_from_id'] = Variable<int>(forwardedFromId);
    }
    if (!nullToAbsent || attachmentsJson != null) {
      map['attachments_json'] = Variable<String>(attachmentsJson);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    if (!nullToAbsent || reactionsJson != null) {
      map['reactions_json'] = Variable<String>(reactionsJson);
    }
    if (!nullToAbsent || locationDataJson != null) {
      map['location_data_json'] = Variable<String>(locationDataJson);
    }
    if (!nullToAbsent || contactDataJson != null) {
      map['contact_data_json'] = Variable<String>(contactDataJson);
    }
    if (!nullToAbsent || callDataJson != null) {
      map['call_data_json'] = Variable<String>(callDataJson);
    }
    if (!nullToAbsent || linkPreviewsJson != null) {
      map['link_previews_json'] = Variable<String>(linkPreviewsJson);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['deleted_for_me'] = Variable<bool>(deletedForMe);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      senderId: Value(senderId),
      senderName: senderName == null && nullToAbsent
          ? const Value.absent()
          : Value(senderName),
      senderAvatarUrl: senderAvatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(senderAvatarUrl),
      body: Value(body),
      createdAt: Value(createdAt),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      forwardedFromId: forwardedFromId == null && nullToAbsent
          ? const Value.absent()
          : Value(forwardedFromId),
      attachmentsJson: attachmentsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentsJson),
      readAt:
          readAt == null && nullToAbsent ? const Value.absent() : Value(readAt),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      reactionsJson: reactionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reactionsJson),
      locationDataJson: locationDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(locationDataJson),
      contactDataJson: contactDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(contactDataJson),
      callDataJson: callDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(callDataJson),
      linkPreviewsJson: linkPreviewsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(linkPreviewsJson),
      isDeleted: Value(isDeleted),
      deletedForMe: Value(deletedForMe),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<int?>(json['conversationId']),
      groupId: serializer.fromJson<int?>(json['groupId']),
      senderId: serializer.fromJson<int>(json['senderId']),
      senderName: serializer.fromJson<String?>(json['senderName']),
      senderAvatarUrl: serializer.fromJson<String?>(json['senderAvatarUrl']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      replyToId: serializer.fromJson<int?>(json['replyToId']),
      forwardedFromId: serializer.fromJson<int?>(json['forwardedFromId']),
      attachmentsJson: serializer.fromJson<String?>(json['attachmentsJson']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
      reactionsJson: serializer.fromJson<String?>(json['reactionsJson']),
      locationDataJson: serializer.fromJson<String?>(json['locationDataJson']),
      contactDataJson: serializer.fromJson<String?>(json['contactDataJson']),
      callDataJson: serializer.fromJson<String?>(json['callDataJson']),
      linkPreviewsJson: serializer.fromJson<String?>(json['linkPreviewsJson']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedForMe: serializer.fromJson<bool>(json['deletedForMe']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<int?>(conversationId),
      'groupId': serializer.toJson<int?>(groupId),
      'senderId': serializer.toJson<int>(senderId),
      'senderName': serializer.toJson<String?>(senderName),
      'senderAvatarUrl': serializer.toJson<String?>(senderAvatarUrl),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'replyToId': serializer.toJson<int?>(replyToId),
      'forwardedFromId': serializer.toJson<int?>(forwardedFromId),
      'attachmentsJson': serializer.toJson<String?>(attachmentsJson),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
      'reactionsJson': serializer.toJson<String?>(reactionsJson),
      'locationDataJson': serializer.toJson<String?>(locationDataJson),
      'contactDataJson': serializer.toJson<String?>(contactDataJson),
      'callDataJson': serializer.toJson<String?>(callDataJson),
      'linkPreviewsJson': serializer.toJson<String?>(linkPreviewsJson),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedForMe': serializer.toJson<bool>(deletedForMe),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  Message copyWith(
          {int? id,
          Value<int?> conversationId = const Value.absent(),
          Value<int?> groupId = const Value.absent(),
          int? senderId,
          Value<String?> senderName = const Value.absent(),
          Value<String?> senderAvatarUrl = const Value.absent(),
          String? body,
          DateTime? createdAt,
          Value<int?> replyToId = const Value.absent(),
          Value<int?> forwardedFromId = const Value.absent(),
          Value<String?> attachmentsJson = const Value.absent(),
          Value<DateTime?> readAt = const Value.absent(),
          Value<DateTime?> deliveredAt = const Value.absent(),
          Value<String?> reactionsJson = const Value.absent(),
          Value<String?> locationDataJson = const Value.absent(),
          Value<String?> contactDataJson = const Value.absent(),
          Value<String?> callDataJson = const Value.absent(),
          Value<String?> linkPreviewsJson = const Value.absent(),
          bool? isDeleted,
          bool? deletedForMe,
          Value<DateTime?> lastSyncedAt = const Value.absent()}) =>
      Message(
        id: id ?? this.id,
        conversationId:
            conversationId.present ? conversationId.value : this.conversationId,
        groupId: groupId.present ? groupId.value : this.groupId,
        senderId: senderId ?? this.senderId,
        senderName: senderName.present ? senderName.value : this.senderName,
        senderAvatarUrl: senderAvatarUrl.present
            ? senderAvatarUrl.value
            : this.senderAvatarUrl,
        body: body ?? this.body,
        createdAt: createdAt ?? this.createdAt,
        replyToId: replyToId.present ? replyToId.value : this.replyToId,
        forwardedFromId: forwardedFromId.present
            ? forwardedFromId.value
            : this.forwardedFromId,
        attachmentsJson: attachmentsJson.present
            ? attachmentsJson.value
            : this.attachmentsJson,
        readAt: readAt.present ? readAt.value : this.readAt,
        deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
        reactionsJson:
            reactionsJson.present ? reactionsJson.value : this.reactionsJson,
        locationDataJson: locationDataJson.present
            ? locationDataJson.value
            : this.locationDataJson,
        contactDataJson: contactDataJson.present
            ? contactDataJson.value
            : this.contactDataJson,
        callDataJson:
            callDataJson.present ? callDataJson.value : this.callDataJson,
        linkPreviewsJson: linkPreviewsJson.present
            ? linkPreviewsJson.value
            : this.linkPreviewsJson,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedForMe: deletedForMe ?? this.deletedForMe,
        lastSyncedAt:
            lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
      );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      senderName:
          data.senderName.present ? data.senderName.value : this.senderName,
      senderAvatarUrl: data.senderAvatarUrl.present
          ? data.senderAvatarUrl.value
          : this.senderAvatarUrl,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      forwardedFromId: data.forwardedFromId.present
          ? data.forwardedFromId.value
          : this.forwardedFromId,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      deliveredAt:
          data.deliveredAt.present ? data.deliveredAt.value : this.deliveredAt,
      reactionsJson: data.reactionsJson.present
          ? data.reactionsJson.value
          : this.reactionsJson,
      locationDataJson: data.locationDataJson.present
          ? data.locationDataJson.value
          : this.locationDataJson,
      contactDataJson: data.contactDataJson.present
          ? data.contactDataJson.value
          : this.contactDataJson,
      callDataJson: data.callDataJson.present
          ? data.callDataJson.value
          : this.callDataJson,
      linkPreviewsJson: data.linkPreviewsJson.present
          ? data.linkPreviewsJson.value
          : this.linkPreviewsJson,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedForMe: data.deletedForMe.present
          ? data.deletedForMe.value
          : this.deletedForMe,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('senderAvatarUrl: $senderAvatarUrl, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('replyToId: $replyToId, ')
          ..write('forwardedFromId: $forwardedFromId, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('readAt: $readAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('locationDataJson: $locationDataJson, ')
          ..write('contactDataJson: $contactDataJson, ')
          ..write('callDataJson: $callDataJson, ')
          ..write('linkPreviewsJson: $linkPreviewsJson, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedForMe: $deletedForMe, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        conversationId,
        groupId,
        senderId,
        senderName,
        senderAvatarUrl,
        body,
        createdAt,
        replyToId,
        forwardedFromId,
        attachmentsJson,
        readAt,
        deliveredAt,
        reactionsJson,
        locationDataJson,
        contactDataJson,
        callDataJson,
        linkPreviewsJson,
        isDeleted,
        deletedForMe,
        lastSyncedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.groupId == this.groupId &&
          other.senderId == this.senderId &&
          other.senderName == this.senderName &&
          other.senderAvatarUrl == this.senderAvatarUrl &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.replyToId == this.replyToId &&
          other.forwardedFromId == this.forwardedFromId &&
          other.attachmentsJson == this.attachmentsJson &&
          other.readAt == this.readAt &&
          other.deliveredAt == this.deliveredAt &&
          other.reactionsJson == this.reactionsJson &&
          other.locationDataJson == this.locationDataJson &&
          other.contactDataJson == this.contactDataJson &&
          other.callDataJson == this.callDataJson &&
          other.linkPreviewsJson == this.linkPreviewsJson &&
          other.isDeleted == this.isDeleted &&
          other.deletedForMe == this.deletedForMe &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<int?> conversationId;
  final Value<int?> groupId;
  final Value<int> senderId;
  final Value<String?> senderName;
  final Value<String?> senderAvatarUrl;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<int?> replyToId;
  final Value<int?> forwardedFromId;
  final Value<String?> attachmentsJson;
  final Value<DateTime?> readAt;
  final Value<DateTime?> deliveredAt;
  final Value<String?> reactionsJson;
  final Value<String?> locationDataJson;
  final Value<String?> contactDataJson;
  final Value<String?> callDataJson;
  final Value<String?> linkPreviewsJson;
  final Value<bool> isDeleted;
  final Value<bool> deletedForMe;
  final Value<DateTime?> lastSyncedAt;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.senderAvatarUrl = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.forwardedFromId = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.readAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.locationDataJson = const Value.absent(),
    this.contactDataJson = const Value.absent(),
    this.callDataJson = const Value.absent(),
    this.linkPreviewsJson = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedForMe = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.groupId = const Value.absent(),
    required int senderId,
    this.senderName = const Value.absent(),
    this.senderAvatarUrl = const Value.absent(),
    required String body,
    required DateTime createdAt,
    this.replyToId = const Value.absent(),
    this.forwardedFromId = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.readAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.locationDataJson = const Value.absent(),
    this.contactDataJson = const Value.absent(),
    this.callDataJson = const Value.absent(),
    this.linkPreviewsJson = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedForMe = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  })  : senderId = Value(senderId),
        body = Value(body),
        createdAt = Value(createdAt);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<int>? conversationId,
    Expression<int>? groupId,
    Expression<int>? senderId,
    Expression<String>? senderName,
    Expression<String>? senderAvatarUrl,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<int>? replyToId,
    Expression<int>? forwardedFromId,
    Expression<String>? attachmentsJson,
    Expression<DateTime>? readAt,
    Expression<DateTime>? deliveredAt,
    Expression<String>? reactionsJson,
    Expression<String>? locationDataJson,
    Expression<String>? contactDataJson,
    Expression<String>? callDataJson,
    Expression<String>? linkPreviewsJson,
    Expression<bool>? isDeleted,
    Expression<bool>? deletedForMe,
    Expression<DateTime>? lastSyncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (groupId != null) 'group_id': groupId,
      if (senderId != null) 'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (forwardedFromId != null) 'forwarded_from_id': forwardedFromId,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (readAt != null) 'read_at': readAt,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (reactionsJson != null) 'reactions_json': reactionsJson,
      if (locationDataJson != null) 'location_data_json': locationDataJson,
      if (contactDataJson != null) 'contact_data_json': contactDataJson,
      if (callDataJson != null) 'call_data_json': callDataJson,
      if (linkPreviewsJson != null) 'link_previews_json': linkPreviewsJson,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedForMe != null) 'deleted_for_me': deletedForMe,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    });
  }

  MessagesCompanion copyWith(
      {Value<int>? id,
      Value<int?>? conversationId,
      Value<int?>? groupId,
      Value<int>? senderId,
      Value<String?>? senderName,
      Value<String?>? senderAvatarUrl,
      Value<String>? body,
      Value<DateTime>? createdAt,
      Value<int?>? replyToId,
      Value<int?>? forwardedFromId,
      Value<String?>? attachmentsJson,
      Value<DateTime?>? readAt,
      Value<DateTime?>? deliveredAt,
      Value<String?>? reactionsJson,
      Value<String?>? locationDataJson,
      Value<String?>? contactDataJson,
      Value<String?>? callDataJson,
      Value<String?>? linkPreviewsJson,
      Value<bool>? isDeleted,
      Value<bool>? deletedForMe,
      Value<DateTime?>? lastSyncedAt}) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      replyToId: replyToId ?? this.replyToId,
      forwardedFromId: forwardedFromId ?? this.forwardedFromId,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      reactionsJson: reactionsJson ?? this.reactionsJson,
      locationDataJson: locationDataJson ?? this.locationDataJson,
      contactDataJson: contactDataJson ?? this.contactDataJson,
      callDataJson: callDataJson ?? this.callDataJson,
      linkPreviewsJson: linkPreviewsJson ?? this.linkPreviewsJson,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedForMe: deletedForMe ?? this.deletedForMe,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<int>(senderId.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (senderAvatarUrl.present) {
      map['sender_avatar_url'] = Variable<String>(senderAvatarUrl.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<int>(replyToId.value);
    }
    if (forwardedFromId.present) {
      map['forwarded_from_id'] = Variable<int>(forwardedFromId.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    if (reactionsJson.present) {
      map['reactions_json'] = Variable<String>(reactionsJson.value);
    }
    if (locationDataJson.present) {
      map['location_data_json'] = Variable<String>(locationDataJson.value);
    }
    if (contactDataJson.present) {
      map['contact_data_json'] = Variable<String>(contactDataJson.value);
    }
    if (callDataJson.present) {
      map['call_data_json'] = Variable<String>(callDataJson.value);
    }
    if (linkPreviewsJson.present) {
      map['link_previews_json'] = Variable<String>(linkPreviewsJson.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedForMe.present) {
      map['deleted_for_me'] = Variable<bool>(deletedForMe.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('senderAvatarUrl: $senderAvatarUrl, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('replyToId: $replyToId, ')
          ..write('forwardedFromId: $forwardedFromId, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('readAt: $readAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('locationDataJson: $locationDataJson, ')
          ..write('contactDataJson: $contactDataJson, ')
          ..write('callDataJson: $callDataJson, ')
          ..write('linkPreviewsJson: $linkPreviewsJson, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedForMe: $deletedForMe, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }
}

class $GroupsTable extends Groups with TableInfo<$GroupsTable, Group> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unread_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _memberCountMeta =
      const VerificationMeta('memberCount');
  @override
  late final GeneratedColumn<int> memberCount = GeneratedColumn<int>(
      'member_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isVerifiedMeta =
      const VerificationMeta('isVerified');
  @override
  late final GeneratedColumn<bool> isVerified = GeneratedColumn<bool>(
      'is_verified', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_verified" IN (0, 1))'));
  static const VerificationMeta _lastMessageMeta =
      const VerificationMeta('lastMessage');
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
      'last_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isMutedMeta =
      const VerificationMeta('isMuted');
  @override
  late final GeneratedColumn<bool> isMuted = GeneratedColumn<bool>(
      'is_muted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_muted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastSyncedAtMeta =
      const VerificationMeta('lastSyncedAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
      'last_synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        avatarUrl,
        unreadCount,
        memberCount,
        updatedAt,
        type,
        isVerified,
        lastMessage,
        isPinned,
        isMuted,
        lastSyncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(Insertable<Group> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
    }
    if (data.containsKey('unread_count')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unread_count']!, _unreadCountMeta));
    }
    if (data.containsKey('member_count')) {
      context.handle(
          _memberCountMeta,
          memberCount.isAcceptableOrUnknown(
              data['member_count']!, _memberCountMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('is_verified')) {
      context.handle(
          _isVerifiedMeta,
          isVerified.isAcceptableOrUnknown(
              data['is_verified']!, _isVerifiedMeta));
    }
    if (data.containsKey('last_message')) {
      context.handle(
          _lastMessageMeta,
          lastMessage.isAcceptableOrUnknown(
              data['last_message']!, _lastMessageMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('is_muted')) {
      context.handle(_isMutedMeta,
          isMuted.isAcceptableOrUnknown(data['is_muted']!, _isMutedMeta));
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
          _lastSyncedAtMeta,
          lastSyncedAt.isAcceptableOrUnknown(
              data['last_synced_at']!, _lastSyncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Group map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Group(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url']),
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unread_count'])!,
      memberCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}member_count']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type']),
      isVerified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_verified']),
      lastMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_message']),
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      isMuted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_muted'])!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_synced_at']),
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class Group extends DataClass implements Insertable<Group> {
  final int id;
  final String name;
  final String? avatarUrl;
  final int unreadCount;
  final int? memberCount;
  final DateTime? updatedAt;
  final String? type;
  final bool? isVerified;
  final String? lastMessage;
  final bool isPinned;
  final bool isMuted;
  final DateTime? lastSyncedAt;
  const Group(
      {required this.id,
      required this.name,
      this.avatarUrl,
      required this.unreadCount,
      this.memberCount,
      this.updatedAt,
      this.type,
      this.isVerified,
      this.lastMessage,
      required this.isPinned,
      required this.isMuted,
      this.lastSyncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    if (!nullToAbsent || memberCount != null) {
      map['member_count'] = Variable<int>(memberCount);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || isVerified != null) {
      map['is_verified'] = Variable<bool>(isVerified);
    }
    if (!nullToAbsent || lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_muted'] = Variable<bool>(isMuted);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      name: Value(name),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      unreadCount: Value(unreadCount),
      memberCount: memberCount == null && nullToAbsent
          ? const Value.absent()
          : Value(memberCount),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      isVerified: isVerified == null && nullToAbsent
          ? const Value.absent()
          : Value(isVerified),
      lastMessage: lastMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessage),
      isPinned: Value(isPinned),
      isMuted: Value(isMuted),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory Group.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Group(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      memberCount: serializer.fromJson<int?>(json['memberCount']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      type: serializer.fromJson<String?>(json['type']),
      isVerified: serializer.fromJson<bool?>(json['isVerified']),
      lastMessage: serializer.fromJson<String?>(json['lastMessage']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isMuted: serializer.fromJson<bool>(json['isMuted']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'memberCount': serializer.toJson<int?>(memberCount),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'type': serializer.toJson<String?>(type),
      'isVerified': serializer.toJson<bool?>(isVerified),
      'lastMessage': serializer.toJson<String?>(lastMessage),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isMuted': serializer.toJson<bool>(isMuted),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  Group copyWith(
          {int? id,
          String? name,
          Value<String?> avatarUrl = const Value.absent(),
          int? unreadCount,
          Value<int?> memberCount = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          Value<String?> type = const Value.absent(),
          Value<bool?> isVerified = const Value.absent(),
          Value<String?> lastMessage = const Value.absent(),
          bool? isPinned,
          bool? isMuted,
          Value<DateTime?> lastSyncedAt = const Value.absent()}) =>
      Group(
        id: id ?? this.id,
        name: name ?? this.name,
        avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
        unreadCount: unreadCount ?? this.unreadCount,
        memberCount: memberCount.present ? memberCount.value : this.memberCount,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        type: type.present ? type.value : this.type,
        isVerified: isVerified.present ? isVerified.value : this.isVerified,
        lastMessage: lastMessage.present ? lastMessage.value : this.lastMessage,
        isPinned: isPinned ?? this.isPinned,
        isMuted: isMuted ?? this.isMuted,
        lastSyncedAt:
            lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
      );
  Group copyWithCompanion(GroupsCompanion data) {
    return Group(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      unreadCount:
          data.unreadCount.present ? data.unreadCount.value : this.unreadCount,
      memberCount:
          data.memberCount.present ? data.memberCount.value : this.memberCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      type: data.type.present ? data.type.value : this.type,
      isVerified:
          data.isVerified.present ? data.isVerified.value : this.isVerified,
      lastMessage:
          data.lastMessage.present ? data.lastMessage.value : this.lastMessage,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isMuted: data.isMuted.present ? data.isMuted.value : this.isMuted,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Group(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('memberCount: $memberCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('type: $type, ')
          ..write('isVerified: $isVerified, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('isPinned: $isPinned, ')
          ..write('isMuted: $isMuted, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      avatarUrl,
      unreadCount,
      memberCount,
      updatedAt,
      type,
      isVerified,
      lastMessage,
      isPinned,
      isMuted,
      lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Group &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatarUrl == this.avatarUrl &&
          other.unreadCount == this.unreadCount &&
          other.memberCount == this.memberCount &&
          other.updatedAt == this.updatedAt &&
          other.type == this.type &&
          other.isVerified == this.isVerified &&
          other.lastMessage == this.lastMessage &&
          other.isPinned == this.isPinned &&
          other.isMuted == this.isMuted &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class GroupsCompanion extends UpdateCompanion<Group> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> avatarUrl;
  final Value<int> unreadCount;
  final Value<int?> memberCount;
  final Value<DateTime?> updatedAt;
  final Value<String?> type;
  final Value<bool?> isVerified;
  final Value<String?> lastMessage;
  final Value<bool> isPinned;
  final Value<bool> isMuted;
  final Value<DateTime?> lastSyncedAt;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.memberCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.type = const Value.absent(),
    this.isVerified = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  });
  GroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.avatarUrl = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.memberCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.type = const Value.absent(),
    this.isVerified = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Group> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? avatarUrl,
    Expression<int>? unreadCount,
    Expression<int>? memberCount,
    Expression<DateTime>? updatedAt,
    Expression<String>? type,
    Expression<bool>? isVerified,
    Expression<String>? lastMessage,
    Expression<bool>? isPinned,
    Expression<bool>? isMuted,
    Expression<DateTime>? lastSyncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (memberCount != null) 'member_count': memberCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (type != null) 'type': type,
      if (isVerified != null) 'is_verified': isVerified,
      if (lastMessage != null) 'last_message': lastMessage,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isMuted != null) 'is_muted': isMuted,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    });
  }

  GroupsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? avatarUrl,
      Value<int>? unreadCount,
      Value<int?>? memberCount,
      Value<DateTime?>? updatedAt,
      Value<String?>? type,
      Value<bool?>? isVerified,
      Value<String?>? lastMessage,
      Value<bool>? isPinned,
      Value<bool>? isMuted,
      Value<DateTime?>? lastSyncedAt}) {
    return GroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      unreadCount: unreadCount ?? this.unreadCount,
      memberCount: memberCount ?? this.memberCount,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      isVerified: isVerified ?? this.isVerified,
      lastMessage: lastMessage ?? this.lastMessage,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (memberCount.present) {
      map['member_count'] = Variable<int>(memberCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (isVerified.present) {
      map['is_verified'] = Variable<bool>(isVerified.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isMuted.present) {
      map['is_muted'] = Variable<bool>(isMuted.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('memberCount: $memberCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('type: $type, ')
          ..write('isVerified: $isVerified, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('isPinned: $isPinned, ')
          ..write('isMuted: $isMuted, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }
}

class $OfflineMessagesTable extends OfflineMessages
    with TableInfo<$OfflineMessagesTable, OfflineMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
      'conversation_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
      'group_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _replyToIdMeta =
      const VerificationMeta('replyToId');
  @override
  late final GeneratedColumn<int> replyToId = GeneratedColumn<int>(
      'reply_to_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _forwardFromIdMeta =
      const VerificationMeta('forwardFromId');
  @override
  late final GeneratedColumn<int> forwardFromId = GeneratedColumn<int>(
      'forward_from_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _attachmentsJsonMeta =
      const VerificationMeta('attachmentsJson');
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
      'attachments_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationDataJsonMeta =
      const VerificationMeta('locationDataJson');
  @override
  late final GeneratedColumn<String> locationDataJson = GeneratedColumn<String>(
      'location_data_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactDataJsonMeta =
      const VerificationMeta('contactDataJson');
  @override
  late final GeneratedColumn<String> contactDataJson = GeneratedColumn<String>(
      'contact_data_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isSentMeta = const VerificationMeta('isSent');
  @override
  late final GeneratedColumn<bool> isSent = GeneratedColumn<bool>(
      'is_sent', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_sent" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _serverMessageIdMeta =
      const VerificationMeta('serverMessageId');
  @override
  late final GeneratedColumn<int> serverMessageId = GeneratedColumn<int>(
      'server_message_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        groupId,
        body,
        replyToId,
        forwardFromId,
        attachmentsJson,
        locationDataJson,
        contactDataJson,
        createdAt,
        isSent,
        serverMessageId,
        errorMessage,
        retryCount
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_messages';
  @override
  VerificationContext validateIntegrity(Insertable<OfflineMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
          _replyToIdMeta,
          replyToId.isAcceptableOrUnknown(
              data['reply_to_id']!, _replyToIdMeta));
    }
    if (data.containsKey('forward_from_id')) {
      context.handle(
          _forwardFromIdMeta,
          forwardFromId.isAcceptableOrUnknown(
              data['forward_from_id']!, _forwardFromIdMeta));
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
          _attachmentsJsonMeta,
          attachmentsJson.isAcceptableOrUnknown(
              data['attachments_json']!, _attachmentsJsonMeta));
    }
    if (data.containsKey('location_data_json')) {
      context.handle(
          _locationDataJsonMeta,
          locationDataJson.isAcceptableOrUnknown(
              data['location_data_json']!, _locationDataJsonMeta));
    }
    if (data.containsKey('contact_data_json')) {
      context.handle(
          _contactDataJsonMeta,
          contactDataJson.isAcceptableOrUnknown(
              data['contact_data_json']!, _contactDataJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('is_sent')) {
      context.handle(_isSentMeta,
          isSent.isAcceptableOrUnknown(data['is_sent']!, _isSentMeta));
    }
    if (data.containsKey('server_message_id')) {
      context.handle(
          _serverMessageIdMeta,
          serverMessageId.isAcceptableOrUnknown(
              data['server_message_id']!, _serverMessageIdMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}conversation_id']),
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}group_id']),
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      replyToId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reply_to_id']),
      forwardFromId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}forward_from_id']),
      attachmentsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}attachments_json']),
      locationDataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}location_data_json']),
      contactDataJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_data_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isSent: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_sent'])!,
      serverMessageId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_message_id']),
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
    );
  }

  @override
  $OfflineMessagesTable createAlias(String alias) {
    return $OfflineMessagesTable(attachedDatabase, alias);
  }
}

class OfflineMessage extends DataClass implements Insertable<OfflineMessage> {
  final int id;
  final int? conversationId;
  final int? groupId;
  final String body;
  final int? replyToId;
  final int? forwardFromId;
  final String? attachmentsJson;
  final String? locationDataJson;
  final String? contactDataJson;
  final DateTime createdAt;
  final bool isSent;
  final int? serverMessageId;
  final String? errorMessage;
  final int retryCount;
  const OfflineMessage(
      {required this.id,
      this.conversationId,
      this.groupId,
      required this.body,
      this.replyToId,
      this.forwardFromId,
      this.attachmentsJson,
      this.locationDataJson,
      this.contactDataJson,
      required this.createdAt,
      required this.isSent,
      this.serverMessageId,
      this.errorMessage,
      required this.retryCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<int>(conversationId);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<int>(replyToId);
    }
    if (!nullToAbsent || forwardFromId != null) {
      map['forward_from_id'] = Variable<int>(forwardFromId);
    }
    if (!nullToAbsent || attachmentsJson != null) {
      map['attachments_json'] = Variable<String>(attachmentsJson);
    }
    if (!nullToAbsent || locationDataJson != null) {
      map['location_data_json'] = Variable<String>(locationDataJson);
    }
    if (!nullToAbsent || contactDataJson != null) {
      map['contact_data_json'] = Variable<String>(contactDataJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_sent'] = Variable<bool>(isSent);
    if (!nullToAbsent || serverMessageId != null) {
      map['server_message_id'] = Variable<int>(serverMessageId);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  OfflineMessagesCompanion toCompanion(bool nullToAbsent) {
    return OfflineMessagesCompanion(
      id: Value(id),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      body: Value(body),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      forwardFromId: forwardFromId == null && nullToAbsent
          ? const Value.absent()
          : Value(forwardFromId),
      attachmentsJson: attachmentsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentsJson),
      locationDataJson: locationDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(locationDataJson),
      contactDataJson: contactDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(contactDataJson),
      createdAt: Value(createdAt),
      isSent: Value(isSent),
      serverMessageId: serverMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverMessageId),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      retryCount: Value(retryCount),
    );
  }

  factory OfflineMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineMessage(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<int?>(json['conversationId']),
      groupId: serializer.fromJson<int?>(json['groupId']),
      body: serializer.fromJson<String>(json['body']),
      replyToId: serializer.fromJson<int?>(json['replyToId']),
      forwardFromId: serializer.fromJson<int?>(json['forwardFromId']),
      attachmentsJson: serializer.fromJson<String?>(json['attachmentsJson']),
      locationDataJson: serializer.fromJson<String?>(json['locationDataJson']),
      contactDataJson: serializer.fromJson<String?>(json['contactDataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isSent: serializer.fromJson<bool>(json['isSent']),
      serverMessageId: serializer.fromJson<int?>(json['serverMessageId']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<int?>(conversationId),
      'groupId': serializer.toJson<int?>(groupId),
      'body': serializer.toJson<String>(body),
      'replyToId': serializer.toJson<int?>(replyToId),
      'forwardFromId': serializer.toJson<int?>(forwardFromId),
      'attachmentsJson': serializer.toJson<String?>(attachmentsJson),
      'locationDataJson': serializer.toJson<String?>(locationDataJson),
      'contactDataJson': serializer.toJson<String?>(contactDataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isSent': serializer.toJson<bool>(isSent),
      'serverMessageId': serializer.toJson<int?>(serverMessageId),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  OfflineMessage copyWith(
          {int? id,
          Value<int?> conversationId = const Value.absent(),
          Value<int?> groupId = const Value.absent(),
          String? body,
          Value<int?> replyToId = const Value.absent(),
          Value<int?> forwardFromId = const Value.absent(),
          Value<String?> attachmentsJson = const Value.absent(),
          Value<String?> locationDataJson = const Value.absent(),
          Value<String?> contactDataJson = const Value.absent(),
          DateTime? createdAt,
          bool? isSent,
          Value<int?> serverMessageId = const Value.absent(),
          Value<String?> errorMessage = const Value.absent(),
          int? retryCount}) =>
      OfflineMessage(
        id: id ?? this.id,
        conversationId:
            conversationId.present ? conversationId.value : this.conversationId,
        groupId: groupId.present ? groupId.value : this.groupId,
        body: body ?? this.body,
        replyToId: replyToId.present ? replyToId.value : this.replyToId,
        forwardFromId:
            forwardFromId.present ? forwardFromId.value : this.forwardFromId,
        attachmentsJson: attachmentsJson.present
            ? attachmentsJson.value
            : this.attachmentsJson,
        locationDataJson: locationDataJson.present
            ? locationDataJson.value
            : this.locationDataJson,
        contactDataJson: contactDataJson.present
            ? contactDataJson.value
            : this.contactDataJson,
        createdAt: createdAt ?? this.createdAt,
        isSent: isSent ?? this.isSent,
        serverMessageId: serverMessageId.present
            ? serverMessageId.value
            : this.serverMessageId,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        retryCount: retryCount ?? this.retryCount,
      );
  OfflineMessage copyWithCompanion(OfflineMessagesCompanion data) {
    return OfflineMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      body: data.body.present ? data.body.value : this.body,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      forwardFromId: data.forwardFromId.present
          ? data.forwardFromId.value
          : this.forwardFromId,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
      locationDataJson: data.locationDataJson.present
          ? data.locationDataJson.value
          : this.locationDataJson,
      contactDataJson: data.contactDataJson.present
          ? data.contactDataJson.value
          : this.contactDataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isSent: data.isSent.present ? data.isSent.value : this.isSent,
      serverMessageId: data.serverMessageId.present
          ? data.serverMessageId.value
          : this.serverMessageId,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('groupId: $groupId, ')
          ..write('body: $body, ')
          ..write('replyToId: $replyToId, ')
          ..write('forwardFromId: $forwardFromId, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('locationDataJson: $locationDataJson, ')
          ..write('contactDataJson: $contactDataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSent: $isSent, ')
          ..write('serverMessageId: $serverMessageId, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      conversationId,
      groupId,
      body,
      replyToId,
      forwardFromId,
      attachmentsJson,
      locationDataJson,
      contactDataJson,
      createdAt,
      isSent,
      serverMessageId,
      errorMessage,
      retryCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.groupId == this.groupId &&
          other.body == this.body &&
          other.replyToId == this.replyToId &&
          other.forwardFromId == this.forwardFromId &&
          other.attachmentsJson == this.attachmentsJson &&
          other.locationDataJson == this.locationDataJson &&
          other.contactDataJson == this.contactDataJson &&
          other.createdAt == this.createdAt &&
          other.isSent == this.isSent &&
          other.serverMessageId == this.serverMessageId &&
          other.errorMessage == this.errorMessage &&
          other.retryCount == this.retryCount);
}

class OfflineMessagesCompanion extends UpdateCompanion<OfflineMessage> {
  final Value<int> id;
  final Value<int?> conversationId;
  final Value<int?> groupId;
  final Value<String> body;
  final Value<int?> replyToId;
  final Value<int?> forwardFromId;
  final Value<String?> attachmentsJson;
  final Value<String?> locationDataJson;
  final Value<String?> contactDataJson;
  final Value<DateTime> createdAt;
  final Value<bool> isSent;
  final Value<int?> serverMessageId;
  final Value<String?> errorMessage;
  final Value<int> retryCount;
  const OfflineMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.body = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.forwardFromId = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.locationDataJson = const Value.absent(),
    this.contactDataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isSent = const Value.absent(),
    this.serverMessageId = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.retryCount = const Value.absent(),
  });
  OfflineMessagesCompanion.insert({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.groupId = const Value.absent(),
    required String body,
    this.replyToId = const Value.absent(),
    this.forwardFromId = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.locationDataJson = const Value.absent(),
    this.contactDataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isSent = const Value.absent(),
    this.serverMessageId = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.retryCount = const Value.absent(),
  }) : body = Value(body);
  static Insertable<OfflineMessage> custom({
    Expression<int>? id,
    Expression<int>? conversationId,
    Expression<int>? groupId,
    Expression<String>? body,
    Expression<int>? replyToId,
    Expression<int>? forwardFromId,
    Expression<String>? attachmentsJson,
    Expression<String>? locationDataJson,
    Expression<String>? contactDataJson,
    Expression<DateTime>? createdAt,
    Expression<bool>? isSent,
    Expression<int>? serverMessageId,
    Expression<String>? errorMessage,
    Expression<int>? retryCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (groupId != null) 'group_id': groupId,
      if (body != null) 'body': body,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (forwardFromId != null) 'forward_from_id': forwardFromId,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (locationDataJson != null) 'location_data_json': locationDataJson,
      if (contactDataJson != null) 'contact_data_json': contactDataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (isSent != null) 'is_sent': isSent,
      if (serverMessageId != null) 'server_message_id': serverMessageId,
      if (errorMessage != null) 'error_message': errorMessage,
      if (retryCount != null) 'retry_count': retryCount,
    });
  }

  OfflineMessagesCompanion copyWith(
      {Value<int>? id,
      Value<int?>? conversationId,
      Value<int?>? groupId,
      Value<String>? body,
      Value<int?>? replyToId,
      Value<int?>? forwardFromId,
      Value<String?>? attachmentsJson,
      Value<String?>? locationDataJson,
      Value<String?>? contactDataJson,
      Value<DateTime>? createdAt,
      Value<bool>? isSent,
      Value<int?>? serverMessageId,
      Value<String?>? errorMessage,
      Value<int>? retryCount}) {
    return OfflineMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      groupId: groupId ?? this.groupId,
      body: body ?? this.body,
      replyToId: replyToId ?? this.replyToId,
      forwardFromId: forwardFromId ?? this.forwardFromId,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      locationDataJson: locationDataJson ?? this.locationDataJson,
      contactDataJson: contactDataJson ?? this.contactDataJson,
      createdAt: createdAt ?? this.createdAt,
      isSent: isSent ?? this.isSent,
      serverMessageId: serverMessageId ?? this.serverMessageId,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<int>(replyToId.value);
    }
    if (forwardFromId.present) {
      map['forward_from_id'] = Variable<int>(forwardFromId.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (locationDataJson.present) {
      map['location_data_json'] = Variable<String>(locationDataJson.value);
    }
    if (contactDataJson.present) {
      map['contact_data_json'] = Variable<String>(contactDataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isSent.present) {
      map['is_sent'] = Variable<bool>(isSent.value);
    }
    if (serverMessageId.present) {
      map['server_message_id'] = Variable<int>(serverMessageId.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('groupId: $groupId, ')
          ..write('body: $body, ')
          ..write('replyToId: $replyToId, ')
          ..write('forwardFromId: $forwardFromId, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('locationDataJson: $locationDataJson, ')
          ..write('contactDataJson: $contactDataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSent: $isSent, ')
          ..write('serverMessageId: $serverMessageId, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $OfflineMessagesTable offlineMessages =
      $OfflineMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [conversations, messages, groups, offlineMessages];
}

typedef $$ConversationsTableCreateCompanionBuilder = ConversationsCompanion
    Function({
  Value<int> id,
  Value<int?> otherUserId,
  Value<String?> otherUserName,
  Value<String?> otherUserPhone,
  Value<String?> otherUserAvatarUrl,
  Value<String?> lastMessage,
  Value<int> unreadCount,
  Value<DateTime?> updatedAt,
  Value<bool> isPinned,
  Value<bool> isMuted,
  Value<DateTime?> archivedAt,
  Value<DateTime?> lastSyncedAt,
});
typedef $$ConversationsTableUpdateCompanionBuilder = ConversationsCompanion
    Function({
  Value<int> id,
  Value<int?> otherUserId,
  Value<String?> otherUserName,
  Value<String?> otherUserPhone,
  Value<String?> otherUserAvatarUrl,
  Value<String?> lastMessage,
  Value<int> unreadCount,
  Value<DateTime?> updatedAt,
  Value<bool> isPinned,
  Value<bool> isMuted,
  Value<DateTime?> archivedAt,
  Value<DateTime?> lastSyncedAt,
});

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get otherUserId => $composableBuilder(
      column: $table.otherUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherUserName => $composableBuilder(
      column: $table.otherUserName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherUserPhone => $composableBuilder(
      column: $table.otherUserPhone,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherUserAvatarUrl => $composableBuilder(
      column: $table.otherUserAvatarUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMuted => $composableBuilder(
      column: $table.isMuted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
      column: $table.archivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => ColumnFilters(column));
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get otherUserId => $composableBuilder(
      column: $table.otherUserId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherUserName => $composableBuilder(
      column: $table.otherUserName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherUserPhone => $composableBuilder(
      column: $table.otherUserPhone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherUserAvatarUrl => $composableBuilder(
      column: $table.otherUserAvatarUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMuted => $composableBuilder(
      column: $table.isMuted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
      column: $table.archivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get otherUserId => $composableBuilder(
      column: $table.otherUserId, builder: (column) => column);

  GeneratedColumn<String> get otherUserName => $composableBuilder(
      column: $table.otherUserName, builder: (column) => column);

  GeneratedColumn<String> get otherUserPhone => $composableBuilder(
      column: $table.otherUserPhone, builder: (column) => column);

  GeneratedColumn<String> get otherUserAvatarUrl => $composableBuilder(
      column: $table.otherUserAvatarUrl, builder: (column) => column);

  GeneratedColumn<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isMuted =>
      $composableBuilder(column: $table.isMuted, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
      column: $table.archivedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => column);
}

class $$ConversationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()> {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> otherUserId = const Value.absent(),
            Value<String?> otherUserName = const Value.absent(),
            Value<String?> otherUserPhone = const Value.absent(),
            Value<String?> otherUserAvatarUrl = const Value.absent(),
            Value<String?> lastMessage = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<bool> isMuted = const Value.absent(),
            Value<DateTime?> archivedAt = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
          }) =>
              ConversationsCompanion(
            id: id,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserPhone: otherUserPhone,
            otherUserAvatarUrl: otherUserAvatarUrl,
            lastMessage: lastMessage,
            unreadCount: unreadCount,
            updatedAt: updatedAt,
            isPinned: isPinned,
            isMuted: isMuted,
            archivedAt: archivedAt,
            lastSyncedAt: lastSyncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> otherUserId = const Value.absent(),
            Value<String?> otherUserName = const Value.absent(),
            Value<String?> otherUserPhone = const Value.absent(),
            Value<String?> otherUserAvatarUrl = const Value.absent(),
            Value<String?> lastMessage = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<bool> isMuted = const Value.absent(),
            Value<DateTime?> archivedAt = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
          }) =>
              ConversationsCompanion.insert(
            id: id,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserPhone: otherUserPhone,
            otherUserAvatarUrl: otherUserAvatarUrl,
            lastMessage: lastMessage,
            unreadCount: unreadCount,
            updatedAt: updatedAt,
            isPinned: isPinned,
            isMuted: isMuted,
            archivedAt: archivedAt,
            lastSyncedAt: lastSyncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()>;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<int?> conversationId,
  Value<int?> groupId,
  required int senderId,
  Value<String?> senderName,
  Value<String?> senderAvatarUrl,
  required String body,
  required DateTime createdAt,
  Value<int?> replyToId,
  Value<int?> forwardedFromId,
  Value<String?> attachmentsJson,
  Value<DateTime?> readAt,
  Value<DateTime?> deliveredAt,
  Value<String?> reactionsJson,
  Value<String?> locationDataJson,
  Value<String?> contactDataJson,
  Value<String?> callDataJson,
  Value<String?> linkPreviewsJson,
  Value<bool> isDeleted,
  Value<bool> deletedForMe,
  Value<DateTime?> lastSyncedAt,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<int?> conversationId,
  Value<int?> groupId,
  Value<int> senderId,
  Value<String?> senderName,
  Value<String?> senderAvatarUrl,
  Value<String> body,
  Value<DateTime> createdAt,
  Value<int?> replyToId,
  Value<int?> forwardedFromId,
  Value<String?> attachmentsJson,
  Value<DateTime?> readAt,
  Value<DateTime?> deliveredAt,
  Value<String?> reactionsJson,
  Value<String?> locationDataJson,
  Value<String?> contactDataJson,
  Value<String?> callDataJson,
  Value<String?> linkPreviewsJson,
  Value<bool> isDeleted,
  Value<bool> deletedForMe,
  Value<DateTime?> lastSyncedAt,
});

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderAvatarUrl => $composableBuilder(
      column: $table.senderAvatarUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get forwardedFromId => $composableBuilder(
      column: $table.forwardedFromId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
      column: $table.attachmentsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationDataJson => $composableBuilder(
      column: $table.locationDataJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactDataJson => $composableBuilder(
      column: $table.contactDataJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get callDataJson => $composableBuilder(
      column: $table.callDataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get linkPreviewsJson => $composableBuilder(
      column: $table.linkPreviewsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deletedForMe => $composableBuilder(
      column: $table.deletedForMe, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => ColumnFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderAvatarUrl => $composableBuilder(
      column: $table.senderAvatarUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get forwardedFromId => $composableBuilder(
      column: $table.forwardedFromId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
      column: $table.attachmentsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationDataJson => $composableBuilder(
      column: $table.locationDataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactDataJson => $composableBuilder(
      column: $table.contactDataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get callDataJson => $composableBuilder(
      column: $table.callDataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get linkPreviewsJson => $composableBuilder(
      column: $table.linkPreviewsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deletedForMe => $composableBuilder(
      column: $table.deletedForMe,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => column);

  GeneratedColumn<String> get senderAvatarUrl => $composableBuilder(
      column: $table.senderAvatarUrl, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<int> get forwardedFromId => $composableBuilder(
      column: $table.forwardedFromId, builder: (column) => column);

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
      column: $table.attachmentsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => column);

  GeneratedColumn<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson, builder: (column) => column);

  GeneratedColumn<String> get locationDataJson => $composableBuilder(
      column: $table.locationDataJson, builder: (column) => column);

  GeneratedColumn<String> get contactDataJson => $composableBuilder(
      column: $table.contactDataJson, builder: (column) => column);

  GeneratedColumn<String> get callDataJson => $composableBuilder(
      column: $table.callDataJson, builder: (column) => column);

  GeneratedColumn<String> get linkPreviewsJson => $composableBuilder(
      column: $table.linkPreviewsJson, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get deletedForMe => $composableBuilder(
      column: $table.deletedForMe, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> conversationId = const Value.absent(),
            Value<int?> groupId = const Value.absent(),
            Value<int> senderId = const Value.absent(),
            Value<String?> senderName = const Value.absent(),
            Value<String?> senderAvatarUrl = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int?> replyToId = const Value.absent(),
            Value<int?> forwardedFromId = const Value.absent(),
            Value<String?> attachmentsJson = const Value.absent(),
            Value<DateTime?> readAt = const Value.absent(),
            Value<DateTime?> deliveredAt = const Value.absent(),
            Value<String?> reactionsJson = const Value.absent(),
            Value<String?> locationDataJson = const Value.absent(),
            Value<String?> contactDataJson = const Value.absent(),
            Value<String?> callDataJson = const Value.absent(),
            Value<String?> linkPreviewsJson = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<bool> deletedForMe = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            conversationId: conversationId,
            groupId: groupId,
            senderId: senderId,
            senderName: senderName,
            senderAvatarUrl: senderAvatarUrl,
            body: body,
            createdAt: createdAt,
            replyToId: replyToId,
            forwardedFromId: forwardedFromId,
            attachmentsJson: attachmentsJson,
            readAt: readAt,
            deliveredAt: deliveredAt,
            reactionsJson: reactionsJson,
            locationDataJson: locationDataJson,
            contactDataJson: contactDataJson,
            callDataJson: callDataJson,
            linkPreviewsJson: linkPreviewsJson,
            isDeleted: isDeleted,
            deletedForMe: deletedForMe,
            lastSyncedAt: lastSyncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> conversationId = const Value.absent(),
            Value<int?> groupId = const Value.absent(),
            required int senderId,
            Value<String?> senderName = const Value.absent(),
            Value<String?> senderAvatarUrl = const Value.absent(),
            required String body,
            required DateTime createdAt,
            Value<int?> replyToId = const Value.absent(),
            Value<int?> forwardedFromId = const Value.absent(),
            Value<String?> attachmentsJson = const Value.absent(),
            Value<DateTime?> readAt = const Value.absent(),
            Value<DateTime?> deliveredAt = const Value.absent(),
            Value<String?> reactionsJson = const Value.absent(),
            Value<String?> locationDataJson = const Value.absent(),
            Value<String?> contactDataJson = const Value.absent(),
            Value<String?> callDataJson = const Value.absent(),
            Value<String?> linkPreviewsJson = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<bool> deletedForMe = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            groupId: groupId,
            senderId: senderId,
            senderName: senderName,
            senderAvatarUrl: senderAvatarUrl,
            body: body,
            createdAt: createdAt,
            replyToId: replyToId,
            forwardedFromId: forwardedFromId,
            attachmentsJson: attachmentsJson,
            readAt: readAt,
            deliveredAt: deliveredAt,
            reactionsJson: reactionsJson,
            locationDataJson: locationDataJson,
            contactDataJson: contactDataJson,
            callDataJson: callDataJson,
            linkPreviewsJson: linkPreviewsJson,
            isDeleted: isDeleted,
            deletedForMe: deletedForMe,
            lastSyncedAt: lastSyncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()>;
typedef $$GroupsTableCreateCompanionBuilder = GroupsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> avatarUrl,
  Value<int> unreadCount,
  Value<int?> memberCount,
  Value<DateTime?> updatedAt,
  Value<String?> type,
  Value<bool?> isVerified,
  Value<String?> lastMessage,
  Value<bool> isPinned,
  Value<bool> isMuted,
  Value<DateTime?> lastSyncedAt,
});
typedef $$GroupsTableUpdateCompanionBuilder = GroupsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> avatarUrl,
  Value<int> unreadCount,
  Value<int?> memberCount,
  Value<DateTime?> updatedAt,
  Value<String?> type,
  Value<bool?> isVerified,
  Value<String?> lastMessage,
  Value<bool> isPinned,
  Value<bool> isMuted,
  Value<DateTime?> lastSyncedAt,
});

class $$GroupsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get memberCount => $composableBuilder(
      column: $table.memberCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVerified => $composableBuilder(
      column: $table.isVerified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMuted => $composableBuilder(
      column: $table.isMuted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => ColumnFilters(column));
}

class $$GroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get memberCount => $composableBuilder(
      column: $table.memberCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVerified => $composableBuilder(
      column: $table.isVerified, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMuted => $composableBuilder(
      column: $table.isMuted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => column);

  GeneratedColumn<int> get memberCount => $composableBuilder(
      column: $table.memberCount, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get isVerified => $composableBuilder(
      column: $table.isVerified, builder: (column) => column);

  GeneratedColumn<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isMuted =>
      $composableBuilder(column: $table.isMuted, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => column);
}

class $$GroupsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GroupsTable,
    Group,
    $$GroupsTableFilterComposer,
    $$GroupsTableOrderingComposer,
    $$GroupsTableAnnotationComposer,
    $$GroupsTableCreateCompanionBuilder,
    $$GroupsTableUpdateCompanionBuilder,
    (Group, BaseReferences<_$AppDatabase, $GroupsTable, Group>),
    Group,
    PrefetchHooks Function()> {
  $$GroupsTableTableManager(_$AppDatabase db, $GroupsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<int?> memberCount = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<String?> type = const Value.absent(),
            Value<bool?> isVerified = const Value.absent(),
            Value<String?> lastMessage = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<bool> isMuted = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
          }) =>
              GroupsCompanion(
            id: id,
            name: name,
            avatarUrl: avatarUrl,
            unreadCount: unreadCount,
            memberCount: memberCount,
            updatedAt: updatedAt,
            type: type,
            isVerified: isVerified,
            lastMessage: lastMessage,
            isPinned: isPinned,
            isMuted: isMuted,
            lastSyncedAt: lastSyncedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> avatarUrl = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<int?> memberCount = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<String?> type = const Value.absent(),
            Value<bool?> isVerified = const Value.absent(),
            Value<String?> lastMessage = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<bool> isMuted = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
          }) =>
              GroupsCompanion.insert(
            id: id,
            name: name,
            avatarUrl: avatarUrl,
            unreadCount: unreadCount,
            memberCount: memberCount,
            updatedAt: updatedAt,
            type: type,
            isVerified: isVerified,
            lastMessage: lastMessage,
            isPinned: isPinned,
            isMuted: isMuted,
            lastSyncedAt: lastSyncedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GroupsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GroupsTable,
    Group,
    $$GroupsTableFilterComposer,
    $$GroupsTableOrderingComposer,
    $$GroupsTableAnnotationComposer,
    $$GroupsTableCreateCompanionBuilder,
    $$GroupsTableUpdateCompanionBuilder,
    (Group, BaseReferences<_$AppDatabase, $GroupsTable, Group>),
    Group,
    PrefetchHooks Function()>;
typedef $$OfflineMessagesTableCreateCompanionBuilder = OfflineMessagesCompanion
    Function({
  Value<int> id,
  Value<int?> conversationId,
  Value<int?> groupId,
  required String body,
  Value<int?> replyToId,
  Value<int?> forwardFromId,
  Value<String?> attachmentsJson,
  Value<String?> locationDataJson,
  Value<String?> contactDataJson,
  Value<DateTime> createdAt,
  Value<bool> isSent,
  Value<int?> serverMessageId,
  Value<String?> errorMessage,
  Value<int> retryCount,
});
typedef $$OfflineMessagesTableUpdateCompanionBuilder = OfflineMessagesCompanion
    Function({
  Value<int> id,
  Value<int?> conversationId,
  Value<int?> groupId,
  Value<String> body,
  Value<int?> replyToId,
  Value<int?> forwardFromId,
  Value<String?> attachmentsJson,
  Value<String?> locationDataJson,
  Value<String?> contactDataJson,
  Value<DateTime> createdAt,
  Value<bool> isSent,
  Value<int?> serverMessageId,
  Value<String?> errorMessage,
  Value<int> retryCount,
});

class $$OfflineMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineMessagesTable> {
  $$OfflineMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get forwardFromId => $composableBuilder(
      column: $table.forwardFromId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
      column: $table.attachmentsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationDataJson => $composableBuilder(
      column: $table.locationDataJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactDataJson => $composableBuilder(
      column: $table.contactDataJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSent => $composableBuilder(
      column: $table.isSent, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverMessageId => $composableBuilder(
      column: $table.serverMessageId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));
}

class $$OfflineMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineMessagesTable> {
  $$OfflineMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get forwardFromId => $composableBuilder(
      column: $table.forwardFromId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
      column: $table.attachmentsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationDataJson => $composableBuilder(
      column: $table.locationDataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactDataJson => $composableBuilder(
      column: $table.contactDataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSent => $composableBuilder(
      column: $table.isSent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverMessageId => $composableBuilder(
      column: $table.serverMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));
}

class $$OfflineMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineMessagesTable> {
  $$OfflineMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<int> get forwardFromId => $composableBuilder(
      column: $table.forwardFromId, builder: (column) => column);

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
      column: $table.attachmentsJson, builder: (column) => column);

  GeneratedColumn<String> get locationDataJson => $composableBuilder(
      column: $table.locationDataJson, builder: (column) => column);

  GeneratedColumn<String> get contactDataJson => $composableBuilder(
      column: $table.contactDataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isSent =>
      $composableBuilder(column: $table.isSent, builder: (column) => column);

  GeneratedColumn<int> get serverMessageId => $composableBuilder(
      column: $table.serverMessageId, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);
}

class $$OfflineMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OfflineMessagesTable,
    OfflineMessage,
    $$OfflineMessagesTableFilterComposer,
    $$OfflineMessagesTableOrderingComposer,
    $$OfflineMessagesTableAnnotationComposer,
    $$OfflineMessagesTableCreateCompanionBuilder,
    $$OfflineMessagesTableUpdateCompanionBuilder,
    (
      OfflineMessage,
      BaseReferences<_$AppDatabase, $OfflineMessagesTable, OfflineMessage>
    ),
    OfflineMessage,
    PrefetchHooks Function()> {
  $$OfflineMessagesTableTableManager(
      _$AppDatabase db, $OfflineMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> conversationId = const Value.absent(),
            Value<int?> groupId = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<int?> replyToId = const Value.absent(),
            Value<int?> forwardFromId = const Value.absent(),
            Value<String?> attachmentsJson = const Value.absent(),
            Value<String?> locationDataJson = const Value.absent(),
            Value<String?> contactDataJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isSent = const Value.absent(),
            Value<int?> serverMessageId = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
          }) =>
              OfflineMessagesCompanion(
            id: id,
            conversationId: conversationId,
            groupId: groupId,
            body: body,
            replyToId: replyToId,
            forwardFromId: forwardFromId,
            attachmentsJson: attachmentsJson,
            locationDataJson: locationDataJson,
            contactDataJson: contactDataJson,
            createdAt: createdAt,
            isSent: isSent,
            serverMessageId: serverMessageId,
            errorMessage: errorMessage,
            retryCount: retryCount,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> conversationId = const Value.absent(),
            Value<int?> groupId = const Value.absent(),
            required String body,
            Value<int?> replyToId = const Value.absent(),
            Value<int?> forwardFromId = const Value.absent(),
            Value<String?> attachmentsJson = const Value.absent(),
            Value<String?> locationDataJson = const Value.absent(),
            Value<String?> contactDataJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isSent = const Value.absent(),
            Value<int?> serverMessageId = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
          }) =>
              OfflineMessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            groupId: groupId,
            body: body,
            replyToId: replyToId,
            forwardFromId: forwardFromId,
            attachmentsJson: attachmentsJson,
            locationDataJson: locationDataJson,
            contactDataJson: contactDataJson,
            createdAt: createdAt,
            isSent: isSent,
            serverMessageId: serverMessageId,
            errorMessage: errorMessage,
            retryCount: retryCount,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OfflineMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OfflineMessagesTable,
    OfflineMessage,
    $$OfflineMessagesTableFilterComposer,
    $$OfflineMessagesTableOrderingComposer,
    $$OfflineMessagesTableAnnotationComposer,
    $$OfflineMessagesTableCreateCompanionBuilder,
    $$OfflineMessagesTableUpdateCompanionBuilder,
    (
      OfflineMessage,
      BaseReferences<_$AppDatabase, $OfflineMessagesTable, OfflineMessage>
    ),
    OfflineMessage,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$OfflineMessagesTableTableManager get offlineMessages =>
      $$OfflineMessagesTableTableManager(_db, _db.offlineMessages);
}
