import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart' hide Message;
import 'local_storage_service.dart';
import '../../features/chats/chat_providers.dart';
import '../../features/chats/chat_repo.dart';
import '../../core/providers/connectivity_provider.dart';

bool _inferVoiceNote({required String body, List<File>? attachments}) {
  if (body.trim().isNotEmpty) return false;
  if (attachments == null || attachments.length != 1) return false;
  final p = attachments.first.path.toLowerCase();
  return p.endsWith('.m4a') ||
      p.endsWith('.aac') ||
      p.endsWith('.mp3') ||
      p.endsWith('.wav') ||
      p.endsWith('.ogg') ||
      p.endsWith('.flac');
}

class MessageQueueService {
  final AppDatabase _db;
  final ChatRepository _chatRepo;
  final bool Function() _isOnline;
  static const _uuid = Uuid();

  MessageQueueService(this._db, this._chatRepo, this._isOnline);

  // Queue a message for sending when online.
  // Returns the stable clientUuid that will be sent to the server for idempotency.
  Future<String> queueMessage({
    required int? conversationId,
    required int? groupId,
    required String body,
    int? replyToId,
    int? forwardFromId,
    List<File>? attachments,
    Map<String, dynamic>? locationData,
    Map<String, dynamic>? contactData,
    String? clientUuid,
    int? referencedStatusId,
    int? referencedGroupId,
    int? referencedGroupMessageId,
    String? referencedContextJson,
    String? messageType,
    bool viewOnce = false,
    DateTime? scheduledAt,
    int? expiresInHours,
  }) async {
    // Always generate/preserve a stable UUID — this same value is sent to the server.
    final clientId = clientUuid ?? _uuid.v4();

    // Serialize attachments (store file paths for later upload)
    String? attachmentsJson;
    if (attachments != null && attachments.isNotEmpty) {
      attachmentsJson = jsonEncode(attachments.map((f) => f.path).toList());
    }

    final companion = OfflineMessagesCompanion.insert(
      clientUuid: Value(clientId),
      conversationId: Value(conversationId),
      groupId: Value(groupId),
      body: body,
      replyToId: Value(replyToId),
      forwardFromId: Value(forwardFromId),
      attachmentsJson: Value(attachmentsJson),
      locationDataJson: Value(locationData != null ? jsonEncode(locationData) : null),
      contactDataJson: Value(contactData != null ? jsonEncode(contactData) : null),
      messageType: Value(messageType),
      viewOnce: Value(viewOnce),
      scheduledAt: Value(scheduledAt),
      expiresInHours: Value(expiresInHours),
      referencedStatusId: Value(referencedStatusId),
      referencedGroupId: Value(referencedGroupId),
      referencedGroupMessageId: Value(referencedGroupMessageId),
      referencedContextJson: Value(referencedContextJson),
      isSent: const Value(false),
      retryCount: const Value(0),
    );

    await _db.into(_db.offlineMessages).insert(companion);
    return clientId;
  }
  
