import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../../../theme/app_theme.dart';
import '../forward_message_screen.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final int currentUserId;
  final bool isStarred;
  final VoidCallback? onDelete;
  final VoidCallback? onStar;
  final VoidCallback? onReply;
  final Function(String)? onReact;
  final VoidCallback? onReplyPrivately;
  final bool isGroupMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.isStarred = false,
    this.onDelete,
    this.onStar,
    this.onReply,
    this.onReact,
    this.onReplyPrivately,
    this.isGroupMessage = false,
  });

  bool get isMe => message.senderId == currentUserId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(context, context),
        onSecondaryTapDown: (details) => _showMessageMenuAtPosition(context, details.globalPosition),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe
                      ? (isDark ? AppTheme.outgoingBubbleDark : AppTheme.outgoingBubbleLight)
                      : (isDark ? AppTheme.incomingBubbleDark : AppTheme.incomingBubbleLight),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isMe ? 12 : 2),
                    bottomRight: Radius.circular(isMe ? 2 : 12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Attachments
                    if (message.attachments.isNotEmpty)
                      ...message.attachments.map((attachment) {
                        if (attachment.isImage) {
                          return _buildImageAttachment(attachment);
                        } else if (attachment.isVideo) {
                          return _buildVideoAttachment(attachment);
                        } else {
                          return _buildDocumentAttachment(attachment, isDark);
                        }
                      }),

                    // Location Data
                    if (message.locationData != null)
                      _buildLocationCard(message.locationData!, isDark),

                    // Contact Data
                    if (message.contactData != null)
                      _buildContactCard(message.contactData!, isDark),

                    // Call Data
                    if (message.callData != null)
                      _buildCallCard(message.callData!, isDark),

                    // Link Previews
                    if (message.linkPreviews != null && message.linkPreviews!.isNotEmpty)
                      ...message.linkPreviews!.map((preview) => _buildLinkPreview(preview, isDark)),

                    // Message body
                    if (message.body.isNotEmpty && !_isSpecialMessage(message))
                      Padding(
                        padding: EdgeInsets.only(
                          top: message.attachments.isNotEmpty || 
                               message.locationData != null || 
                               message.contactData != null ||
                               message.callData != null ||
                               (message.linkPreviews != null && message.linkPreviews!.isNotEmpty) ? 8 : 0,
                        ),
                        child: _buildMessageText(context, isDark, isMe),
                      ),

                    // Timestamp
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat.jm().format(message.createdAt),
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white.withOpacity(0.7)
                                  : (isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight),
                              fontSize: 11,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.readAt != null
                                  ? Icons.done_all
                                  : (message.deliveredAt != null
                                      ? Icons.done_all
                                      : Icons.done),
                              size: 14,
                              color: message.readAt != null
                                  ? const Color(0xFF53BDEB)
                                  : Colors.white.withOpacity(0.7),
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
                  padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
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
  }

  Widget _buildImageAttachment(MessageAttachment attachment) {
    return Container(
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
            if (attachment.isCompressing)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'Compressing...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoAttachment(MessageAttachment attachment) {
    // MEDIA COMPRESSION: Use thumbnail if available, otherwise use video URL
    final imageUrl = attachment.thumbnailUrl ?? attachment.displayUrl;
    final isCompressing = attachment.isCompressing;
    
    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          // MEDIA COMPRESSION: Show compression indicator
          if (isCompressing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    'Compressing...',
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
    );
  }

  Widget _buildDocumentAttachment(MessageAttachment attachment, bool isDark) {
    final fileName = attachment.url.split('/').last;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description, color: AppTheme.primaryGreen, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.download_rounded, size: 20),
        ],
      ),
    );
  }

  void _showMessageMenuAtPosition(BuildContext context, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    _showMessageMenu(context, context, position: overlay.globalToLocal(position));
  }

  void _showMessageMenu(BuildContext context, BuildContext widgetContext, {Offset? position}) {
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;
    
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
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.reply, size: 20),
              SizedBox(width: 8),
              Text('Reply'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              onReply?.call();
            });
          },
        ),
        if (isGroupMessage && !isMe)
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.person_outline, size: 20),
                SizedBox(width: 8),
                Text('Reply Privately'),
              ],
            ),
            onTap: () {
              Future.delayed(Duration.zero, () {
                onReplyPrivately?.call();
              });
            },
          ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.add_reaction, size: 20),
              SizedBox(width: 8),
              Text('React'),
            ],
          ),
          onTap: () {
            // Use Future.delayed to ensure the popup menu is closed before showing dialog
            // Use widgetContext instead of menu context to avoid invalid context errors
            Future.delayed(const Duration(milliseconds: 100), () {
              if (widgetContext.mounted) {
                _showReactionPicker(widgetContext);
              }
            });
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 8),
              Text('Copy'),
            ],
          ),
          onTap: () {
            // TODO: Copy message to clipboard
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.forward, size: 20),
              SizedBox(width: 8),
              Text('Forward'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ForwardMessageScreen(message: message),
                ),
              );
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(isStarred ? Icons.star : Icons.star_border, size: 20),
              const SizedBox(width: 8),
              Text(isStarred ? 'Unstar' : 'Star'),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            onStar?.call();
          },
        ),
        if (isMe)
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
            onTap: () {
              // TODO: Edit message
            },
          ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.delete, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
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

  bool _isSpecialMessage(Message message) {
    // Check if message body is just a placeholder for special content
    final body = message.body.toLowerCase().trim();
    return body == '👤 shared contact' || 
           body == '📍 shared location' || 
           body.contains('shared contact') ||
           body.contains('shared location') ||
           message.callData != null;
  }

  Widget _buildLocationCard(Map<String, dynamic> locationData, bool isDark) {
    final latitude = locationData['latitude'] as num?;
    final longitude = locationData['longitude'] as num?;
    final address = locationData['address'] as String?;
    final placeName = locationData['place_name'] as String?;

    if (latitude == null || longitude == null) return const SizedBox.shrink();

    final mapUrl = 'https://www.google.com/maps?q=$latitude,$longitude';

    return GestureDetector(
      onTap: () {
        // Open in browser/maps app
        // TODO: Use url_launcher package
        debugPrint('Open location: $mapUrl');
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

  Widget _buildCallCard(Map<String, dynamic> callData, bool isDark) {
    final callType = callData['type'] as String? ?? 'voice';
    final callStatus = callData['status'] as String? ?? 'ended';
    final callLink = callData['call_link'] as String?;
    final duration = callData['duration'] as int?;
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
      if (duration < 60) {
        durationText = '${duration}s';
      } else {
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        durationText = '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
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

    return GestureDetector(
      onTap: callLink != null && isActive
          ? () async {
              // Join call - navigate to call screen
              // This would need to be handled by the parent widget
            }
          : null,
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

  Widget _buildLinkPreview(dynamic previewData, bool isDark) {
    if (previewData is! Map) return const SizedBox.shrink();
    
    final preview = Map<String, dynamic>.from(previewData);
    final title = preview['title'] as String?;
    final description = preview['description'] as String?;
    final url = preview['url'] as String?;
    final image = preview['image'] as String?;
    final siteName = preview['site_name'] as String?;

    if (url == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        // Open URL
        // TODO: Use url_launcher package
        debugPrint('Open URL: $url');
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
            children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
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
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageText(BuildContext context, bool isDark, bool isMe) {
    final text = message.body;
    final baseStyle = TextStyle(
      color: isMe
          ? (isDark ? Colors.white : const Color(0xFF065F46))
          : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
      fontSize: 15,
      height: 1.4,
    );

    // Phone number regex: matches Ghana phone numbers
    // Pattern: (?:\+?233|0)?([1-9]\d{8})
    final phoneRegex = RegExp(r'(?:\+?233|0)?([1-9]\d{8})');
    final matches = phoneRegex.allMatches(text);

    if (matches.isEmpty) {
      // No phone numbers found, return plain text
      return Text(text, style: baseStyle);
    }

    // Build TextSpan with clickable phone numbers
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the phone number
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      // Add clickable phone number
      final phoneNumber = match.group(0)!;
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      spans.add(TextSpan(
        text: phoneNumber,
        style: baseStyle.copyWith(
          color: AppTheme.primaryGreen,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _handlePhoneClick(context, normalizedPhone),
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
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

  void _handlePhoneClick(BuildContext context, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Phone: $phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: Text('Chat with $phone'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to search/start conversation with phone
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Invite to GekyChat'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open invite dialog
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy number'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Copy to clipboard
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

