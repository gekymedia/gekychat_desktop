import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'desktop_microphone_permission_dialog.dart';

/// Desktop voice-note permission flow (WhatsApp-style dialogs).
Future<bool> ensureDesktopMicrophoneForRecording(BuildContext context) async {
  var status = await Permission.microphone.status;
  if (status.isGranted) return true;

  if (!context.mounted) return false;

  await showDesktopMicrophonePermissionDialog(
    context,
    kind: DesktopMicrophoneDialogKind.allowAccess,
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
  );
  return false;
}

Future<void> showDesktopMicrophoneNotFoundDialog(BuildContext context) {
  return showDesktopMicrophonePermissionDialog(
    context,
    kind: DesktopMicrophoneDialogKind.notFound,
  );
}
