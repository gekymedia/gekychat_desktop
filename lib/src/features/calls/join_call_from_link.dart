import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/session.dart';
import 'call_repository.dart';
import 'livekit_call_screen.dart';
import 'providers.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/storage_url.dart';

const _dismissedDeadCallKeysPrefsKey = 'dismissed_dead_call_keys_v1';
bool _dismissedDeadCallKeysHydrated = false;

Future<void> hydrateDismissedDeadCallKeys(ProviderContainer container) async {
  if (_dismissedDeadCallKeysHydrated) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_dismissedDeadCallKeysPrefsKey) ?? const [];
    if (saved.isNotEmpty) {
      container.read(dismissedDeadCallKeysProvider.notifier).state = {
        ...container.read(dismissedDeadCallKeysProvider),
        ...saved,
      };
    }
  } catch (_) {}
  _dismissedDeadCallKeysHydrated = true;
}

bool ongoingCallBannerSuppressed(
  ProviderContainer container,
  Map<String, dynamic> callData,
) {
  final dismissed = container.read(dismissedDeadCallKeysProvider);
  final sid = callData['session_id']?.toString();
  if (sid != null && sid.isNotEmpty && dismissed.contains('s:$sid')) {
    return true;
  }
  final link = callData['call_link'];
  if (link is! String || link.isEmpty) return false;
  try {
    final uri = Uri.parse(
      link.startsWith('http') ? link : 'https://chat.gekychat.com$link',
    );
    final segments = uri.pathSegments;
    final idx = segments.indexOf('join');
    if (idx >= 0 && idx < segments.length - 1) {
      final callId = segments[idx + 1];
      if (dismissed.contains('c:$callId')) return true;
    }
  } catch (_) {}
  return false;
}

void rememberDismissedDeadCall(
  ProviderContainer container,
  String callLink,
  Map<String, dynamic> callData,
) {
  try {
    final uri = Uri.parse(
      callLink.startsWith('http')
          ? callLink
          : 'https://chat.gekychat.com$callLink',
    );
    final segments = uri.pathSegments;
    final idx = segments.indexOf('join');
    if (idx < 0 || idx >= segments.length - 1) return;
    final callId = segments[idx + 1];
    final sid = callData['session_id']?.toString();
    final ctrl = container.read(dismissedDeadCallKeysProvider.notifier);
    ctrl.state = {
      ...ctrl.state,
      'c:$callId',
      if (sid != null && sid.isNotEmpty) 's:$sid',
    };
    unawaited(_persistDismissedDeadCallKeys(ctrl.state.toList()));
  } catch (_) {}
}

Future<void> _persistDismissedDeadCallKeys(List<String> keys) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedDeadCallKeysPrefsKey, keys);
  } catch (_) {}
}

/// Join an active call using the deep link stored on the call message (LiveKit).
Future<void> joinCallFromChatLink(
  BuildContext context,
  String callLink,
  Map<String, dynamic> callData,
) async {
  try {
    final uri = Uri.parse(
      callLink.startsWith('http')
          ? callLink
          : 'https://chat.gekychat.com$callLink',
    );
    final segments = uri.pathSegments;
    final callIdIndex = segments.indexOf('join');

    if (callIdIndex == -1 || callIdIndex >= segments.length - 1) {
      throw Exception('Invalid call link format');
    }

    final callId = segments[callIdIndex + 1];

    final ref = ProviderScope.containerOf(context);
    final callRepo = ref.read(callRepositoryProvider);
    final liveKitTokenService = ref.read(liveKitTokenServiceProvider);

    final response = await callRepo.joinCall(callId);

    if (response['status'] == 'success' && response['session_id'] != null) {
      final sessionId = response['session_id'] as int;
      await callRepo.acceptIncomingCallSession(sessionId);

      final callType = response['type'] as String? ??
          callData['type'] as String? ??
          'voice';
      final conversationId = response['conversation_id'] as int?;
      final groupId = response['group_id'] as int?;
      final callerName = response['caller_name'] as String?;
      final callerAvatar = resolveAvatarUrl(
        response['caller_avatar']?.toString(),
      );
      final roomName = 'call_$sessionId';
      final currentUser = await ref.read(currentUserProvider.future);
      final displayName =
          currentUser.name.trim().isNotEmpty ? currentUser.name.trim() : 'User';
      final tokenResult = await liveKitTokenService.fetchToken(
        roomName: roomName,
        displayName: displayName,
      );
      final cn = callerName?.trim();
      final title = (cn != null && cn.isNotEmpty)
          ? cn
          : (groupId != null ? 'Group call' : 'Call');

      if (context.mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => LiveKitCallScreen(
              url: tokenResult.url,
              token: tokenResult.token,
              roomName: roomName,
              callId: sessionId,
              videoEnabled: callType == 'video',
              peerName: title,
              peerAvatar: callerAvatar,
              groupId: groupId,
              conversationId: conversationId,
              isOutgoingCall: false,
            ),
          ),
        );
      }
    } else {
      throw Exception(response['message']?.toString() ?? 'Failed to join call');
    }
  } catch (e) {
    if (e is CallJoinException) {
      final m = e.userMessage.toLowerCase();
      final dismissStale = m.contains('no longer') ||
          m.contains('ended') ||
          m.contains('not available');
      if (dismissStale) {
        try {
          rememberDismissedDeadCall(
            ProviderScope.containerOf(context),
            callLink,
            callData,
          );
        } catch (_) {}
      }
    }
    final friendlyMessage = e is CallJoinException
        ? e.userMessage
        : 'Unable to join call. Please try again.';
    if (context.mounted) {
            context.showErrorToast(friendlyMessage);    }
  }
}
