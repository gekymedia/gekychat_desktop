import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/download_path_service.dart';
import '../../../utils/view_once_desktop_policy.dart';
import '../models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/colored_avatar.dart';
import 'message_info_dialog.dart';
import '../../../core/providers.dart';
import '../../../utils/display_text.dart';
import '../../../utils/phone_matcher.dart';
import '../../../utils/text_formatting.dart';
import '../../contacts/contacts_repository.dart';
import '../../contacts/contact_display_service.dart';
import '../chat_providers.dart';
import '../../../utils/gekychat_chat_link_parser.dart';
import '../../../utils/world_feed_link_navigation.dart';
import '../../calls/join_call_from_link.dart';
import '../../calls/joinable_call_message.dart';
import 'poll_message_widget.dart';
import '../../calls/call_duration_format.dart';
import 'media_gallery_viewer.dart';

/// WhatsApp-style bubble text (aligned with mobile [enhanced_message_bubble]).
const Color _kWaSentTextLight = Color(0xFF111B21);
const Color _kWaSentTextDark = Color(0xFFE9EDEF);
const Color _kWaIncomingTextLight = Color(0xFF111B21);
const Color _kWaIncomingTextDark = Color(0xFFE9EDEF);
const Color _kWaMutedLight = Color(0xFF667781);
const Color _kWaMutedDark = Color(0xFF8696A0);
const Color _kWaReadReceiptBlue = Color(0xFF53BDEB);

const List<Color> _senderNameColors = [
  Color(0xFF1E88E5),
  Color(0xFFE91E63),
  Color(0xFF9C27B0),
  Color(0xFF00ACC1),
  Color(0xFF43A047),
  Color(0xFFFF9800),
  Color(0xFF795548),
  Color(0xFF607D8B),
  Color(0xFFF44336),
  Color(0xFF3F51B5),
];

Color _colorForSender({required int senderId, Map<String, dynamic>? sender}) {
  var index = senderId.abs();
  if (index == 0 && sender != null) {
    final name =
        sender['name']?.toString() ?? sender['phone']?.toString() ?? '';
    index = name.hashCode.abs();
  }
  return _senderNameColors[index % _senderNameColors.length];
}

/// Shrink-wrap bubble chrome (reply strip, short text) without forcing max width.
Widget _bubbleShrinkWrapChild(Widget child) {
  return Align(
    alignment: Alignment.centerLeft,
    child: child,
  );
}

Color _bubbleTextColor(bool isMe, bool isDark) {
  if (isMe) {
    return isDark ? _kWaSentTextDark : _kWaSentTextLight;
  }
  return isDark ? _kWaIncomingTextDark : _kWaIncomingTextLight;
}

Color _bubbleMutedColor(bool isMe, bool isDark) {
  if (isMe) {
    return isDark
        ? _kWaSentTextDark.withValues(alpha: 0.65)
        : _kWaMutedLight;
  }
  return isDark ? _kWaMutedDark : _kWaMutedLight;
}

