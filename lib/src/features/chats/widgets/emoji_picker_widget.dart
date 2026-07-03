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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    final panelBg = isDark ? const Color(0xFF202C33) : const Color(0xFFEBEFF2);
    final primary = scheme.primary;
    final onSurface = isDark ? Colors.white70 : scheme.onSurfaceVariant;
    final onSurfaceMuted = isDark ? Colors.white54 : scheme.onSurfaceVariant;

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
            backgroundColor: panelBg,
            noRecents: Text(
              'No Recents',
              style: TextStyle(fontSize: 16, color: onSurfaceMuted),
              textAlign: TextAlign.center,
            ),
            buttonMode: ButtonMode.MATERIAL,
          ),
          skinToneConfig: SkinToneConfig(
            dialogBackgroundColor:
                isDark ? const Color(0xFF2A3942) : scheme.surfaceContainerHighest,
            indicatorColor: primary,
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: panelBg,
            indicatorColor: primary,
            iconColor: onSurface,
            iconColorSelected: primary,
            backspaceColor: primary,
            dividerColor: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
            showBackspaceButton: true,
            recentTabBehavior: RecentTabBehavior.RECENT,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: panelBg,
            buttonColor: primary,
            buttonIconColor: Colors.white,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: panelBg,
            buttonIconColor: onSurface,
            hintText: 'Search emoji',
          ),
        ),
      ),
    );
  }
}
