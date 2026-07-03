// lib/src/features/calls/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'call_repository.dart';
import 'call_manager.dart';
import 'livekit_token_service.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  final api = ref.read(apiServiceProvider);
  return CallRepository(api);
});

final callManagerProvider = Provider<CallManager>((ref) {
  final callRepo = ref.read(callRepositoryProvider);
  final pusherService = ref.read(pusherServiceProvider);
  return CallManager(callRepo, pusherService);
});

final liveKitTokenServiceProvider = Provider<LiveKitTokenService>((ref) {
  final api = ref.read(apiServiceProvider);
  return LiveKitTokenService(api);
});

/// Keys: `c:<callId from URL>`, `s:<session_id from call_data>`.
final dismissedDeadCallKeysProvider = StateProvider<Set<String>>((ref) => {});

