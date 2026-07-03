import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/global_navigator_key.dart';
import 'livekit_call_screen.dart';

/// Push a route on [rootNavigatorKey] (above GoRouter). Retries until ready.
Future<bool> pushRouteOnRootNavigator(
  Route<void> route, {
  required String logLabel,
  bool replace = false,
  VoidCallback? onRoutePopped,
}) async {
  const maxAttempts = 80;
  const delay = Duration(milliseconds: 200);

  for (var i = 0; i < maxAttempts; i++) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator != null) {
      final pushed = Completer<bool>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pushed.isCompleted) return;
        try {
          final Future<void> routeFuture;
          if (replace) {
            routeFuture = navigator.pushReplacement(route);
          } else {
            routeFuture = navigator.push(route);
          }
          if (onRoutePopped != null) {
            routeFuture.whenComplete(onRoutePopped);
          }
          pushed.complete(true);
        } catch (e, st) {
          debugPrint('❌ $logLabel push failed: $e');
          debugPrint('$st');
          if (!pushed.isCompleted) pushed.complete(false);
        }
      });
      return pushed.future;
    }
    await Future.delayed(delay);
  }
  debugPrint(
    '⚠️ $logLabel: root navigator not ready after ${maxAttempts * 200}ms',
  );
  return false;
}

/// Opens [LiveKitCallScreen] on the root navigator so call UI covers the app.
Future<void> pushLiveKitCallScreenOnRoot({
  String? url,
  String? token,
  required String roomName,
  required int callId,
  bool videoEnabled = false,
  bool deferCredentialFetch = false,
  bool isOutgoingCall = false,
  String? peerName,
  String? peerAvatar,
  int? conversationId,
  int? groupId,
  bool replace = false,
  VoidCallback? onRoutePopped,
}) async {
  final route = MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => LiveKitCallScreen(
      url: url,
      token: token,
      roomName: roomName,
      callId: callId,
      videoEnabled: videoEnabled,
      deferCredentialFetch: deferCredentialFetch,
      isOutgoingCall: isOutgoingCall,
      peerName: peerName,
      peerAvatar: peerAvatar,
      conversationId: conversationId,
      groupId: groupId,
    ),
  );

  await pushRouteOnRootNavigator(
    route,
    logLabel: 'LiveKitCallScreen',
    replace: replace,
    onRoutePopped: onRoutePopped,
  );
}
