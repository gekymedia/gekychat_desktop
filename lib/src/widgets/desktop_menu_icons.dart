import 'package:flutter/material.dart';

/// Menu icons aligned with mobile / Telegram-style affordances.
abstract final class DesktopMenuIcons {
  /// Curved-neck forward arrow (flipped reply icon).
  static Widget forward(Color color, {double size = 20}) {
    return SizedBox(
      width: size,
      height: size,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: Icon(Icons.reply_rounded, size: size, color: color),
      ),
    );
  }
}
