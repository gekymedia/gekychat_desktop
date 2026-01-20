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

/// Optimized conversations provider with stale-while-revalidate pattern
final optimizedConversationsProvider = FutureProvider<List<ConversationSummary>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getConversations();
});

/// Optimized groups provider
final optimizedGroupsProvider = FutureProvider<List<GroupSummary>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getGroups();
});

/// Optimized archived conversations provider
final optimizedArchivedConversationsProvider = FutureProvider<List<ConversationSummary>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getArchivedConversations();
});
