# Offline-First Integration Guide - Desktop (Flutter)

## 🖥️ Overview

This guide explains how to integrate and enhance offline-first messaging functionality in the GekyChat desktop app (Flutter).

## ✅ Current State

Your desktop app already has:
- ✅ **Drift database** with `OfflineMessages` table
- ✅ **MessageQueueService** for offline message queue
- ✅ **ConnectivityProvider** for network detection
- ✅ Basic offline message handling

## 🎯 Enhancements Needed

### 1. Add `client_uuid` Support

Update your `Messages` table in `app_database.dart`:

```dart
// In lib/src/core/database/app_database.dart

class Messages extends Table {
  IntColumn get id => integer().nullable()(); // Nullable for pending
  TextColumn get clientUuid => text()(); // Add this - unique client ID
  IntColumn get conversationId => integer().nullable()();
  IntColumn get groupId => integer().nullable()();
  IntColumn get senderId => integer()();
  TextColumn get body => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // Add status
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get serverCreatedAt => dateTime().nullable()();
  // ... rest of fields
  
  @override
  Set<Column> get primaryKey => {clientUuid}; // Use clientUuid as primary key
}
```

### 2. Enhanced MessageQueueService

Update your existing `MessageQueueService`:

```dart
// In lib/src/core/database/message_queue_service.dart

import 'package:uuid/uuid.dart';

class MessageQueueService {
  final AppDatabase _db;
  final ChatRepository _chatRepo;
  final bool Function() _isOnline;
  static const _uuid = Uuid();

  // Enhanced queue message with client_uuid
  Future<String> queueMessageWithUuid({
    required int? conversationId,
    required int? groupId,
    required String body,
    int? replyToId,
    int? forwardFromId,
    List<File>? attachments,
    Map<String, dynamic>? locationData,
    Map<String, dynamic>? contactData,
  }) async {
    // Generate client UUID
    final clientUuid = _uuid.v4();

    // Serialize attachments
    String? attachmentsJson;
    if (attachments != null && attachments.isNotEmpty) {
      attachmentsJson = jsonEncode(attachments.map((f) => f.path).toList());
    }

    // Save to offline messages queue
    final companion = OfflineMessagesCompanion(
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
      clientUuid: Value(clientUuid), // Add client UUID
    );

    final id = await _db.into(_db.offlineMessages).insert(companion);

    // Also save to messages table with pending status
    await _db.into(_db.messages).insert(MessagesCompanion.insert(
      clientUuid: clientUuid,
      conversationId: Value(conversationId),
      groupId: Value(groupId),
      body: body,
      status: const Value('pending'),
      createdAt: DateTime.now(),
      senderId: Value(await _getCurrentUserId()),
      // ... other fields
    ));

    // Try to send immediately if online
    if (_isOnline()) {
      unawaited(syncPendingMessages());
    }

    return clientUuid;
  }

  // Enhanced sync with client_uuid support
  Future<void> syncPendingMessages() async {
    if (!_isOnline()) {
      return;
    }

    final pending = await getPendingMessages();

    for (final queuedMessage in pending) {
      try {
        if (queuedMessage.retryCount > 5) {
          await markAsFailed(queuedMessage.id, 'Max retry attempts reached');
          continue;
        }

        // Parse attachments
        List<File>? attachments;
        if (queuedMessage.attachmentsJson != null) {
          try {
            final paths = jsonDecode(queuedMessage.attachmentsJson!) as List;
            attachments = paths
                .map((path) => File(path.toString()))
                .where((f) => f.existsSync())
                .toList();
            if (attachments.isEmpty) attachments = null;
          } catch (e) {
            // Ignore parsing errors
          }
        }

        // Prepare request with client_uuid
        dynamic data;
        if (attachments != null && attachments.isNotEmpty) {
          final formData = FormData();
          formData.fields.add(MapEntry('body', queuedMessage.body));
          formData.fields.add(MapEntry('client_uuid', queuedMessage.clientUuid ?? _uuid.v4()));
          if (queuedMessage.replyToId != null) {
            formData.fields.add(MapEntry('reply_to', queuedMessage.replyToId.toString()));
          }
          // Add attachments...
          data = formData;
        } else {
          data = {
            'body': queuedMessage.body,
            'client_uuid': queuedMessage.clientUuid ?? _uuid.v4(),
            if (queuedMessage.replyToId != null) 'reply_to': queuedMessage.replyToId,
          };
        }

        // Send message
        final sentMessage = queuedMessage.conversationId != null
            ? await _chatRepo.sendMessageToConversation(
                conversationId: queuedMessage.conversationId!,
                body: queuedMessage.body.isEmpty ? null : queuedMessage.body,
                replyTo: queuedMessage.replyToId,
                forwardFrom: queuedMessage.forwardFromId,
                attachments: attachments,
                clientUuid: queuedMessage.clientUuid, // Pass client_uuid
              )
            : (queuedMessage.groupId != null
                ? await _chatRepo.sendMessageToGroup(
                    groupId: queuedMessage.groupId!,
                    body: queuedMessage.body.isEmpty ? null : queuedMessage.body,
                    replyToId: queuedMessage.replyToId,
                    forwardFrom: queuedMessage.forwardFromId,
                    attachments: attachments,
                    clientUuid: queuedMessage.clientUuid, // Pass client_uuid
                  )
                : null);

        if (sentMessage != null) {
          await markAsSent(queuedMessage.id, sentMessage.id);

          // Update message status in messages table
          if (queuedMessage.clientUuid != null) {
            await (_db.update(_db.messages)
                  ..where((m) => m.clientUuid.equals(queuedMessage.clientUuid!)))
                .write(MessagesCompanion(
                  id: Value(sentMessage.id),
                  status: const Value('sent'),
                  serverCreatedAt: Value(sentMessage.createdAt),
                ));
          }
        } else {
          await markAsFailed(queuedMessage.id, 'Failed to send message');
        }
      } catch (e) {
        await markAsFailed(queuedMessage.id, e.toString());
      }
    }

    await cleanupOldMessages();
  }

  Future<int> _getCurrentUserId() async {
    // Get current user ID from session
    // Implementation depends on your session management
    return 0; // Replace with actual implementation
  }
}
```

