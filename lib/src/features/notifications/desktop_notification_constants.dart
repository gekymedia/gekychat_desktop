import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Inline reply action id (Windows arguments / Android action id).
const String kDesktopReplyActionId = 'reply';

/// Windows text input id — reply text is returned in [NotificationResponse.data].
const String kDesktopReplyInputId = 'reply';

/// Windows toast actions return [NotificationResponse.actionId] / payload as the
/// action `arguments` string — not the toast `launch` payload. Embed thread id here.
String buildWindowsReplyArguments({
  int? conversationId,
  int? groupId,
}) {
  if (groupId != null && groupId > 0) return 'reply|g=$groupId';
  if (conversationId != null && conversationId > 0) return 'reply|c=$conversationId';
  return kDesktopReplyActionId;
}

bool isWindowsReplyActionId(String? actionId) =>
    actionId != null && actionId.startsWith('reply');

/// Parses `reply|c=89` / `reply|g=12` from Windows inline-reply action arguments.
Map<String, dynamic>? parseWindowsReplyRouting(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final match = RegExp(r'^reply\|([cg])=(\d+)$').firstMatch(trimmed);
  if (match == null) return null;
  final id = match.group(2);
  if (id == null) return null;
  if (match.group(1) == 'g') {
    return {'type': 'message', 'group_id': id};
  }
  return {'type': 'message', 'conversation_id': id};
}

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
  String? replyArguments,
}) {
  final args = replyArguments ?? kDesktopReplyActionId;
  return WindowsNotificationDetails(
    inputs: kDesktopMessageWindowsDetails.inputs,
    actions: <WindowsAction>[
      WindowsAction(
        content: 'Send',
        arguments: args,
        inputId: kDesktopReplyInputId,
      ),
    ],
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
