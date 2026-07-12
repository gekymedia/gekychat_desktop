import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/desktop_center_modal.dart';

/// Curated birthday sticker pack (large emoji rendered as transparent PNG).
const birthdayStickerEmojis = [
  '🎂',
  '🎉',
  '🥳',
  '🎁',
  '🎈',
  '🎊',
  '🍰',
  '🧁',
  '✨',
  '💖',
  '🎆',
  '🪅',
  '🎇',
  '🌟',
  '💐',
  '🥂',
  '🎀',
  '❤️',
  '🤗',
  '🙌',
  '👏',
  '😍',
  '🤩',
  '💯',
];

Future<void> showBirthdayStickerPicker(
  BuildContext context, {
  required String celebrantName,
  required Future<void> Function(File stickerFile) onSelected,
}) {
  return showDesktopCenterModal<void>(
    context: context,
    title: 'Birthday stickers',
    maxWidth: 380,
    maxHeightFraction: 0.72,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Send to $celebrantName',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white54
                  : const Color(0xFF667781),
            ),
          ),
        ),
        Expanded(
          child: _BirthdayStickerGrid(
            onPick: (emoji) async {
              try {
                final file = await _BirthdayEmojiRenderer().renderToFile(emoji);
                if (context.mounted) Navigator.pop(context);
                await onSelected(file);
              } catch (e) {
                if (context.mounted) {
                  context.showErrorToast('Failed to create sticker: $e');
                }
              }
            },
          ),
        ),
      ],
    ),
  );
}

class _BirthdayStickerGrid extends StatelessWidget {
  const _BirthdayStickerGrid({required this.onPick});

  final Future<void> Function(String emoji) onPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: birthdayStickerEmojis.length,
      itemBuilder: (context, index) {
        final emoji = birthdayStickerEmojis[index];
        return Material(
          color: isDark
              ? const Color(0xFF1F2C34)
              : AppTheme.primaryGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onPick(emoji),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
          ),
        );
      },
    );
  }
}

class _BirthdayEmojiRenderer {
  Future<File> renderToFile(String emoji) async {
    const double size = 160.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = Colors.transparent,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: const TextStyle(fontSize: 120, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size);

    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/birthday_sticker_${emoji.hashCode}.png');
    await file.writeAsBytes(bytes);
    return file;
  }
}