class MessageBubble extends ConsumerWidget {
  final Message message;
  final int currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final Function(String)? onReact;
  final VoidCallback? onReplyPrivately;
  final Function(String)? onEdit;
  final bool isGroupMessage;
  final bool isChannel; // Whether this is a channel message
  final String? channelName; // Channel name (to use instead of admin name)
  final bool? senderIsAdmin; // Whether sender is admin (for channels)
  final VoidCallback? onReferencedStatusTap;
  final VoidCallback? onReferencedGroupTap;
  final List<Message>? allMessages;
  final String? dmContactName;
  final ValueChanged<int>? onReplyPreviewTap;
  final Future<void> Function(Message message)? onViewOnceOpened;
  final void Function(Message message)? onReplyToMessage;
  final Future<void> Function(Message message)? onForwardToMessage;
  final Future<void> Function(Message message)? onDeleteMessage;
  /// Map of sender user ID → contact-book display name for group senders.
  final Map<int, String>? contactNames;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.onDelete,
    this.onReply,
    this.onForward,
    this.onReact,
    this.onReplyPrivately,
    this.onEdit,
    this.isGroupMessage = false,
    this.isChannel = false,
    this.channelName,
    this.senderIsAdmin,
    this.onReferencedStatusTap,
    this.onReferencedGroupTap,
    this.allMessages,
    this.dmContactName,
    this.onReplyPreviewTap,
    this.onViewOnceOpened,
    this.onReplyToMessage,
    this.onForwardToMessage,
    this.onDeleteMessage,
    this.contactNames,
  });

  bool isMe(int currentUserId) => message.senderId == currentUserId;

  /// Resolve the display name for a group message sender.
  /// Prefers the contact-book name from [contactNames] over the raw API name.
  String _resolveSenderName(
    Map<String, dynamic>? sender,
    int? senderId,
    WidgetRef ref,
  ) {
    final apiName = sender?['name'] as String? ??
        sender?['phone'] as String? ??
        'Unknown';
    if (senderId != null) {
      final cached = contactNames?[senderId];
      if (cached != null && cached.isNotEmpty) return cached;
      final service = ref.read(contactDisplayServiceProvider);
      if (service.isLoaded) {
        return service.resolve(
          userId: senderId,
          phone: sender?['phone'] as String?,
          apiName: apiName,
        );
      }
    }
    return apiName;
  }
  bool _messageHasReferencedStatus(Message m) =>
      m.referencedStatusId != null ||
      (m.referencedStatus != null && m.referencedStatus!.isNotEmpty);

  bool _messageHasReferencedGroup(Message m) =>
      (m.referencedGroupId != null && m.referencedGroupMessageId != null) ||
      (m.referencedGroup != null && m.referencedGroup!.isNotEmpty);

  Widget _buildReferencedGroupStrip(
      BuildContext context, bool isDark, bool isMeValue) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = isMeValue
        ? scheme.onPrimary.withOpacity(0.5)
        : scheme.primary;
    final snap = message.referencedGroup;
    final groupName = snap?['group_name']?.toString().trim();
    final preview = snap?['body_preview']?.toString().trim();
    final title =
        groupName != null && groupName.isNotEmpty ? groupName : 'Group message';
    final subtitle =
        preview != null && preview.isNotEmpty ? preview : 'Tap to view in group';

    final content = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.groups_rounded, size: 22, color: borderColor.withOpacity(0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: borderColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onReferencedGroupTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReferencedGroupTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }

  Widget _buildReferencedStatusStrip(
      BuildContext context, bool isDark, bool isMeValue) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = isMeValue
        ? scheme.onPrimary.withOpacity(0.5)
        : scheme.primary;
    final snap = message.referencedStatus;

    var expired = false;
    var title = 'Status';
    var subtitle = 'Tap to open';
    String? thumbUrl;

    if (snap != null && snap.isNotEmpty) {
      expired = snap['expired'] == true;
      final type = snap['type']?.toString() ?? '';
      switch (type) {
        case 'text':
          title = 'Text status';
          final tx = snap['text']?.toString().trim() ?? '';
          subtitle = expired
              ? 'No longer available'
              : (tx.isNotEmpty ? tx : 'Tap to open');
          break;
        case 'image':
          title = 'Photo';
          subtitle = expired ? 'No longer available' : 'Tap to open';
          thumbUrl = snap['thumbnail_url']?.toString();
          break;
        case 'video':
          title = 'Video';
          subtitle = expired ? 'No longer available' : 'Tap to open';
          thumbUrl = snap['thumbnail_url']?.toString();
          break;
        case 'audio':
          title = 'Audio';
          subtitle = expired ? 'No longer available' : 'Tap to open';
          break;
        default:
          subtitle = expired ? 'No longer available' : 'Tap to open';
      }
    } else if (message.referencedStatusId != null) {
      subtitle = 'Tap to open';
    }

    final content = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (thumbUrl != null &&
              thumbUrl.isNotEmpty &&
              !expired)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: thumbUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.image_outlined,
                  size: 28,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                expired
                    ? Icons.hourglass_disabled_outlined
                    : Icons.auto_stories_outlined,
                size: 26,
                color: borderColor.withOpacity(0.9),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: borderColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onReferencedStatusTap == null || expired) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReferencedStatusTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }

  String _getStatusTooltip(Message message) {
    if (message.readAt != null) {
      final readTime = DateFormat('MMM d, h:mm a').format(message.readAt!);
      return 'Read at $readTime';
    } else if (message.deliveredAt != null) {
      final deliveredTime = DateFormat('MMM d, h:mm a').format(message.deliveredAt!);
      return 'Delivered at $deliveredTime';
    } else {
      return 'Sent at ${DateFormat('MMM d, h:mm a').format(message.createdAt)}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMeValue = isMe(currentUserId);
    final gkLink = parseFirstGekychatSpecialLink(message.body);
    final isWorldFeedBubble = gkLink?.kind == GekychatChatLinkKind.worldFeed;
    final worldLinkPreview =
        isWorldFeedBubble && gkLink != null ? _worldFeedLinkPreview(gkLink) : null;

    // System messages are centered
    if (message.isSystem) {
      return _buildSystemMessage(context, isDark);
    }

    return Align(
      alignment: isMeValue ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final bubbleMaxWidth =
              (availableWidth * 0.78).clamp(200.0, 520.0);
          return GestureDetector(
        onLongPress: () => _showMessageMenu(context, context, isMeValue),
        onSecondaryTapDown: (details) => _showMessageMenuAtPosition(context, details.globalPosition, isMeValue),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isMeValue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (_messageHasReferencedStatus(message))
                _buildReferencedStatusStrip(context, isDark, isMeValue),
              if (_messageHasReferencedGroup(message))
                _buildReferencedGroupStrip(context, isDark, isMeValue),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMeValue
                      ? (isDark ? AppTheme.outgoingBubbleDark : AppTheme.outgoingBubbleLight)
                      : (isDark ? AppTheme.incomingBubbleDark : AppTheme.incomingBubbleLight),
                  border: isWorldFeedBubble
                      ? Border.all(
                          color: isMeValue
                              ? AppTheme.primaryGreen.withValues(alpha: 0.55)
                              : AppTheme.primaryGreen.withValues(alpha: 0.85),
                          width: 1.5,
                        )
                      : null,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isMeValue ? 12 : 2),
                    bottomRight: Radius.circular(isMeValue ? 2 : 12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Group sender above reply preview (WhatsApp order).
                    if (!isMeValue && isGroupMessage && message.sender != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isChannel && senderIsAdmin == true && channelName != null)
                              ColoredAvatar(
                                name: channelName!,
                                radius: 12,
                              )
                            else
                              ColoredAvatar(
                                imageUrl: message.sender!['avatar_url'] as String? ?? message.sender!['avatar_path'] as String?,
                                name: message.sender!['name'] as String? ?? message.sender!['phone'] as String? ?? 'Unknown',
                                radius: 12,
                              ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                (isChannel && senderIsAdmin == true && channelName != null)
                                    ? channelName!
                                    : _resolveSenderName(
                                        message.sender,
                                        message.senderId,
                                        ref,
                                      ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: (isChannel && senderIsAdmin == true && channelName != null)
                                      ? (isDark ? _kWaMutedDark : _kWaMutedLight)
                                      : _colorForSender(
                                          senderId: message.senderId,
                                          sender: message.sender,
                                        ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (message.replyToId != null)
                      _buildReplyPreview(context, isDark, isMeValue),
                    // Attachments
                    // IMPORTANT: Check isAudio FIRST (before isVideo) because audio files
                    // can have .mp4 extension but are still audio (server sets isAudio flag based on MIME type)
                    if (message.attachments.isNotEmpty)
                      _ViewOnceAttachmentsSection(
                        message: message,
                        isMe: isMeValue,
                        isDark: isDark,
                        ref: ref,
                        context: context,
                        onViewOnceOpened: onViewOnceOpened,
                        openMediaGallery: (items, index, {isViewOnce = false}) =>
                            _openMediaGallery(context, items, index, isViewOnce: isViewOnce),
                        buildImage: (a) => _buildImageAttachment(context, a, isMeValue),
                        buildVideo: (a) => _buildVideoAttachment(context, a, isMeValue),
                        buildAudio: (a) => _buildAudioAttachment(a, isDark, ref, context),
                        buildDocument: (a) => _buildDocumentAttachment(a, isDark, ref, context),
                      ),

                    // Location Data
                    if (message.locationData != null)
                      _buildLocationCard(message.locationData!, isDark),

                    // Contact Data
                    if (message.contactData != null)
                      _buildContactCard(message.contactData!, isDark),

                    // Sika transfer card
                    if (message.sikaTransferData != null)
                      _buildSikaTransferCard(message.sikaTransferData!, isDark, isMeValue),

                    // Poll
                    if (message.messageType == 'poll')
                      _buildPollCard(message, isDark, ref),

                    // Call Data
                    if (message.callData != null)
                      _buildCallCard(message.callData!, isDark, isMeValue),

                    if (isWorldFeedBubble &&
                        !message.isDeleted &&
                        gkLink != null) ...[
                      _buildWorldFeedLinkHeader(isDark, isMeValue),
                      if (worldLinkPreview != null)
                        _buildLinkPreview(
                          context,
                          ref,
                          worldLinkPreview,
                          isDark,
                        )
                      else
                        _buildWorldFeedPreviewCard(context, ref, isDark, gkLink),
                    ],

                    // Link previews (skip for World when dedicated preview/card above)
                    if (!isWorldFeedBubble &&
                        message.linkPreviews != null &&
                        message.linkPreviews!.isNotEmpty)
                      ...message.linkPreviews!.map((preview) => _buildLinkPreview(context, ref, preview, isDark)),

                    // Deleted message indicator (WhatsApp style)
                    if (message.isDeleted)
                      Padding(
                        padding: EdgeInsets.only(
                          top: message.attachments.isNotEmpty || 
                               message.locationData != null || 
                               message.contactData != null ||
                               message.messageType == 'poll' ||
                               message.callData != null ||
                               (message.linkPreviews != null && message.linkPreviews!.isNotEmpty) ||
                               isWorldFeedBubble ? 8 : 0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: (isMeValue
                                  ? Colors.white.withOpacity(0.6)
                                  : (isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'This message was deleted',
                              style: TextStyle(
                                color: isMeValue
                                    ? Colors.white.withOpacity(0.6)
                                    : (isDark
                                        ? AppTheme.textSecondaryDark
                                        : AppTheme.textSecondaryLight),
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      )
                    // Message body
                    else if (_shouldShowMessageBody(isWorldFeedBubble))
                      Padding(
                        padding: EdgeInsets.only(
                          top: message.attachments.isNotEmpty || 
                               message.locationData != null || 
                               message.contactData != null ||
                               message.messageType == 'poll' ||
                               message.callData != null ||
                               (message.linkPreviews != null && message.linkPreviews!.isNotEmpty) ||
                               isWorldFeedBubble ? 8 : 0,
                        ),
                        child: _buildMessageText(context, ref, isDark, isMeValue),
                      ),

                    // Timestamp + Edited label + status tick
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.editedAt != null) ...[
                            Text(
                              'Edited',
                              style: TextStyle(
                                color: _bubbleMutedColor(isMeValue, isDark),
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            DateFormat.jm().format(message.createdAt),
                            style: TextStyle(
                              color: _bubbleMutedColor(isMeValue, isDark),
                              fontSize: 11,
                            ),
                          ),
                          if (isMeValue) ...[
                            const SizedBox(width: 4),
                            Tooltip(
                              message: _getStatusTooltip(message),
                              child: Builder(builder: (context) {
                                final st = message.status;
                                final tickMuted = _bubbleMutedColor(true, isDark);
                                if (st == 'queued' || st == 'sending') {
                                  return Icon(Icons.schedule, size: 14,
                                      color: tickMuted);
                                } else if (st == 'failed') {
                                  return const Icon(Icons.error_outline, size: 14,
                                      color: Colors.redAccent);
                                } else if (message.readAt != null || st == 'read') {
                                  return const Icon(Icons.done_all, size: 14,
                                      color: _kWaReadReceiptBlue);
                                } else if (message.deliveredAt != null || st == 'delivered') {
                                  return Icon(Icons.done_all, size: 14,
                                      color: tickMuted);
                                } else {
                                  return Icon(Icons.done, size: 14,
                                      color: tickMuted);
                                }
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Reactions
              if (message.reactions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: isMeValue ? 45 : 12,
                    right: isMeValue ? 12 : 45,
                  ),
                  child: Wrap(
                    spacing: 4,
                    children: message.reactions.map((reaction) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          reaction.emoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        ),
          );
        },
      ),
    );
  }

  List<GalleryMediaItem> _getGalleryMediaItems() {
    if (allMessages == null) return [];

    final items = <GalleryMediaItem>[];
    for (final msg in allMessages!) {
      if (msg.isViewOnce) continue;
      for (final attachment in msg.attachments) {
        if (attachment.isImage || attachment.isVideo) {
          items.add(
            GalleryMediaItem(
              attachment: attachment,
              message: msg,
              isSent: msg.senderId == currentUserId,
            ),
          );
        }
      }
    }
    return items;
  }

  void _openMediaGallery(
    BuildContext context,
    List<GalleryMediaItem> items,
    int initialIndex, {
    bool isViewOnce = false,
  }) {
    if (items.isEmpty) return;
    if (isViewOnce) {
      showViewOnceUnavailableOnDesktop(context);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGalleryViewer(
          items: items,
          initialIndex: initialIndex.clamp(0, items.length - 1),
          isViewOnce: isViewOnce,
          onReply: onReplyToMessage ??
              (onReply != null
                  ? (msg) {
                      if (msg.id == message.id) onReply!();
                    }
                  : null),
          onForward: onForwardToMessage ??
              (onForward != null
                  ? (msg) async {
                      if (msg.id == message.id) onForward!();
                    }
                  : null),
          onDelete: onDeleteMessage ??
              (onDelete != null
                  ? (msg) async {
                      if (msg.id == message.id) onDelete!();
                    }
                  : null),
        ),
      ),
    );
  }

  void _openAttachmentInGallery(
    BuildContext context,
    MessageAttachment attachment,
    bool isSent, {
    bool isViewOnce = false,
  }) {
    if (isViewOnce) {
      showViewOnceUnavailableOnDesktop(context);
      return;
    }

    final items = _getGalleryMediaItems();
    if (items.isEmpty) {
      _openMediaGallery(
        context,
        [
          GalleryMediaItem(
            attachment: attachment,
            message: message,
            isSent: isSent,
          ),
        ],
        0,
      );
      return;
    }

    final index = items.indexWhere((item) => item.attachment.id == attachment.id);
    _openMediaGallery(context, items, index >= 0 ? index : 0);
  }

  Widget _buildImageAttachment(
    BuildContext context,
    MessageAttachment attachment,
    bool isSent,
  ) {
    return GestureDetector(
      onTap: () => _openAttachmentInGallery(context, attachment, isSent),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 300),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: attachment.displayUrl, // MEDIA COMPRESSION: Use compressed URL if available
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 200,
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 48),
              ),
            ),
            // MEDIA COMPRESSION: Show compression indicator overlay
            // Only show "Sending..." if message status is actually "sending" or "queued"
            // Don't show it just because compression is pending (compression can happen in background)
            if (attachment.isCompressing && (message.status == 'sending' || message.status == 'queued'))
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'Sending...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildVideoAttachment(
    BuildContext context,
    MessageAttachment attachment,
    bool isSent,
  ) {
    // MEDIA COMPRESSION: Use thumbnail if available, otherwise use video URL
    final thumbnailUrl = attachment.thumbnailUrl;
    final isCompressing = attachment.isCompressing;
    
    return GestureDetector(
      onTap: () => _openAttachmentInGallery(context, attachment, isSent),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          // MEDIA COMPRESSION: Show compression indicator
          // Only show "Sending..." if message status is actually "sending" or "queued"
          // Don't show it just because compression is pending (compression can happen in background)
          if (isCompressing && (message.status == 'sending' || message.status == 'queued'))
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    'Sending...',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(16),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildDocumentAttachment(
    MessageAttachment attachment,
    bool isDark,
    WidgetRef ref,
    BuildContext context,
  ) {
    return _DocumentAttachmentTile(
      attachment: attachment,
      isDark: isDark,
    );
  }

  Widget _buildAudioAttachment(MessageAttachment attachment, bool isDark, WidgetRef ref, BuildContext context) {
    return VoiceMessagePlayer(
      attachment: attachment,
      isDark: isDark,
    );
  }

  void _showMessageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MessageInfoDialog(
        messageId: message.id,
        isGroupMessage: isGroupMessage,
        currentUserId: currentUserId,
      ),
    );
  }

  void _showMessageMenuAtPosition(BuildContext context, Offset position, bool isMeValue) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    _showMessageMenu(context, context, isMeValue, position: overlay.globalToLocal(position));
  }

  void _showMessageMenu(BuildContext context, BuildContext widgetContext, bool isMeValue, {Offset? position}) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use provided position or center of screen
    final menuPosition = position ?? Offset(screenSize.width / 2, screenSize.height / 2);
    final menuSize = const Size(200, 300); // Approximate menu size
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        menuPosition.dx,
        menuPosition.dy,
        screenSize.width - menuPosition.dx - menuSize.width,
        screenSize.height - menuPosition.dy - menuSize.height,
      ),
      color: isDark ? const Color(0xFF2A3942) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.reply, size: 20, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reply',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              onReply?.call();
            });
          },
        ),
        // Message Info (for sent messages in groups)
        if (isGroupMessage && isMeValue) ...<PopupMenuEntry<dynamic>>[
          const PopupMenuDivider(),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Message Info',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
            onTap: () {
              Future.delayed(Duration.zero, () {
                _showMessageInfo(widgetContext);
              });
            },
          ),
        ],
        if (isGroupMessage && !isMeValue) ...<PopupMenuEntry<dynamic>>[
          const PopupMenuDivider(),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reply Privately',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
            onTap: () {
              Future.delayed(Duration.zero, () {
                onReplyPrivately?.call();
              });
            },
          ),
        ],
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.add_reaction_outlined, size: 20, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'React',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (widgetContext.mounted) {
                _showReactionPicker(widgetContext);
              }
            });
          },
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.copy, size: 20, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Copy',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () async {
              await Clipboard.setData(ClipboardData(text: message.body));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.forward, size: 20, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Forward',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              onForward?.call();
            });
          },
        ),
        if (isMeValue) ...<PopupMenuEntry<dynamic>>[
          const PopupMenuDivider(),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Edit',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (widgetContext.mounted && onEdit != null) {
                  _showEditDialog(widgetContext);
                }
              });
            },
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              onDelete?.call();
            });
          },
        ),
      ],
    );
  }

  bool _shouldShowMessageBody(bool isWorldFeedBubble) {
    if (message.isDeleted || _isSpecialMessage(message)) return false;
    final resolved = _resolvedBodyText();
    if (resolved.isEmpty) return false;
    return true;
  }

  Map<String, dynamic>? _worldFeedLinkPreview(GekychatChatLinkMatch match) {
    final previews = message.linkPreviews;
    if (previews == null || previews.isEmpty) return null;
    for (final raw in previews) {
      if (raw is! Map) continue;
      final preview = Map<String, dynamic>.from(raw);
      final url = preview['url']?.toString() ?? '';
      if (url == match.matchedUrl ||
          looksLikeGekychatWorldFeedNavigationUrl(url)) {
        return preview;
      }
    }
    final first = previews.first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return null;
  }

  String _resolvedBodyText() {
    var text = message.body;
    final special = parseFirstGekychatSpecialLink(text);
    if (special != null && special.kind == GekychatChatLinkKind.worldFeed) {
      final cleaned = text.replaceAll(special.matchedUrl, '').trim();
      if (cleaned.isNotEmpty) return cleaned;
      return special.matchedUrl;
    }
    if (special != null &&
        (special.kind == GekychatChatLinkKind.groupJoin ||
            special.kind == GekychatChatLinkKind.groupOpen ||
            special.kind == GekychatChatLinkKind.channel)) {
      final cleaned = text.replaceAll(special.matchedUrl, '').trim();
      if (cleaned.isNotEmpty) return cleaned;
      return switch (special.kind) {
        GekychatChatLinkKind.channel => 'Shared a GekyChat channel',
        _ => 'Shared a GekyChat group invite',
      };
    }
    return text;
  }

  Widget _buildWorldFeedLinkHeader(bool isDark, bool isMeValue) {
    final accent = isMeValue
        ? (isDark ? Colors.white : const Color(0xFF065F46))
        : AppTheme.primaryGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.movie_filter_rounded, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            'GekyChat World',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorldFeedPreviewCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    GekychatChatLinkMatch match,
  ) {
    final thumbBg = isDark ? const Color(0xFF0F1418) : const Color(0xFFE7EEF2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => tryOpenWorldFeedUrlInApp(ref, context, match.matchedUrl),
          child: Ink(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryGreen.withValues(alpha: 0.22),
                  thumbBg,
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Watch on GekyChat World',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Tap to open feed',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSpecialMessage(Message message) {
    if (message.messageType == 'poll') return true;
    if (message.callData != null) return true;
    // Check if message body is just a placeholder for special content
    final body = message.body.toLowerCase().trim();
    return body == '👤 shared contact' || 
           body == '📍 shared location' || 
           body.contains('shared contact') ||
           body.contains('shared location');
  }

  Widget _buildPollCard(Message message, bool isDark, WidgetRef ref) {
    if (message.id <= 0) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message.body.isNotEmpty ? sanitizeDisplayText(message.body) : 'Poll',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }
    return PollMessageWidget(
      messageId: message.id,
      isGroupPoll: isGroupMessage,
      isDark: isDark,
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> locationData, bool isDark) {
    final latitude = locationData['latitude'] as num?;
    final longitude = locationData['longitude'] as num?;
    final address = locationData['address'] as String?;
    final placeName = locationData['place_name'] as String?;

    if (latitude == null || longitude == null) return const SizedBox.shrink();

    final mapUrl = 'https://www.google.com/maps?q=$latitude,$longitude';

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(mapUrl);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Could not launch $mapUrl: $e');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3942) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF3A4A52) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Center(
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (placeName != null)
                    Text(
                      placeName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  if (address != null && address != placeName) ...[
                    if (placeName != null) const SizedBox(height: 4),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.map,
                        size: 16,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View on Google Maps',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinCallFromLink(BuildContext context, WidgetRef ref, String callLink, Map<String, dynamic> callData) async {
    await joinCallFromChatLink(
      context,
      callLink,
      Map<String, dynamic>.from(callData),
    );
  }

  Widget _buildSikaTransferCard(
      Map<String, dynamic> data, bool isDark, bool isMe) {
    final isGift = data['type'] == 'gift';
    final coins = data['amount'] ?? data['coins'] ?? 0;
    final note = data['note'] as String?;
    final recipientName = data['recipient_name'] as String?;
    final senderName = data['sender_name'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A3942)
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.amber.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isGift ? Icons.card_giftcard : Icons.monetization_on,
                  color: Colors.amber.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                isGift ? 'Sika Gift' : 'Sika Transfer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$coins Coins',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
          if (recipientName != null || senderName != null) ...[
            const SizedBox(height: 4),
            Text(
              isMe
                  ? (recipientName != null ? 'To: $recipientName' : '')
                  : (senderName != null ? 'From: $senderName' : ''),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallCard(Map<String, dynamic> callData, bool isDark, bool isMe) {
    final callType = callData['type'] as String? ?? 'voice';
    final callStatus = callData['status'] as String? ?? 'ended';
    final callLink = callData['call_link'] as String?;
    final duration = callDurationSecondsFromData(callData);
    final isMissed = callData['missed'] as bool? ?? false;
    final isActive = callStatus == 'calling' || callStatus == 'ongoing';

    final callIcon = callType == 'video' ? Icons.videocam : Icons.call;
    final callTypeText = callType == 'video' ? 'Video call' : 'Voice call';
    
    String title;
    if (isMissed) {
      title = 'Missed $callTypeText';
    } else if (isActive) {
      title = '$callTypeText - Join now';
    } else {
      title = callTypeText;
    }

    String durationText = '';
    if (duration != null && duration > 0) {
      durationText = formatCallDurationLabel(duration);
    }

    IconData statusIcon;
    Color statusColor;
    if (isMissed) {
      statusIcon = Icons.call_missed;
      statusColor = Colors.red;
    } else if (isActive) {
      statusIcon = Icons.call;
      statusColor = Colors.green;
    } else if (isMe) {
      statusIcon = Icons.call_made;
      statusColor = AppTheme.primaryGreen;
    } else {
      statusIcon = Icons.call_received;
      statusColor = Colors.green;
    }

    return Consumer(
      builder: (context, ref, child) => GestureDetector(
        onTap: callLink != null && isActive
            ? () => _joinCallFromLink(context, ref, callLink, callData)
            : null,
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3942) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF3A4A52) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              callIcon,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  if (durationText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      durationText,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ] else if (!isActive) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('H:mm').format(message.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                  if (isActive && callLink != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.call, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Join Call',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contactData, bool isDark) {
    final displayName = contactData['display_name'] as String? ?? 'Contact';
    final phone = contactData['phone'] as String?;
    final email = contactData['email'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A3942) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF3A4A52) : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (phone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
                if (email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkPreview(
    BuildContext context,
    WidgetRef ref,
    dynamic previewData,
    bool isDark,
  ) {
    if (previewData is! Map) return const SizedBox.shrink();
    
    final preview = Map<String, dynamic>.from(previewData);
    final title = preview['title'] as String?;
    final description = preview['description'] as String?;
    final url = preview['url'] as String?;
    final image = preview['image'] as String?;
    final siteName = preview['site_name'] as String?;

    if (url == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        if (tryOpenWorldFeedUrlInApp(ref, context, url)) return;
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          debugPrint('Could not launch $url');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3942) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF3A4A52) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: CachedNetworkImage(
                  imageUrl: image,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (siteName != null)
                    Text(
                      siteName,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (title != null) ...[
                    if (siteName != null) const SizedBox(height: 4),
                    Text(
                      title.length > 70 ? '${title.substring(0, 70)}...' : title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (description != null) ...[
                    if (title != null) const SizedBox(height: 4),
                    Text(
                      description.length > 120 ? '${description.substring(0, 120)}...' : description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    Uri.parse(url).host,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        contentPadding: const EdgeInsets.all(16),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    onReact?.call(emoji);
                  },
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              }),
              // More reactions button (emoji picker)
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showCustomEmojiPicker(context);
                },
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.add_circle_outline, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomEmojiPicker(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emojis = [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
      '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
      '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩',
      '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
      '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬',
      '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗',
      '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯',
      '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐',
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉',
      '👆', '👇', '☝️', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️',
    ];

    final emoji = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          'Choose Emoji',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () => Navigator.pop(context, emojis[index]),
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
          ),
        ],
      ),
    );

    if (emoji != null && emoji.isNotEmpty) {
      onReact?.call(emoji);
    }
  }

  void _showEditDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: message.body);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Enter message',
            hintStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primaryGreen),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newBody = controller.text.trim();
              if (newBody.isNotEmpty && onEdit != null) {
                onEdit!(newBody);
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryGreen,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (isDark ? Colors.grey[800] : Colors.grey[200])?.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            sanitizeDisplayText(message.body),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(
    BuildContext context,
    bool isDark,
    bool isMeValue,
  ) {
    final preview = message.replyToPreview;
    Message? original;
    if (message.replyToId != null && allMessages != null) {
      for (final m in allMessages!) {
        if (m.id == message.replyToId) {
          original = m;
          break;
        }
      }
    }

    String replyText = preview?['body_preview']?.toString() ?? '';
    if (replyText.isEmpty && original != null) {
      if (original.body.isNotEmpty) {
        replyText = original.body;
      } else if (original.attachments.isNotEmpty) {
        final a = original.attachments.first;
        if (a.isImage) {
          replyText = '📷 Photo';
        } else if (a.isVideo) {
          replyText = '🎥 Video';
        } else if (a.isAudio) {
          replyText = '🎤 Audio';
        } else {
          replyText = '📎 Attachment';
        }
      } else if (original.callData != null ||
          original.messageType == 'call' ||
          original.messageType == 'video_call') {
        final isVideo = original.callData?['type'] == 'video' ||
            original.messageType == 'video_call';
        replyText = '📞 ${isVideo ? 'Video' : 'Voice'} call';
      } else {
        replyText = 'Message';
      }
    }
    if (replyText.isEmpty) {
      replyText = 'Original message';
    }

    String? senderLabel;
    final previewSenderId = preview?['sender_id'];
    final originalSenderId = original?.senderId;
    final quotedSenderId = previewSenderId is int
        ? previewSenderId
        : int.tryParse(previewSenderId?.toString() ?? '') ??
            originalSenderId;

    if (isGroupMessage) {
      if (original?.sender != null) {
        final rawName = original!.sender!['name'] as String? ??
            original.sender!['phone'] as String?;
        final senderId = original.senderId;
        final contactName = contactNames?[senderId];
        senderLabel = (contactName != null && contactName.isNotEmpty)
            ? contactName
            : rawName;
      }
    } else if (quotedSenderId != null) {
      final rawName = original?.sender?['name'] as String? ?? dmContactName ?? 'Contact';
      if (quotedSenderId == currentUserId) {
        senderLabel = 'You';
      } else {
        final contactName = contactNames?[quotedSenderId];
        senderLabel = (contactName != null && contactName.isNotEmpty) ? contactName : rawName;
      }
    }
    senderLabel ??= isGroupMessage ? 'Unknown' : 'Reply';

    final accent = isMeValue
        ? AppTheme.primaryGreen
        : (quotedSenderId == currentUserId
            ? AppTheme.primaryGreen
            : (original?.senderId != null
                ? _colorForSender(
                    senderId: original!.senderId,
                    sender: original.sender,
                  )
                : AppTheme.primaryGreen));
    final stripBg = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.05);

    final strip = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: stripBg,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            replyText,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? _kWaIncomingTextDark.withValues(alpha: 0.85)
                  : _kWaIncomingTextLight.withValues(alpha: 0.78),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    final wrappedStrip = _bubbleShrinkWrapChild(strip);

    final replyToId = message.replyToId;
    if (replyToId != null && onReplyPreviewTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onReplyPreviewTap!(replyToId),
          borderRadius: BorderRadius.circular(6),
          child: wrappedStrip,
        ),
      );
    }
    return wrappedStrip;
  }

  Widget _buildMessageText(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool isMe,
  ) {
    final text = _resolvedBodyText();
    final textColor = _bubbleTextColor(isMe, isDark);
    final baseStyle = TextStyle(
      color: textColor,
      fontSize: 15,
      height: 1.4,
    );

    // Parse formatted text first
    final formattedSpan = TextFormatting.parseFormattedText(
      text,
      baseStyle: baseStyle,
      defaultColor: textColor,
    );

    // URL regex: http(s), www., and gekychat:// deep links
    final urlRegex = RegExp(
      r'(?:gekychat:\/\/[^\s<>\[\]()]+|(?:(?:https?:\/\/)|(?:www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*))',
      caseSensitive: false,
    );
    
    // Phone number regex: matches Ghana phone numbers
    // Pattern: (?:\+?233|0)?([1-9]\d{8})
    final phoneRegex = RegExp(r'(?:\+?233|0)?([1-9]\d{8})');
    
    final urlMatches = urlRegex.allMatches(text);
    final phoneMatches = phoneRegex.allMatches(text);

    if (urlMatches.isEmpty && phoneMatches.isEmpty) {
      return SelectableText.rich(
        formattedSpan,
        textWidthBasis: TextWidthBasis.longestLine,
      );
    }

    // Build TextSpan with clickable URLs and phone numbers while preserving formatting
    final spans = <TextSpan>[];
    final formattedChildren = formattedSpan.children;
    
    if (formattedChildren == null || formattedChildren.isEmpty) {
      // No children, just use the text directly
      return SelectableText.rich(formattedSpan);
    }
    
    // Process each formatted span and add URL/phone number detection
    for (final span in formattedChildren) {
      // Only process TextSpan elements
      if (span is! TextSpan) {
        spans.add(TextSpan(text: '', style: baseStyle));
        continue;
      }
      
      final spanText = span.text ?? '';
      final spanUrlMatches = urlRegex.allMatches(spanText);
      final spanPhoneMatches = phoneRegex.allMatches(spanText);
      
      // Combine all matches and sort by position
      final allMatches = <_ClickableMatch>[
        ...spanUrlMatches.map((m) => _ClickableMatch(m.start, m.end, 'url', m.group(0)!)),
        ...spanPhoneMatches.map((m) => _ClickableMatch(m.start, m.end, 'phone', m.group(0)!)),
      ]..sort((a, b) => a.start.compareTo(b.start));
      
      if (allMatches.isEmpty) {
        spans.add(span);
      } else {
        // Split span text by clickable elements
        int lastEnd = 0;
        for (final match in allMatches) {
          // Skip if this match overlaps with previous one
          if (match.start < lastEnd) continue;
          
          if (match.start > lastEnd) {
            spans.add(TextSpan(
              text: spanText.substring(lastEnd, match.start),
              style: span.style,
            ));
          }
          
          if (match.type == 'url') {
            spans.add(TextSpan(
              text: match.text,
              style: (span.style ?? baseStyle).copyWith(
                color: AppTheme.primaryGreen,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _handleUrlClick(context, ref, match.text),
            ));
          } else if (match.type == 'phone') {
            final normalizedPhone = _normalizePhoneNumber(match.text);
            spans.add(TextSpan(
              text: match.text,
              style: (span.style ?? baseStyle).copyWith(
                color: AppTheme.primaryGreen,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _handlePhoneClick(context, ref, normalizedPhone),
            ));
          }
          
          lastEnd = match.end;
        }
        
        if (lastEnd < spanText.length) {
          spans.add(TextSpan(
            text: spanText.substring(lastEnd),
            style: span.style,
          ));
        }
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters except +
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleaned.startsWith('233')) {
      return '+$cleaned';
    } else if (cleaned.startsWith('0')) {
      return '+233${cleaned.substring(1)}';
    } else if (cleaned.length == 9 && !cleaned.startsWith('0')) {
      return '+233$cleaned';
    }
    
    return cleaned.startsWith('+') ? cleaned : '+$cleaned';
  }

  IconData _getDocumentIcon(String? mimeType, String? fileName) {
    final lowerMime = mimeType?.toLowerCase() ?? '';
    final lowerFile = fileName?.toLowerCase() ?? '';
    
    // Audio files (mp3, wav, m4a, aac, ogg, flac, etc.)
    if (lowerMime.startsWith('audio/') || 
        lowerFile.endsWith('.mp3') || lowerFile.endsWith('.wav') || 
        lowerFile.endsWith('.m4a') || lowerFile.endsWith('.aac') || 
        lowerFile.endsWith('.ogg') || lowerFile.endsWith('.flac') ||
        lowerFile.endsWith('.wma') || lowerFile.endsWith('.opus')) {
      return Icons.audiotrack;
    }
    
    // Video files (mp4, avi, mkv, mov, wmv, etc.)
    if (lowerMime.startsWith('video/') || 
        lowerFile.endsWith('.mp4') || lowerFile.endsWith('.avi') || 
        lowerFile.endsWith('.mkv') || lowerFile.endsWith('.mov') || 
        lowerFile.endsWith('.wmv') || lowerFile.endsWith('.flv') ||
        lowerFile.endsWith('.webm') || lowerFile.endsWith('.m4v')) {
      return Icons.videocam;
    }
    
    // Image files (jpg, png, gif, webp, etc.)
    if (lowerMime.startsWith('image/') || 
        lowerFile.endsWith('.jpg') || lowerFile.endsWith('.jpeg') || 
        lowerFile.endsWith('.png') || lowerFile.endsWith('.gif') || 
        lowerFile.endsWith('.webp') || lowerFile.endsWith('.bmp') ||
        lowerFile.endsWith('.svg') || lowerFile.endsWith('.ico')) {
      return Icons.image;
    }
    
    // PDF files
    if (lowerMime.contains('pdf') || lowerFile.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    
    // Word documents
    if (lowerMime.contains('word') || lowerMime.contains('doc') || 
        lowerFile.endsWith('.doc') || lowerFile.endsWith('.docx')) {
      return Icons.description;
    }
    
    // Excel/Spreadsheet files
    if (lowerMime.contains('sheet') || lowerMime.contains('excel') || 
        lowerFile.endsWith('.xls') || lowerFile.endsWith('.xlsx') ||
        lowerFile.endsWith('.csv')) {
      return Icons.table_chart;
    }
    
    // PowerPoint files
    if (lowerMime.contains('presentation') || lowerMime.contains('powerpoint') ||
        lowerFile.endsWith('.ppt') || lowerFile.endsWith('.pptx')) {
      return Icons.slideshow;
    }
    
    // Archive/Compressed files
    if (lowerMime.contains('zip') || lowerMime.contains('rar') || 
        lowerMime.contains('archive') || lowerMime.contains('compressed') ||
        lowerFile.endsWith('.zip') || lowerFile.endsWith('.rar') || 
        lowerFile.endsWith('.7z') || lowerFile.endsWith('.tar') ||
        lowerFile.endsWith('.gz') || lowerFile.endsWith('.bz2')) {
      return Icons.folder_zip;
    }
    
    // Text files
    if (lowerMime.startsWith('text/') || 
        lowerFile.endsWith('.txt') || lowerFile.endsWith('.text') ||
        lowerFile.endsWith('.md') || lowerFile.endsWith('.json') ||
        lowerFile.endsWith('.xml') || lowerFile.endsWith('.csv')) {
      return Icons.text_snippet;
    }
    
    // Code files
    if (lowerFile.endsWith('.js') || lowerFile.endsWith('.ts') ||
        lowerFile.endsWith('.py') || lowerFile.endsWith('.java') ||
        lowerFile.endsWith('.cpp') || lowerFile.endsWith('.c') ||
        lowerFile.endsWith('.php') || lowerFile.endsWith('.rb') ||
        lowerFile.endsWith('.go') || lowerFile.endsWith('.rs')) {
      return Icons.code;
    }
    
    // Default file icon
    return Icons.insert_drive_file;
  }
  
  Color _getDocumentIconColor(String? mimeType, String? fileName) {
    final lowerMime = mimeType?.toLowerCase() ?? '';
    final lowerFile = fileName?.toLowerCase() ?? '';
    
    // Audio files - purple/blue
    if (lowerMime.startsWith('audio/') || 
        lowerFile.endsWith('.mp3') || lowerFile.endsWith('.wav') || 
        lowerFile.endsWith('.m4a') || lowerFile.endsWith('.aac') || 
        lowerFile.endsWith('.ogg') || lowerFile.endsWith('.flac') ||
        lowerFile.endsWith('.wma') || lowerFile.endsWith('.opus')) {
      return const Color(0xFF9C27B0); // Purple
    }
    
    // Video files - red
    if (lowerMime.startsWith('video/') || 
        lowerFile.endsWith('.mp4') || lowerFile.endsWith('.avi') || 
        lowerFile.endsWith('.mkv') || lowerFile.endsWith('.mov') || 
        lowerFile.endsWith('.wmv') || lowerFile.endsWith('.flv') ||
        lowerFile.endsWith('.webm') || lowerFile.endsWith('.m4v')) {
      return const Color(0xFFE53935); // Red
    }
    
    // Image files - teal
    if (lowerMime.startsWith('image/') || 
        lowerFile.endsWith('.jpg') || lowerFile.endsWith('.jpeg') || 
        lowerFile.endsWith('.png') || lowerFile.endsWith('.gif') || 
        lowerFile.endsWith('.webp') || lowerFile.endsWith('.bmp') ||
        lowerFile.endsWith('.svg') || lowerFile.endsWith('.ico')) {
      return const Color(0xFF00897B); // Teal
    }
    
    // PDF files - red
    if (lowerMime.contains('pdf') || lowerFile.endsWith('.pdf')) {
      return const Color(0xFFE53935); // Red
    }
    
    // Word documents - blue
    if (lowerMime.contains('word') || lowerMime.contains('doc') || 
        lowerFile.endsWith('.doc') || lowerFile.endsWith('.docx')) {
      return const Color(0xFF1976D2); // Blue
    }
    
    // Excel files - green
    if (lowerMime.contains('sheet') || lowerMime.contains('excel') || 
        lowerFile.endsWith('.xls') || lowerFile.endsWith('.xlsx') ||
        lowerFile.endsWith('.csv')) {
      return const Color(0xFF388E3C); // Green
    }
    
    // PowerPoint files - orange
    if (lowerMime.contains('presentation') || lowerMime.contains('powerpoint') ||
        lowerFile.endsWith('.ppt') || lowerFile.endsWith('.pptx')) {
      return const Color(0xFFFF6F00); // Orange
    }
    
    // Archive files - amber
    if (lowerMime.contains('zip') || lowerMime.contains('rar') || 
        lowerMime.contains('archive') || lowerMime.contains('compressed') ||
        lowerFile.endsWith('.zip') || lowerFile.endsWith('.rar') || 
        lowerFile.endsWith('.7z') || lowerFile.endsWith('.tar') ||
        lowerFile.endsWith('.gz') || lowerFile.endsWith('.bz2')) {
      return const Color(0xFFFFA000); // Amber
    }
    
    // Text files - blue-grey
    if (lowerMime.startsWith('text/') || 
        lowerFile.endsWith('.txt') || lowerFile.endsWith('.text') ||
        lowerFile.endsWith('.md') || lowerFile.endsWith('.json') ||
        lowerFile.endsWith('.xml') || lowerFile.endsWith('.csv')) {
      return const Color(0xFF546E7A); // Blue Grey
    }
    
    // Code files - indigo
    if (lowerFile.endsWith('.js') || lowerFile.endsWith('.ts') ||
        lowerFile.endsWith('.py') || lowerFile.endsWith('.java') ||
        lowerFile.endsWith('.cpp') || lowerFile.endsWith('.c') ||
        lowerFile.endsWith('.php') || lowerFile.endsWith('.rb') ||
        lowerFile.endsWith('.go') || lowerFile.endsWith('.rs')) {
      return const Color(0xFF3F51B5); // Indigo
    }
    
    // Default - green (WhatsApp style)
    return AppTheme.primaryGreen;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _handleUrlClick(BuildContext context, WidgetRef ref, String url) async {
    try {
      if (tryOpenWorldFeedUrlInApp(ref, context, url)) {
        return;
      }
      // Add https:// prefix if URL starts with www.
      String finalUrl = url;
      if (url.startsWith('www.')) {
        finalUrl = 'https://$url';
      }
      
      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $url')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open link: $e')),
        );
      }
    }
  }

  void _handlePhoneClick(BuildContext context, WidgetRef ref, String phone) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Phone: $phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: Text('Chat with $phone'),
              onTap: () => _startChatWithPhone(dialogContext, context, ref, phone),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Invite to GekyChat'),
              onTap: () {
                Navigator.pop(dialogContext);
                Share.share(
                  'Join me on GekyChat! Download the app and start chatting. Visit https://chat.gekychat.com for more info.',
                  subject: 'Invitation to GekyChat',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy number'),
              onTap: () async {
                Navigator.pop(dialogContext);
                await Clipboard.setData(ClipboardData(text: phone));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone number copied to clipboard')),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _startChatWithPhone(
    BuildContext dialogContext,
    BuildContext context,
    WidgetRef ref,
    String phone,
  ) async {
    Navigator.pop(dialogContext);

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final contactsRepo = ref.read(contactsRepositoryProvider);
      final conversations = await chatRepo.getConversations();

      for (final conversation in conversations) {
        if (PhoneMatcher.matchesLoose(conversation.otherUser.phone, phone)) {
          _navigateToConversation(context, ref, conversation.id);
          return;
        }
      }

      final phonesToResolve = <String>{
        phone,
        ...PhoneMatcher.candidates(phone),
        PhoneMatcher.normalizeGhanaLoginPhone(phone),
      }.where((p) => p.trim().isNotEmpty).toList();

      final resolved = await contactsRepo.resolvePhones(phonesToResolve);
      int? userId;
      for (final user in resolved) {
        final idRaw = user['id'];
        final id = idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
        if (id != null && id > 0) {
          userId = id;
          break;
        }
      }

      if (userId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$phone is not on GekyChat yet. Use Invite to send them a link.'),
            ),
          );
        }
        return;
      }

      for (final conversation in conversations) {
        if (conversation.otherUser.id == userId) {
          _navigateToConversation(context, ref, conversation.id);
          return;
        }
      }

      final conversationId = await chatRepo.startConversation(userId);
      if (context.mounted) {
        _navigateToConversation(context, ref, conversationId);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  void _navigateToConversation(
    BuildContext context,
    WidgetRef ref,
    int conversationId,
  ) {
    ref.read(currentSectionProvider.notifier).setSection('/chats');
    ref.read(selectedConversationProvider.notifier).selectConversation(conversationId);
    if (context.mounted) {
      context.go('/chats');
    }
  }
}

class _DocumentAttachmentData {
  const _DocumentAttachmentData({required this.fileExists});

  final bool fileExists;
}

/// Document tile with download/open actions and PDF preview after download.
class _DocumentAttachmentTile extends ConsumerStatefulWidget {
  const _DocumentAttachmentTile({
    required this.attachment,
    required this.isDark,
  });

  final MessageAttachment attachment;
  final bool isDark;

  @override
  ConsumerState<_DocumentAttachmentTile> createState() =>
      _DocumentAttachmentTileState();
}

class _DocumentAttachmentTileState extends ConsumerState<_DocumentAttachmentTile> {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  int _refreshToken = 0;

  MessageAttachment get attachment => widget.attachment;

  String get _fileName {
    var fileName = attachment.originalName ??
        attachment.url.split('/').last.split('?').first;

    String? extension;
    if (attachment.originalName != null) {
      final parts = attachment.originalName!.split('.');
      if (parts.length > 1) {
        extension = '.${parts.last.toLowerCase()}';
      }
    } else {
      final urlParts = fileName.split('.');
      if (urlParts.length > 1) {
        extension = '.${urlParts.last.toLowerCase()}';
      }
    }

    const maxLength = 30;
    if (fileName.length > maxLength && extension != null) {
      final nameWithoutExt =
          fileName.substring(0, fileName.length - extension.length);
      if (nameWithoutExt.length > maxLength - extension.length - 3) {
        fileName =
            '${nameWithoutExt.substring(0, maxLength - extension.length - 3)}...$extension';
      }
    } else if (fileName.length > maxLength) {
      fileName = '${fileName.substring(0, maxLength - 3)}...';
    }

    if (extension != null && !fileName.endsWith(extension)) {
      fileName = '$fileName$extension';
    }
    return fileName;
  }

  Future<String?> _resolveLocalPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadPathService = DownloadPathService(prefs);
      final storedPath =
          await downloadPathService.getDownloadPath(attachment.url);
      if (storedPath != null && await File(storedPath).exists()) {
        return storedPath;
      }
      if (storedPath != null) {
        await downloadPathService.removeDownloadPath(attachment.url);
      }
      return null;
    } catch (e) {
      debugPrint('Error resolving document path: $e');
      return null;
    }
  }

  Future<_DocumentAttachmentData> _loadDocumentData() async {
    final localPath = await _resolveLocalPath();
    return _DocumentAttachmentData(fileExists: localPath != null);
  }

  Future<void> _openFile(String filePath) async {
    try {
      final file = File(filePath);
      final absolutePath = file.absolute.path;
      if (!await file.exists()) {
        throw Exception('File does not exist: $absolutePath');
      }

      if (Platform.isWindows) {
        await Process.start(
          'explorer.exe',
          [absolutePath],
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isMacOS) {
        await Process.start(
          'open',
          [absolutePath],
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isLinux) {
        await Process.start(
          'xdg-open',
          [absolutePath],
          mode: ProcessStartMode.detached,
        );
      } else {
        throw UnsupportedError('Platform not supported for opening files');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }

  Future<void> _handleTap(bool fileExists, String? localPath) async {
    if (_isDownloading) return;
    if (fileExists && localPath != null) {
      await _openFile(localPath);
      return;
    }
    await _downloadFile();
  }

  Future<void> _downloadFile() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final prefs = await SharedPreferences.getInstance();
      final downloadPathService = DownloadPathService(prefs);

      var fileName = attachment.originalName ??
          attachment.url.split('/').last.split('?').first;

      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads/GekyChat');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final savePath = '${downloadDir.path}/$fileName';

      await apiService.downloadFile(
        attachment.displayUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _downloadProgress = received / total);
        },
      );

      await downloadPathService.saveDownloadPath(attachment.url, savePath);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
          _refreshToken++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to Downloads/GekyChat/$fileName'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => _openFile(savePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _fileName;
    final isDark = widget.isDark;

    return FutureBuilder<_DocumentAttachmentData>(
      key: ValueKey('doc_${attachment.id}_$_refreshToken'),
      future: _loadDocumentData(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final fileExists = data?.fileExists ?? false;
        final icon = _isDownloading
            ? Icons.downloading
            : (fileExists ? Icons.open_in_new_rounded : Icons.download_rounded);
        final actionText = _isDownloading
            ? '${(_downloadProgress * 100).toStringAsFixed(0)}%'
            : (fileExists ? 'Open' : 'Download');
        final subtitleText = attachment.originalSize != null
            ? _formatFileSize(attachment.originalSize!)
            : attachment.compressedSize != null
                ? _formatFileSize(attachment.compressedSize!)
                : 'File';

        final iconColor = _getDocumentIconColor(attachment.mimeType, fileName);

        return GestureDetector(
          onTap: () async {
            final localPath = await _resolveLocalPath();
            await _handleTap(fileExists, localPath);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getDocumentIcon(attachment.mimeType, fileName),
                          color: iconColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppTheme.textPrimaryDark
                                    : AppTheme.textPrimaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              subtitleText,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              actionText,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            icon,
                            size: 20,
                            color: fileExists ? AppTheme.primaryGreen : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isDownloading) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        minHeight: 4,
                        backgroundColor: isDark
                            ? const Color(0xFF2A3942)
                            : Colors.grey.shade300,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getDocumentIcon(String? mimeType, String? fileName) {
    final lowerMime = mimeType?.toLowerCase() ?? '';
    final lowerFile = fileName?.toLowerCase() ?? '';
    if (lowerMime.contains('pdf') || lowerFile.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (lowerMime.contains('word') ||
        lowerMime.contains('doc') ||
        lowerFile.endsWith('.doc') ||
        lowerFile.endsWith('.docx')) {
      return Icons.description;
    }
    if (lowerMime.contains('sheet') ||
        lowerMime.contains('excel') ||
        lowerFile.endsWith('.xls') ||
        lowerFile.endsWith('.xlsx')) {
      return Icons.table_chart;
    }
    return Icons.insert_drive_file;
  }

  Color _getDocumentIconColor(String? mimeType, String? fileName) {
    final lowerMime = mimeType?.toLowerCase() ?? '';
    final lowerFile = fileName?.toLowerCase() ?? '';
    if (lowerMime.contains('pdf') || lowerFile.endsWith('.pdf')) {
      return Colors.red.shade700;
    }
    if (lowerMime.contains('word') ||
        lowerMime.contains('doc') ||
        lowerFile.endsWith('.doc') ||
        lowerFile.endsWith('.docx')) {
      return Colors.blue.shade700;
    }
    if (lowerMime.contains('sheet') ||
        lowerMime.contains('excel') ||
        lowerFile.endsWith('.xls') ||
        lowerFile.endsWith('.xlsx')) {
      return Colors.green.shade700;
    }
    return AppTheme.primaryGreen;
  }
}

/// Helper class for tracking clickable matches (URLs and phone numbers)
class _ClickableMatch {
  final int start;
  final int end;
  final String type; // 'url' or 'phone'
  final String text;

  _ClickableMatch(this.start, this.end, this.type, this.text);
}

class _ViewOnceAttachmentsSection extends StatefulWidget {
  final Message message;
  final bool isMe;
  final bool isDark;
  final WidgetRef ref;
  final BuildContext context;
  final Future<void> Function(Message message)? onViewOnceOpened;
  final void Function(List<GalleryMediaItem> items, int index, {bool isViewOnce})
      openMediaGallery;
  final Widget Function(MessageAttachment) buildImage;
  final Widget Function(MessageAttachment) buildVideo;
  final Widget Function(MessageAttachment) buildAudio;
  final Widget Function(MessageAttachment) buildDocument;

  const _ViewOnceAttachmentsSection({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.ref,
    required this.context,
    required this.onViewOnceOpened,
    required this.openMediaGallery,
    required this.buildImage,
    required this.buildVideo,
    required this.buildAudio,
    required this.buildDocument,
  });

  @override
  State<_ViewOnceAttachmentsSection> createState() =>
      _ViewOnceAttachmentsSectionState();
}

class _ViewOnceAttachmentsSectionState extends State<_ViewOnceAttachmentsSection> {
  bool get _hasMedia => widget.message.attachments.any(
        (a) => a.isImage || a.isVideo || a.isAudio,
      );

  bool get _hasOnlyAudio => widget.message.attachments.isNotEmpty &&
      widget.message.attachments.every((a) => a.isAudio);

  @override
  Widget build(BuildContext context) {
    if (widget.message.isViewOnce && _hasMedia) {
      if (widget.isMe) {
        return _buildSentPlaceholder(context);
      }
      if (!widget.message.viewOnceOpened) {
        return _hasOnlyAudio
            ? _buildAudioPlaceholder(context)
            : _buildMediaPlaceholder(context);
      }
      if (_hasOnlyAudio) {
        return _buildAudioOpened(context);
      }
      return _buildOpenedLabel();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.message.attachments.map((attachment) {
        if (attachment.isAudio) {
          return widget.buildAudio(attachment);
        } else if (attachment.isImage) {
          return widget.buildImage(attachment);
        } else if (attachment.isVideo) {
          return widget.buildVideo(attachment);
        } else {
          return widget.buildDocument(attachment);
        }
      }).toList(),
    );
  }

  Widget _buildSentPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_1, size: 24, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            'View once',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => showViewOnceUnavailableOnDesktop(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        width: 200,
        height: 120,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_1, size: 40, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              'View once',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Open on mobile app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => showViewOnceUnavailableOnDesktop(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_1, size: 32, color: scheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View once voice message',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                Text(
                  'Open on mobile app',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioOpened(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off_outlined, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Opened',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenedLabel() {
    final textColor = (widget.isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off_outlined, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            'Viewed',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewOnceVideoViewer extends StatefulWidget {
  final String url;

  const _ViewOnceVideoViewer({required this.url});

  @override
  State<_ViewOnceVideoViewer> createState() => _ViewOnceVideoViewerState();
}

class _ViewOnceVideoViewerState extends State<_ViewOnceVideoViewer> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text('View once'),
      ),
      body: Center(
        child: controller != null && controller.value.isInitialized
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                  IconButton(
                    iconSize: 48,
                    color: Colors.white,
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_isPlaying) {
                          controller.pause();
                        } else {
                          controller.play();
                        }
                        _isPlaying = !_isPlaying;
                      });
                    },
                  ),
                ],
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

/// Voice message player widget (WhatsApp/Telegram style)
class VoiceMessagePlayer extends ConsumerStatefulWidget {
  final MessageAttachment attachment;
  final bool isDark;

  const VoiceMessagePlayer({
    super.key,
    required this.attachment,
    required this.isDark,
  });

  @override
  ConsumerState<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends ConsumerState<VoiceMessagePlayer> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _error;
  late AnimationController _animationController;
  late List<double> _waveformHeights;

  @override
  void initState() {
    super.initState();
    // Initialize waveform heights with random values (simulated waveform)
    _waveformHeights = List.generate(50, (index) {
      // Create a more realistic waveform pattern
      return 3.0 + (index % 7) * 1.5 + (index % 3) * 0.8;
    });
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
        if (_isPlaying) {
          _animationController.repeat();
        } else {
          _animationController.stop();
        }
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        _animationController.stop();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_position == Duration.zero || _position == _duration) {
          // Start from beginning or restart
          setState(() {
            _isLoading = true;
            _error = null;
          });
          await _audioPlayer.play(UrlSource(widget.attachment.displayUrl));
          setState(() {
            _isLoading = false;
          });
        } else {
          // Resume from current position
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to play audio: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Build waveform visualization (WhatsApp style)
  Widget _buildWaveform(double progress) {
    final barCount = _waveformHeights.length;
    final activeColor = widget.isDark ? AppTheme.primaryGreen : AppTheme.primaryGreen;
    final inactiveColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.15);
    
    return GestureDetector(
      onTapDown: (details) {
        if (_duration.inMilliseconds > 0) {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final localPosition = details.localPosition;
          final width = box.size.width;
          final tapPosition = localPosition.dx / width;
          final seekPosition = Duration(
            milliseconds: (_duration.inMilliseconds * tapPosition).round(),
          );
          _seekTo(seekPosition);
        }
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (index) {
            final barPosition = index / barCount;
            final isActive = barPosition <= progress;
            final baseHeight = _waveformHeights[index];
            
            // Animate bars when playing and they're active
            double animatedHeight = baseHeight;
            if (_isPlaying && isActive) {
              // Add subtle animation to active bars
              final animationValue = _animationController.value;
              final variation = (index % 3) / 3.0;
              animatedHeight = baseHeight * (1.0 + 0.2 * animationValue * (1 - variation));
            }
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 2.5,
              height: animatedHeight.clamp(3.0, 20.0),
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(
                color: isActive ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(1.25),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    // WhatsApp-style audio player: compact, clean design
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button (WhatsApp style - circular green button)
          GestureDetector(
            onTap: _isLoading ? null : _togglePlayPause,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Waveform and duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform visualization (WhatsApp style)
                _buildWaveform(progress),
                const SizedBox(height: 2),
                // Duration (WhatsApp style - right aligned)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' / ${_formatDuration(_duration)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
