import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class EmojiPickerWidget extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;
  final VoidCallback onBackspace;

  const EmojiPickerWidget({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          onEmojiSelected(emoji.emoji);
        },
        onBackspacePressed: onBackspace,
        config: Config(
          height: 256,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: 28 * (1.0),
          ),
          skinToneConfig: const SkinToneConfig(),
          categoryViewConfig: const CategoryViewConfig(),
          bottomActionBarConfig: const BottomActionBarConfig(),
          searchViewConfig: const SearchViewConfig(),
        ),
      ),
    );
  }
}


