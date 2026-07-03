import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lays out chat content with an optional right-hand info panel.
///
/// On wide panes the panel sits beside the chat. On narrow panes it overlays
/// the message area so bubbles are not squeezed.
///
/// [chat] should use a stable [GlobalKey] on the chat root so opening/closing
/// the panel (or resizing across overlay vs side-by-side) does not corrupt the
/// element tree.
class ChatSidePanelLayout extends StatelessWidget {
  static const double panelWidth = 360;
  static const double minChatWidth = 480;

  final Widget chat;
  final Widget? sidePanel;
  final bool showSidePanel;
  final VoidCallback? onDismissPanel;

  const ChatSidePanelLayout({
    super.key,
    required this.chat,
    this.sidePanel,
    this.showSidePanel = false,
    this.onDismissPanel,
  });

  bool _useOverlay(double maxWidth) =>
      maxWidth < panelWidth + minChatWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panel = sidePanel;
        final show = showSidePanel && panel != null;

        // Always host chat in a Stack so the parent type never flips between
        // bare widget / Stack / Row (which reparents the message list).
        if (!show) {
          return Stack(
            fit: StackFit.expand,
            children: [Positioned.fill(child: chat)],
          );
        }

        if (!_useOverlay(constraints.maxWidth)) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: chat),
                    SizedBox(width: panelWidth, child: panel),
                  ],
                ),
              ),
            ],
          );
        }

        final width = math.min(panelWidth, constraints.maxWidth * 0.92);
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: chat),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismissPanel,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: width,
              child: Material(
                elevation: 8,
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }
}
