import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_database.dart' hide Message;
import 'local_storage_service.dart';
import '../../features/chats/chat_repo.dart';
import '../../features/chats/models.dart';
import '../../core/providers/connectivity_provider.dart';

class MessageQueueService {
  final AppDatabase _db;
  final ChatRepository _chatRepo;
  final bool Function() _isOnline;
  static const _uuid = Uuid();

  MessageQueueService(this._db, this._chatRepo, this._isOnline);

  // Queue a message for sending when online (with client_uuid support)
  Future<String> queueMessage({
    required int? conversationId,
    required int? groupId,
    required String body,
    int? replyToId,
    int? forwardFromId,
    List<File>? attachments,
    Map<String, dynamic>? locationData,
    Map<String, dynamic>? contactData,
    String? clientUuid, // Optional: provide client UUID, otherwise generate
  }) async {
    // Generate client UUID if not provided
    final clientId = clientUuid ?? _uuid.v4();
    
    // Serialize attachments (store file paths)
    String? attachmentsJson;
    if (attachments != null && attachments.isNotEmpty) {
      attachmentsJson = jsonEncode(attachments.map((f) => f.path).toList());
    }

    final companion = OfflineMessagesCompanion(
      clientUuid: Value(clientId), // Add client UUID
      conversationId: Value(conversationId),
      groupId: Value(groupId),
      body: Value(body),
      replyToId: Value(replyToId),
      forwardFromId: Value(forwardFromId),
      attachmentsJson: Value(attachmentsJson),
      locationDataJson: Value(locationData != null ? jsonEncode(locationData) : null),
      contactDataJson: Value(contactData != null ? jsonEncode(contactData) : null),
      isSent: const Value(false),
      retryCount: const Value(0),
    );

    await _db.into(_db.offlineMessages).insert(companion);
    
    // Also save to Messages table with pending status
    await _db.into(_db.messages).insert(MessagesCompanion.insert(
      clientUuid: clientId,
      conversationId: Value(conversationId),
      groupId: Value(groupId),
      body: body,
      status: const Value('pending'),
      createdAt: DateTime.now(),
      senderId: Value(await _getCurrentUserId()),
      // ... other fields
    ));
    
    return clientId;
  }
  
  Future<int> _getCurrentUserId() async {
    // Get current user ID from session/storage
    // Implementation depends on your session management
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? 0; // Replace with actual implementation
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

        // Get client UUID from queued message
        final clientUuid = queuedMessage.clientUuid ?? _uuid.v4();
        
        // Send the message with client_uuid
        final sentMessage = queuedMessage.conversationId != null
            ? await _chatRepo.sendMessageToConversation(
                conversationId: queuedMessage.conversationId!,
                body: queuedMessage.body.isEmpty ? null : queuedMessage.body,
                replyTo: queuedMessage.replyToId,
                forwardFrom: queuedMessage.forwardFromId,
                attachments: attachments,
                clientUuid: clientUuid, // Pass client_uuid
              )
            : (queuedMessage.groupId != null
                ? await _chatRepo.sendMessageToGroup(
                    groupId: queuedMessage.groupId!,
                    body: queuedMessage.body.isEmpty ? null : queuedMessage.body,
                    replyToId: queuedMessage.replyToId,
                    forwardFrom: queuedMessage.forwardFromId,
                    attachments: attachments,
                    clientUuid: clientUuid, // Pass client_uuid
                  )
                : null);

        // Mark as sent
        if (sentMessage != null) {
          await markAsSent(queuedMessage.id, sentMessage.id);
          
          // Update message status in messages table
          await (_db.update(_db.messages)
                ..where((m) => m.clientUuid.equals(clientUuid)))
              .write(MessagesCompanion(
                id: Value(sentMessage.id),
                status: const Value('sent'),
                serverCreatedAt: Value(sentMessage.createdAt),
              ));
        } else {
          await markAsFailed(queuedMessage.id, 'Failed to send message');
          
          // Update message status to failed
          await (_db.update(_db.messages)
                ..where((m) => m.clientUuid.equals(clientUuid)))
              .write(MessagesCompanion(
                status: const Value('failed'),
              ));
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
  final isOnline = () => ref.read(connectivityProvider);
  return MessageQueueService(db, chatRepo, isOnline);
});
