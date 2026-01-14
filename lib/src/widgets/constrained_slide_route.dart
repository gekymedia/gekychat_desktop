import 'package:flutter/material.dart';

/// Custom route that slides in from the right but only covers the conversation area
/// (not the sidebar and menu bar)
class ConstrainedSlideRightRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final double leftOffset; // Offset from left to account for sidebar

  ConstrainedSlideRightRoute({
    required this.page,
    this.leftOffset = 400.0, // Default sidebar width + side nav
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.ease;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return Stack(
              children: [
                // Background overlay
                Positioned.fill(
                  left: leftOffset,
                  child: Container(
                    color: Colors.black.withOpacity(0.3 * animation.value),
                  ),
                ),
                // Sliding page
                Positioned.fill(
                  left: leftOffset,
                  child: SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  ),
                ),
              ],
            );
          },
          opaque: false,
          fullscreenDialog: false,
        );
}
