import 'package:flutter/material.dart';
import 'desktop_typography.dart';

enum DesktopMicrophoneDialogKind {
  allowAccess,
  notFound,
  denied,
}

/// WhatsApp-style microphone permission / hardware dialogs for desktop voice notes.
Future<void> showDesktopMicrophonePermissionDialog(
  BuildContext context, {
  required DesktopMicrophoneDialogKind kind,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  late final String title;
  late final String body;

  switch (kind) {
    case DesktopMicrophoneDialogKind.allowAccess:
      title = 'Allow microphone';
      body =
          'To record voice messages, allow GekyChat access to your microphone '
          'when Windows asks.';
    case DesktopMicrophoneDialogKind.notFound:
      title = 'Microphone not found';
      body =
          "You can't record a voice message because it looks like your computer "
          "doesn't have a microphone. Try connecting one, or restart the app "
          'after plugging it in.';
    case DesktopMicrophoneDialogKind.denied:
      title = 'Microphone access needed';
      body =
          'Microphone access is turned off for GekyChat. Open Windows Settings → '
          'Privacy → Microphone and allow access for this app.';
  }

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: isDark ? const Color(0xFF233138) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF0F2F5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          kind == DesktopMicrophoneDialogKind.notFound
                              ? Icons.mic_off_rounded
                              : Icons.mic_none_rounded,
                          color: isDark ? Colors.white70 : const Color(0xFF54656F),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontFamily: DesktopTypography.fontFamily,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              body,
                              style: TextStyle(
                                fontFamily: DesktopTypography.fontFamily,
                                fontSize: 14,
                                height: 1.45,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF54656F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF008069)
                            : const Color(0xFF111B21),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('OK, got it'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

bool desktopMicrophoneNotFoundError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('not found') ||
      msg.contains('no device') ||
      msg.contains('no microphone') ||
      msg.contains('input device');
}