### 3. Update ChatRepository

Enhance your `ChatRepository` to support `client_uuid`:

```dart
// In lib/src/features/chats/chat_repo.dart

Future<Message> sendMessageToConversation({
  required int conversationId,
  String? body,
  int? replyTo,
  int? forwardFrom,
  List<File>? attachments,
  String? clientUuid, // Add this parameter
}) async {
  try {
    // Prepare request
    dynamic data;
    if (attachments != null && attachments.isNotEmpty) {
      final formData = FormData();
      if (body != null && body.isNotEmpty) {
        formData.fields.add(MapEntry('body', body));
      }
      if (clientUuid != null) {
        formData.fields.add(MapEntry('client_uuid', clientUuid));
      }
      if (replyTo != null) {
        formData.fields.add(MapEntry('reply_to', replyTo.toString()));
      }
      // Add attachments...
      data = formData;
    } else {
      data = {
        if (body != null && body.isNotEmpty) 'body': body,
        if (clientUuid != null) 'client_uuid': clientUuid,
        if (replyTo != null) 'reply_to': replyTo,
        if (forwardFrom != null) 'forward_from': forwardFrom,
      };
    }

    // Send to API
    final response = await apiService.post(
      '/conversations/$conversationId/messages',
      data: data,
    );

    return Message.fromJson(response.data['data']);
  } catch (e) {
    rethrow;
  }
}
```

### 4. Enhanced Connectivity Provider

Update your connectivity provider:

```dart
// In lib/src/core/providers/connectivity_provider.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectivityNotifier() : super(ConnectivityState.initial()) {
    _init();
  }

  void _init() {
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    final hasInternet = await _hasInternetConnection();

    state = ConnectivityState(
      isOnline: hasInternet,
      type: result,
      quality: hasInternet ? ConnectionQuality.good : ConnectionQuality.none,
    );

    // Trigger sync when coming online
    if (hasInternet) {
      // Notify sync service
      // ref.read(messageQueueServiceProvider).syncPendingMessages();
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      if (await _connectivity.checkConnectivity() == ConnectivityResult.none) {
        return false;
      }

      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

enum ConnectionQuality {
  none,
  poor,
  degraded,
  good,
}

class ConnectivityState {
  final bool isOnline;
  final ConnectivityResult type;
  final ConnectionQuality quality;

  ConnectivityState({
    required this.isOnline,
    required this.type,
    required this.quality,
  });

  factory ConnectivityState.initial() {
    return ConnectivityState(
      isOnline: true, // Assume online initially
      type: ConnectivityResult.other,
      quality: ConnectionQuality.good,
    );
  }
}
```

