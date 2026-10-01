import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gekychat_desktop/src/features/chats/widgets/chat_list_last_message_preview.dart';

void main() {
  Future<void> pumpPreview(
    WidgetTester tester, {
    required String text,
    bool fromMe = false,
    String? outgoingStatus,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatListLastMessagePreview(
            text: text,
            isDark: false,
            hasUnread: false,
            fromMe: fromMe,
            outgoingStatus: outgoingStatus,
          ),
        ),
      ),
    );
  }

  testWidgets('shows camera icon for photo preview', (tester) async {
    await pumpPreview(tester, text: '📷 Photo');
    expect(find.text('Photo'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.textContaining('📷'), findsNothing);
  });

  testWidgets('shows mic icon for voice message preview', (tester) async {
    await pumpPreview(tester, text: '🎤 Voice message');
    expect(find.text('Voice message'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
  });

  testWidgets('keeps ticks before media icon for outgoing', (tester) async {
    await pumpPreview(
      tester,
      text: '🎬 Video',
      fromMe: true,
      outgoingStatus: 'delivered',
    );
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
  });

  testWidgets('plain text has no media icon', (tester) async {
    await pumpPreview(tester, text: 'hello there');
    expect(find.text('hello there'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
  });
}
