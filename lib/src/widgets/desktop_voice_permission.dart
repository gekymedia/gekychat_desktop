import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'desktop_microphone_permission_dialog.dart';

/// Desktop voice-note permission flow (WhatsApp-style dialogs).
Future<bool> ensureDesktopMicrophoneForRecording(BuildContext context) {
  return _ensureDesktopMicrophone(
    context,
    purpose: DesktopMicrophonePurpose.voiceNote,
  );
}

/// Desktop in-call microphone permission flow.
Future<bool> ensureDesktopMicrophoneForCall(BuildContext context) {
  return _ensureDesktopMicrophone(
    context,
    purpose: DesktopMicrophonePurpose.call,
  );
}

Future<bool> _ensureDesktopMicrophone(
  BuildContext context, {
  required DesktopMicrophonePurpose purpose,
}) async {
  var status = await Permission.microphone.status;
  if (status.isGranted) return true;

  if (!context.mounted) return false;

  await showDesktopMicrophonePermissionDialog(
    context,
    kind: DesktopMicrophoneDialogKind.allowAccess,
    purpose: purpose,
  );

  if (!context.mounted) return false;

  status = await Permission.microphone.request();
  if (status.isGranted) return true;

  if (!context.mounted) return false;

  await showDesktopMicrophonePermissionDialog(
    context,
    kind: status.isPermanentlyDenied
        ? DesktopMicrophoneDialogKind.denied
        : DesktopMicrophoneDialogKind.allowAccess,
    purpose: purpose,
  );
  return false;
}

Future<void> showDesktopMicrophoneNotFoundDialog(
  BuildContext context, {
  DesktopMicrophonePurpose purpose = DesktopMicrophonePurpose.voiceNote,
}) {
  return showDesktopMicrophonePermissionDialog(
    context,
    kind: DesktopMicrophoneDialogKind.notFound,
    purpose: purpose,
  );
}
