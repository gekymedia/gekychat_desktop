import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';
import '../core/providers/connectivity_provider.dart';
import '../core/services/taskbar_badge_service.dart';
import '../features/chats/chat_providers.dart';
import '../features/chats/models.dart';

/// Pulls missing messages from the server into the local Drift cache.
/// Mirrors mobile [SyncService] incremental `after_id` sync for desktop.
class MessageSyncService {
  MessageSyncService(this._ref);

  final Ref _ref;
  static bool _syncInProgress = false;
  static const _smartSyncMaxAgeDays = 7;
  static const _lastSmartSyncKey = 'desktop_last_smart_sync';

  Future<void> syncInbox({bool force = false}) async {
    if (_syncInProgress) {
      debugPrint('⏭️ Desktop message sync already in progress');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      debugPrint('⏭️ Desktop message sync skipped (not logged in)');
      return;
    }

    if (!_ref.read(connectivityProvider)) {
      debugPrint('⏭️ Desktop message sync skipped (offline)');
      return;
    }

    _syncInProgress = true;
    try {
      debugPrint('🔄 Desktop message sync starting${force ? ' (forced)' : ''}…');

      final chatRepo = _ref.read(chatRepositoryProvider);
      final storage = _ref.read(localStorageServiceProvider);

      // Refresh inbox lists so new chats appear in the local DB.
      await chatRepo.getConversations();
      final groups = await chatRepo.getGroups();
      try {
        await chatRepo.getArchivedConversations();
      } catch (e) {
        debugPrint('Archived conversations refresh (non-fatal): $e');
      }

      final openConversationId = _ref.read(selectedConversationProvider);
      final openGroupId = _ref.read(selectedGroupIdProvider);
      final userId = prefs.getInt('user_id');

      var conversationIds = await storage.getCachedConversationIds();
      conversationIds = await _resolveConversationIds(conversationIds, prefs, force);

      final groupIds = groups.map((g) => g.id).where((id) => id > 0).toList();

      var pulledCount = 0;

      for (final convId in conversationIds) {
        if (convId <= 0) continue;
        try {
          final messages =
              await chatRepo.pullNewMessagesForConversation(convId);
          if (messages.isEmpty) continue;
          pulledCount += messages.length;
          await _bumpConversationPreview(
            convId,
            messages,
            userId: userId,
            viewingOpenChat: openConversationId == convId,
          );
        } catch (e) {
          debugPrint('Desktop sync conversation $convId: $e');
        }
      }

      for (final groupId in groupIds) {
        if (groupId <= 0) continue;
        try {
          final messages = await chatRepo.pullNewMessagesForGroup(groupId);
          if (messages.isEmpty) continue;
          pulledCount += messages.length;
          await _bumpGroupPreview(
            groupId,
            messages,
            userId: userId,
            viewingOpenChat: openGroupId == groupId,
          );
        } catch (e) {
          final forbidden = e.toString().contains('403') ||
              e.toString().toLowerCase().contains('forbidden');
          if (forbidden) {
            debugPrint(
              'Desktop sync group $groupId: skipped (no longer a member)',
            );
            await storage.removeGroup(groupId);
          } else {
            debugPrint('Desktop sync group $groupId: $e');
          }
        }
      }

      if (pulledCount > 0) {
        debugPrint('✅ Desktop message sync pulled $pulledCount message(s)');
        _ref.read(inboxListRefreshTickProvider.notifier).state++;
        _ref.read(inboxBackgroundSyncTickProvider.notifier).state++;
        unawaited(_ref.read(taskbarBadgeServiceProvider).updateBadge());
      } else {
        debugPrint('✅ Desktop message sync — nothing new');
      }

      await prefs.setString(
        _lastSmartSyncKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } finally {
      _syncInProgress = false;
    }
  }

  /// Prefer smart sync (only changed conversations) when we synced recently.
  Future<List<int>> _resolveConversationIds(
    List<int> cachedIds,
    SharedPreferences prefs,
    bool force,
  ) async {
    if (force) return cachedIds;

    final sinceIso = prefs.getString(_lastSmartSyncKey);
    if (sinceIso == null || sinceIso.isEmpty) return cachedIds;

    final since = DateTime.tryParse(sinceIso);
    if (since == null) return cachedIds;
    if (DateTime.now().toUtc().difference(since).inDays >= _smartSyncMaxAgeDays) {
      return cachedIds;
    }

    try {
      final response =
          await _ref.read(apiServiceProvider).getSyncChanges(sinceIso);
      final data = response.data;
      if (data is! Map || data['conversations_updated'] is! List) {
        return cachedIds;
      }
      final updated = (data['conversations_updated'] as List)
          .map((e) {
            if (e is! Map) return null;
            final id = e['id'];
            if (id is int) return id;
            return int.tryParse(id?.toString() ?? '');
          })
          .whereType<int>()
          .where((id) => id > 0)
          .toSet()
          .toList();
      if (updated.isEmpty) return const [];
      debugPrint(
        '📥 Desktop smart sync: ${updated.length} changed conversation(s)',
      );
      return updated;
    } catch (e) {
      debugPrint('Desktop smart sync fallback: $e');
      return cachedIds;
    }
  }

  Future<void> _bumpConversationPreview(
    int conversationId,
    List<Message> messages, {
    required int? userId,
    required bool viewingOpenChat,
  }) async {
    if (messages.isEmpty) return;
    final newest = messages.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
    final fromMe = userId != null && newest.senderId == userId;
    try {
      await _ref.read(localStorageServiceProvider).bumpConversationFromInbox(
            conversationId: conversationId,
            lastMessage: _previewBody(newest),
            fromMe: fromMe,
            updatedAt: newest.createdAt,
            incrementUnread: !fromMe && !viewingOpenChat,
          );
    } catch (e) {
      debugPrint('Desktop sync bump conversation: $e');
    }
  }

  Future<void> _bumpGroupPreview(
    int groupId,
    List<Message> messages, {
    required int? userId,
    required bool viewingOpenChat,
  }) async {
    if (messages.isEmpty) return;
    final newest = messages.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
    final fromMe = userId != null && newest.senderId == userId;
    try {
      await _ref.read(localStorageServiceProvider).bumpGroupFromInbox(
            groupId: groupId,
            lastMessage: _previewBody(newest),
            fromMe: fromMe,
            updatedAt: newest.createdAt,
            incrementUnread: !fromMe && !viewingOpenChat,
          );
    } catch (e) {
      debugPrint('Desktop sync bump group: $e');
    }
  }

  static String _previewBody(Message message) {
    final text = message.body.trim();
    if (text.isNotEmpty) {
      return text.length > 120 ? '${text.substring(0, 117)}...' : text;
    }
    if (message.attachments.isNotEmpty) return '📎 Attachment';
    return 'New message';
  }
}

final messageSyncServiceProvider = Provider<MessageSyncService>((ref) {
  return MessageSyncService(ref);
});

/// Incremented after a background pull so open chat panes can refresh quietly.
final inboxBackgroundSyncTickProvider = StateProvider<int>((ref) => 0);
