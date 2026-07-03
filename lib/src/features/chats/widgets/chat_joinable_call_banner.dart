import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calls/call_busy_helper.dart';
import '../../calls/joinable_call_message.dart';
import '../models.dart';
import 'ongoing_call_join_banner.dart';

/// Resolves the newest joinable call in [messages], verifies with the server, then shows the strip.
class ChatJoinableCallBanner extends ConsumerWidget {
  final List<Message> messages;
  final int? conversationId;
  final int? groupId;

  const ChatJoinableCallBanner({
    super.key,
    required this.messages,
    this.conversationId,
    this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userIsBusyInCall(ProviderScope.containerOf(context))) {
      return const SizedBox.shrink();
    }

    final container = ProviderScope.containerOf(context);
    final active = newestJoinableActiveCallMessage(
      messages,
      container: container,
      conversationId: conversationId,
      groupId: groupId,
    );
    if (active?.callData == null) {
      return const SizedBox.shrink();
    }

    final cd = active!.callData!;
    final link = cd['call_link'];
    if (link is! String || link.isEmpty) {
      return const SizedBox.shrink();
    }

    final sid = sessionIdFromCallData(cd);
    if (sid == null || sid <= 0) {
      return const SizedBox.shrink();
    }

    final isVideo = (cd['type'] as String?) == 'video';
    return VerifiedOngoingCallJoinBanner(
      key: ValueKey('join-banner-$sid'),
      sessionId: sid,
      callLink: link,
      callData: Map<String, dynamic>.from(cd),
      isVideo: isVideo,
    );
  }
}
