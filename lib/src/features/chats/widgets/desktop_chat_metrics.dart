// Layout metrics for the desktop chat pane (aligned with WhatsApp Web).
import 'package:flutter/material.dart';

abstract final class DesktopChatMetrics {
  /// Max bubble width as a fraction of the chat pane (WhatsApp ≈ 65%).
  static const double bubbleWidthFraction = 0.65;

  /// Hard cap so bubbles stay readable on very wide panes.
  static const double bubbleMaxWidthCap = 480;

  static const double bubbleMinWidth = 200;

  static double bubbleMaxWidth(double availableWidth) {
    return (availableWidth * bubbleWidthFraction)
        .clamp(bubbleMinWidth, bubbleMaxWidthCap);
  }

  /// Message list inset — tighter than generic 16px padding.
  static const messageListPadding =
      EdgeInsets.fromLTRB(12, 8, 12, 12);

  /// Vertical gap between messages in the same cluster (same sender, <10 min).
  static const double messageClusterGap = 1.0;

  /// Vertical gap when a new message block starts (sender change or long pause).
  static const double messageBlockGap = 6.0;
}
