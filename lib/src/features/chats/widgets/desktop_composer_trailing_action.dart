import 'package:flutter/material.dart';
import 'desktop_message_composer_pill.dart';

/// WhatsApp Web–style trailing control: microphone when empty, send when there is text.
class DesktopComposerTrailingAction extends StatelessWidget {
  const DesktopComposerTrailingAction({
    super.key,
    required this.showSend,
    required this.isRecording,
    required this.onSend,
    required this.onMicPress,
    required this.isDark,
  });

  final bool showSend;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onMicPress;
  final bool isDark;

  static const _accent = Color(0xFF008069);

  @override
  Widget build(BuildContext context) {
    if (isRecording) return const SizedBox(width: 4);

    final idleColor = isDark ? Colors.white70 : const Color(0xFF54656F);

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: SizedBox(
        width: 44,
        height: DesktopMessageComposerPill.barHeight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: showSend
              ? Center(
                  key: const ValueKey('send'),
                  child: Material(
                    color: _accent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onSend,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                )
              : IconButton(
                  key: const ValueKey('mic'),
                  icon: Icon(Icons.mic, color: idleColor, size: 22),
                  onPressed: onMicPress,
                  tooltip: 'Record voice message',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.center,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
        ),
      ),
    );
  }
}
