import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/livekit_call_service.dart';
import 'call_manager.dart';
import 'call_repository.dart';
import 'providers.dart';

const String kAlreadyInCallUserMessage =
    "You're already in a call. End it before starting another.";

bool userIsBusyInCall(ProviderContainer container) {
  if (container.read(liveKitCallServiceProvider).hasActiveCall) return true;
  return container.read(callManagerProvider).hasActiveCall;
}

bool _serverCallStatusIsStillOpen(String? status) {
  if (status == null) return true;
  if (status == 'active') return true;
  if (status == 'pending' ||
      status == 'calling' ||
      status == 'ringing' ||
      status == 'ongoing') {
    return true;
  }
  return false;
}

int? _sessionIdForLocalBusyState(ProviderContainer container) {
  return container.read(callManagerProvider).currentCall?.id;
}

Future<void> clearOrphanedLocalCallLayers(ProviderContainer container) async {
  if (container.read(liveKitCallServiceProvider).hasActiveCall) {
    await container.read(liveKitCallServiceProvider).endCall();
  }
  final cm = container.read(callManagerProvider);
  if (cm.hasActiveCall) {
    await cm.abandonCallLocally();
  }
}

Future<void> reconcileLocalCallStateWithServer(
  ProviderContainer container,
) async {
  final cm = container.read(callManagerProvider);
  if (!cm.isCaller && cm.callState == CallState.ringing) {
    return;
  }

  if (!userIsBusyInCall(container)) return;

  final sessionId = _sessionIdForLocalBusyState(container);
  if (sessionId == null) {
    await clearOrphanedLocalCallLayers(container);
    return;
  }

  try {
    final status = await container
        .read(callRepositoryProvider)
        .fetchCallSessionStatus(sessionId);
    if (!_serverCallStatusIsStillOpen(status)) {
      debugPrint(
        'reconcileCallState: server says session $sessionId ended ($status)',
      );
      await clearOrphanedLocalCallLayers(container);
    }
  } catch (e) {
    debugPrint('reconcileCallState: status fetch failed, keeping local busy: $e');
  }
}

void showAlreadyInCallSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(kAlreadyInCallUserMessage)),
  );
}

bool showCallStartFailureIfAny(BuildContext context, Object error) {
  if (error is CallStartException) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.userMessage)),
    );
    return true;
  }
  return false;
}
