import 'package:flutter/material.dart';

/// Branded GekyChat AI mark for the icon rail and empty states.
class GekyChatAiIcon extends StatelessWidget {
  const GekyChatAiIcon({
    super.key,
    this.size = 24,
    this.onAccentBackground = false,
  });

  final double size;
  final bool onAccentBackground;

  @override
  Widget build(BuildContext context) {
    final logoAsset = onAccentBackground
        ? 'assets/icons/white_no_text/64x64.png'
        : 'assets/icons/gold_no_text/64x64.png';
    final sparkleColor =
        onAccentBackground ? Colors.white : const Color(0xFF008069);
    final sparkleSize = size * 0.38;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Image.asset(
            logoAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.auto_awesome,
                size: size,
                color: sparkleColor,
              );
            },
          ),
          Positioned(
            right: -sparkleSize * 0.15,
            top: -sparkleSize * 0.1,
            child: Icon(
              Icons.auto_awesome,
              size: sparkleSize,
              color: sparkleColor,
            ),
          ),
        ],
      ),
    );
  }
}