### 5. UI Status Indicator Widget

Create a connection status widget:

```dart
// lib/src/widgets/connection_status_indicator.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/connectivity_provider.dart';

class ConnectionStatusIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: connectivity.isOnline
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connectivity.isOnline ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: connectivity.isOnline ? Colors.green : Colors.red,
          ),
          SizedBox(width: 6),
          Text(
            connectivity.isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: connectivity.isOnline ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
```

### 6. Message Status Indicator

Add status icons to messages:

```dart
// In your message bubble widget

Widget _buildMessageStatus(String status, bool isOutgoing) {
  if (!isOutgoing) return SizedBox.shrink();

  IconData icon;
  Color color;

  switch (status) {
    case 'pending':
      icon = Icons.access_time;
      color = Colors.grey;
      break;
    case 'sending':
      icon = Icons.send;
      color = Colors.grey;
      break;
    case 'sent':
      icon = Icons.check;
      color = Colors.grey;
      break;
    case 'delivered':
      icon = Icons.done_all;
      color = Colors.grey;
      break;
    case 'read':
      icon = Icons.done_all;
      color = Colors.blue;
      break;
    case 'failed':
      icon = Icons.error;
      color = Colors.red;
      break;
    default:
      return SizedBox.shrink();
  }

  return Icon(icon, size: 14, color: color);
}
```

### 7. Auto-Sync Timer

Add periodic sync:

```dart
// In your main app or chat screen

class ChatScreen extends ConsumerStatefulWidget {
  // ...
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _startSyncTimer();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final connectivity = ref.read(connectivityProvider);
      if (connectivity.isOnline) {
        ref.read(messageQueueServiceProvider).syncPendingMessages();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // ...
}
```

## 🔄 Integration Steps

### Step 1: Update Database Schema

1. Add `clientUuid` to `Messages` and `OfflineMessages` tables
2. Add `status` field to `Messages` table
3. Run migrations: `flutter pub run build_runner build --delete-conflicting-outputs`

### Step 2: Update Message Sending

```dart
// Before
await chatRepo.sendMessageToConversation(
  conversationId: id,
  body: text,
);

// After
final clientUuid = await messageQueueService.queueMessageWithUuid(
  conversationId: id,
  body: text,
);
```

### Step 3: Add Status Indicator

Add to your app bar or status bar:

```dart
AppBar(
  actions: [
    ConnectionStatusIndicator(),
    // ... other actions
  ],
)
```

### Step 4: Update Message Display

Show status for outgoing messages:

```dart
MessageBubble(
  message: message,
  trailing: _buildMessageStatus(message.status, message.isOutgoing),
)
```

## 🧪 Testing

### Test Offline Sending

1. Disconnect internet
2. Send message
3. Verify pending status
4. Reconnect internet
5. Verify sync and status update

### Test Cache Loading

1. Load conversation online
2. Disconnect internet
3. Restart app
4. Verify messages load from cache

## 📊 Monitoring

Add sync metrics:

```dart
class SyncMetrics {
  static int messagesSynced = 0;
  static int syncErrors = 0;
  static DateTime? lastSyncTime;

  static void recordSync({required bool success}) {
    if (success) {
      messagesSynced++;
    } else {
      syncErrors++;
    }
    lastSyncTime = DateTime.now();
  }
}
```

## ✅ Checklist

- [ ] Update database schema with `clientUuid` and `status`
- [ ] Enhance `MessageQueueService` with `client_uuid` support
- [ ] Update `ChatRepository` to accept `client_uuid`
- [ ] Enhance connectivity provider
- [ ] Add UI status indicators
- [ ] Update message sending logic
- [ ] Test offline functionality
- [ ] Test sync on connectivity restore

---

**Last Updated**: 2025-01-XX  
**Version**: 1.0.0
