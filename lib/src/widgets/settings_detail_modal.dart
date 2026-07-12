import 'package:flutter/material.dart';

import 'desktop_center_modal.dart';

/// Opens a settings sub-page in a centered desktop modal.
Future<void> showSettingsDetailModal(
  BuildContext context, {
  required String title,
  required Widget child,
  double maxWidth = 600,
  List<Widget>? headerActions,
}) {
  return showDesktopCenterModal<void>(
    context: context,
    title: title,
    maxWidth: maxWidth,
    maxHeightFraction: 0.88,
    headerActions: headerActions,
    child: child,
  );
}
