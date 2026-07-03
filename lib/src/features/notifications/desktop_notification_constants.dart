import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Inline reply action id (Windows arguments / Android action id).
const String kDesktopReplyActionId = 'reply';

/// Windows text input id — reply text is returned in [NotificationResponse.data].
const String kDesktopReplyInputId = 'reply';

const String kDesktopMessageCategoryId = 'MESSAGE_CATEGORY';

final DarwinNotificationCategory kDesktopMessageCategory =
    DarwinNotificationCategory(
  kDesktopMessageCategoryId,
  actions: <DarwinNotificationAction>[
    DarwinNotificationAction.text(
      kDesktopReplyActionId,
      'Reply',
      buttonTitle: 'Send',
      placeholder: 'Type a message…',
    ),
  ],
);

const AndroidNotificationAction kDesktopAndroidReplyAction =
    AndroidNotificationAction(
  kDesktopReplyActionId,
  'Reply',
  cancelNotification: false,
  showsUserInterface: false,
  inputs: <AndroidNotificationActionInput>[
    AndroidNotificationActionInput(label: 'Type a message…'),
  ],
);

const WindowsNotificationDetails kDesktopMessageWindowsDetails =
    WindowsNotificationDetails(
  inputs: <WindowsTextInput>[
    WindowsTextInput(
      id: kDesktopReplyInputId,
      placeHolderContent: 'Type a reply…',
    ),
  ],
  actions: <WindowsAction>[
    WindowsAction(
      content: 'Send',
      arguments: kDesktopReplyActionId,
      inputId: kDesktopReplyInputId,
    ),
  ],
);

/// Message toast with optional sender avatar (replaces default app icon on Windows).
WindowsNotificationDetails buildMessageWindowsDetails({
  List<WindowsImage> images = const [],
  String? subtitle,
}) {
  return WindowsNotificationDetails(
    inputs: kDesktopMessageWindowsDetails.inputs,
    actions: kDesktopMessageWindowsDetails.actions,
    images: images,
    subtitle: subtitle,
  );
}

DarwinNotificationDetails buildMessageDarwinDetails({
  String? subtitle,
  List<DarwinNotificationAttachment>? attachments,
}) {
  return DarwinNotificationDetails(
    categoryIdentifier: kDesktopMessageCategoryId,
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    presentBanner: true,
    presentList: true,
    subtitle: subtitle,
    attachments: attachments,
  );
}
