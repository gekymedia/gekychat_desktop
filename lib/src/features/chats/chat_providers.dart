import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_repo.dart';
import 'models.dart';
import '../../core/providers.dart';
import '../../core/providers/connectivity_provider.dart';

/// Provider for chat repository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final localStorageService = ref.watch(localStorageServiceProvider);
  final isOnline = ref.watch(connectivityProvider);
  return ChatRepository(
    apiService,
    localStorageService: localStorageService,
    isOnline: isOnline,
  );
});

/// Cached conversations provider - Telegram-style: shows cached data immediately while refreshing
/// This provider keeps data alive and refreshes in background without blocking UI
final conversationsProvider = FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getConversations();
}).keepAlive(); // Keep data in memory across rebuilds

/// Cached archived conversations provider
final archivedConversationsProvider = FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getArchivedConversations();
}).keepAlive();

/// Cached groups provider - Telegram-style: shows cached data immediately while refreshing
final groupsProvider = FutureProvider.autoDispose<List<GroupSummary>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getGroups();
}).keepAlive();

/// Helper extension to add keepAlive to FutureProvider
extension KeepAliveExtension<T> on AutoDisposeFutureProvider<T> {
  AutoDisposeFutureProvider<T> keepAlive() {
    return FutureProvider.autoDispose<T>((ref) async {
      // Keep provider alive by watching a dummy provider
      ref.keepAlive();
      final original = this;
      final value = await ref.watch(original.future);
      return value;
    });
  }
}

/// Tick counter — background inbox refresh (keeps previous list visible).
final inboxListRefreshTickProvider = StateProvider<int>((ref) => 0);

/// Sidebar conversations — stale-while-revalidate; tick triggers silent refresh.
class OptimizedConversationsNotifier
    extends AsyncNotifier<List<ConversationSummary>> {
  @override
  Future<List<ConversationSummary>> build() async {
    ref.listen(inboxListRefreshTickProvider, (previous, next) {
      if (previous != next) {
        unawaited(refreshSilently());
      }
    });
    ref.watch(chatRepositoryProvider);
    return ref.read(chatRepositoryProvider).getConversations();
  }

  /// Refetch without clearing the sidebar (no skeleton flash).
  Future<void> refreshSilently() async {
    if (!state.hasValue) return;
    try {
      final fresh = await ref.read(chatRepositoryProvider).getConversations();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncValue<List<ConversationSummary>>.error(
        e,
        st,
      ).copyWithPrevious(state);
    }
  }
}

final optimizedConversationsProvider = AsyncNotifierProvider<
    OptimizedConversationsNotifier,
    List<ConversationSummary>>(OptimizedConversationsNotifier.new);

/// Sidebar groups — same silent refresh pattern as conversations.
class OptimizedGroupsNotifier extends AsyncNotifier<List<GroupSummary>> {
  @override
  Future<List<GroupSummary>> build() async {
    ref.listen(inboxListRefreshTickProvider, (previous, next) {
      if (previous != next) {
        unawaited(refreshSilently());
      }
    });
    ref.watch(chatRepositoryProvider);
    return ref.read(chatRepositoryProvider).getGroups();
  }

  Future<void> refreshSilently() async {
    if (!state.hasValue) return;
    try {
      final fresh = await ref.read(chatRepositoryProvider).getGroups();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncValue<List<GroupSummary>>.error(e, st).copyWithPrevious(state);
    }
  }
}

final optimizedGroupsProvider =
    AsyncNotifierProvider<OptimizedGroupsNotifier, List<GroupSummary>>(
  OptimizedGroupsNotifier.new,
);

/// Optimized archived conversations provider
final optimizedArchivedConversationsProvider = FutureProvider<List<ConversationSummary>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getArchivedConversations();
});