  // Get all pending messages
  Future<List<OfflineMessage>> getPendingMessages() async {
    return await (_db.select(_db.offlineMessages)
          ..where((tbl) => tbl.isSent.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .get();
  }

  // Mark message as sent
  Future<void> markAsSent(int queueId, int? serverMessageId) async {
    await (_db.update(_db.offlineMessages)
          ..where((tbl) => tbl.id.equals(queueId)))
        .write(OfflineMessagesCompanion(
      isSent: const Value(true),
      serverMessageId: Value(serverMessageId),
    ));
  }

  // Mark message as failed
  Future<void> markAsFailed(int queueId, String errorMessage) async {
    final message = await (_db.select(_db.offlineMessages)
          ..where((tbl) => tbl.id.equals(queueId)))
        .getSingle();
    
    await (_db.update(_db.offlineMessages)
          ..where((tbl) => tbl.id.equals(queueId)))
        .write(OfflineMessagesCompanion(
      errorMessage: Value(errorMessage),
      retryCount: Value(message.retryCount + 1),
    ));
  }

  // Delete sent messages older than 7 days
  Future<void> cleanupOldMessages() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await (_db.delete(_db.offlineMessages)
          ..where((tbl) => tbl.isSent.equals(true) & tbl.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  // Sync pending messages when online
  Future<void> syncPendingMessages() async {
    if (!_isOnline()) {
      return;
    }

    final pending = await getPendingMessages();
    
    for (final queuedMessage in pending) {
      try {
        // Skip if retry count is too high (more than 5 attempts)
        if (queuedMessage.retryCount > 5) {
          await markAsFailed(queuedMessage.id, 'Max retry attempts reached');
          continue;
        }

        // Parse attachments if any
        List<File>? attachments;
        if (queuedMessage.attachmentsJson != null) {
          try {
            final paths = jsonDecode(queuedMessage.attachmentsJson!) as List;
            attachments = paths.map((path) => File(path.toString())).toList();
            // Filter out files that no longer exist
            attachments = attachments.where((f) => f.existsSync()).toList();
            if (attachments.isEmpty) {
              attachments = null;
            }
          } catch (e) {
            // Ignore attachment parsing errors
          }
        }

        // Use the stable UUID stored at queue time for server-side idempotency.
        // If the row predates schema v5 it will be null — fall back to a fresh UUID (no dedup, but safe).
        final clientUuid = queuedMessage.clientUuid ?? _uuid.v4();

        final voiceNote = _inferVoiceNote(
          body: queuedMessage.body,
          attachments: attachments,
        );

        // Send the message with the stable client_uuid
        final sentMessage = queuedMessage.conversationId != null
            ? await _chatRepo.sendMessageToConversation(
                conversationId: queuedMessage.conversationId!,
                body: queuedMessage.body.isEmpty ? null : queuedMessage.body,
                replyTo: queuedMessage.replyToId,
                forwardFrom: queuedMessage.forwardFromId,
                attachments: attachments,
                clientUuid: clientUuid,
                referencedStatusId: queuedMessage.referencedStatusId,
                referencedGroupId: queuedMessage.referencedGroupId,
                referencedGroupMessageId: queuedMessage.referencedGroupMessageId,
                messageType: queuedMessage.messageType,
                viewOnce: queuedMessage.viewOnce,
                voiceNote: voiceNote,
                scheduledAt: queuedMessage.scheduledAt,
                expiresInHours: queuedMessage.expiresInHours,
              )
            : (queuedMessage.groupId != null
                ? await _chatRepo.sendMessageToGroup(
                    groupId: queuedMessage.groupId!,
                    body: queuedMessage.body.isEmpty ? null : queuedMessage.body,
                    replyToId: queuedMessage.replyToId,
                    forwardFrom: queuedMessage.forwardFromId,
                    attachments: attachments,
                    clientUuid: clientUuid,
                    messageType: queuedMessage.messageType,
                    viewOnce: queuedMessage.viewOnce,
                    voiceNote: voiceNote,
                    scheduledAt: queuedMessage.scheduledAt,
                    expiresInHours: queuedMessage.expiresInHours,
                  )
                : null);

        if (sentMessage != null) {
          await markAsSent(queuedMessage.id, sentMessage.id);
        } else {
          await markAsFailed(queuedMessage.id, 'Failed to send message');
        }
      } catch (e) {
        await markAsFailed(queuedMessage.id, e.toString());
      }
    }

    // Cleanup old sent messages
    await cleanupOldMessages();
  }
}

final messageQueueServiceProvider = Provider<MessageQueueService>((ref) {
  final db = ref.read(appDatabaseProvider);
  final chatRepo = ref.read(chatRepositoryProvider);
  bool isOnline() => ref.read(connectivityProvider);
  return MessageQueueService(db, chatRepo, isOnline);
});
