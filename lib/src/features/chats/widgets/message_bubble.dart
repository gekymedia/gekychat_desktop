import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/download_path_service.dart';
import '../models.dart';
import '../../../theme/app_theme.dart';
import '../forward_message_screen.dart';
import '../../../widgets/colored_avatar.dart';
import '../../../widgets/constrained_slide_route.dart';
import 'message_info_dialog.dart';
import '../../../core/providers.dart';
import '../../../utils/text_formatting.dart';
import '../../calls/call_manager.dart';
import '../../calls/call_screen.dart';
import '../../calls/call_session.dart';
import '../../calls/providers.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;
  final int currentUserId;
  final bool isStarred;
  final VoidCallback? onDelete;
  final VoidCallback? onStar;
  final VoidCallback? onReply;
  final Function(String)? onReact;
  final VoidCallback? onReplyPrivately;
  final Function(String)? onEdit;
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
    this.onEdit,
    this.isGroupMessage = false,
  });

  bool isMe(int currentUserId) => message.senderId == currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMeValue = isMe(currentUserId);

    // System messages are centered
    if (message.isSystem) {
      return _buildSystemMessage(context, isDark);
    }

    return Align(
      alignment: isMeValue ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(context, context, isMeValue),
        onSecondaryTapDown: (details) => _showMessageMenuAtPosition(context, details.globalPosition, isMeValue),
        onTap: () {
          // Show message info on tap (for sent messages in groups)
          if (isMeValue && isGroupMessage) {
            _showMessageInfo(context);
          }
        },
        child: Container(
          margin: EdgeInsets.only(
            left: isMeValue ? 8 : 8,
            right: isMeValue ? 8 : 8,
            top: 4,
            bottom: 4,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
          ),
          child: Column(
            crossAxisAlignment: isMeValue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMeValue
                      ? (isDark ? AppTheme.outgoingBubbleDark : AppTheme.outgoingBubbleLight)
                      : (isDark ? AppTheme.incomingBubbleDark : AppTheme.incomingBubbleLight),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isMeValue ? 12 : 2),
                    bottomRight: Radius.circular(isMeValue ? 2 : 12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender name and avatar for group messages
                    if (!isMeValue && isGroupMessage && message.sender != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            ColoredAvatar(
                              imageUrl: message.sender!['avatar_url'] as String? ?? message.sender!['avatar_path'] as String?,
                              name: message.sender!['name'] as String? ?? message.sender!['phone'] as String? ?? 'Unknown',
                              radius: 12,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              message.sender!['name'] as String? ?? message.sender!['phone'] as String? ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Attachments
                    // IMPORTANT: Check isAudio FIRST (before isVideo) because audio files
                    // can have .mp4 extension but are still audio (server sets isAudio flag based on MIME type)
                    if (message.attachments.isNotEmpty)
                      ...message.attachments.map((attachment) {
                        if (attachment.isAudio) {
                          return _buildAudioAttachment(attachment, isDark, ref, context);
                        } else if (attachment.isImage) {
                          return _buildImageAttachment(attachment);
                        } else if (attachment.isVideo) {
                          return _buildVideoAttachment(attachment);
                        } else {
                          return _buildDocumentAttachment(attachment, isDark, ref, context);
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
                      _buildCallCard(message.callData!, isDark, isMeValue),

                    // Link Previews
                    if (message.linkPreviews != null && message.linkPreviews!.isNotEmpty)
                      ...message.linkPreviews!.map((preview) => _buildLinkPreview(preview, isDark)),

                    // Deleted message indicator (WhatsApp style)
                    if (message.isDeleted)
                      Padding(
                        padding: EdgeInsets.only(
                          top: message.attachments.isNotEmpty || 
                               message.locationData != null || 
                               message.contactData != null ||
                               message.callData != null ||
                               (message.linkPreviews != null && message.linkPreviews!.isNotEmpty) ? 8 : 0,
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
                    else if (message.body.isNotEmpty && !_isSpecialMessage(message))
                      Padding(
                        padding: EdgeInsets.only(
                          top: message.attachments.isNotEmpty || 
                               message.locationData != null || 
                               message.contactData != null ||
                               message.callData != null ||
                               (message.linkPreviews != null && message.linkPreviews!.isNotEmpty) ? 8 : 0,
                        ),
                        child: _buildMessageText(context, isDark, isMeValue),
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
                              color: isMeValue
                                  ? (isDark ? Colors.white70 : Colors.white.withOpacity(0.7))
                                  : (isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight),
                              fontSize: 11,
                            ),
                          ),
                          if (isMeValue) ...[
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
    );
  }

  Widget _buildVideoAttachment(MessageAttachment attachment) {
    // MEDIA COMPRESSION: Use thumbnail if available, otherwise use video URL
    final thumbnailUrl = attachment.thumbnailUrl;
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
    );
  }

  Widget _buildDocumentAttachment(MessageAttachment attachment, bool isDark, WidgetRef ref, BuildContext context) {
    final fileName = attachment.url.split('/').last.split('?').first;
    return FutureBuilder<String?>(
      future: _getDownloadPath(attachment.url),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.hasData && snapshot.data != null;
        final localPath = snapshot.data;
        
        return FutureBuilder<bool>(
          future: localPath != null ? File(localPath).exists() : Future.value(false),
          builder: (context, fileExistsSnapshot) {
            final fileExists = fileExistsSnapshot.data ?? false;
            final showOpenIcon = isDownloaded && fileExists;
            
            return GestureDetector(
              onTap: () => _downloadFile(attachment, ref, context),
              child: Container(
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
                    Icon(
                      showOpenIcon ? Icons.open_in_new_rounded : Icons.download_rounded,
                      size: 20,
                      color: showOpenIcon ? AppTheme.primaryGreen : null,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _getDownloadPath(String attachmentUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadPathService = DownloadPathService(prefs);
      return await downloadPathService.getDownloadPath(attachmentUrl);
    } catch (e) {
      debugPrint('Error getting download path: $e');
      return null;
    }
  }

  Widget _buildAudioAttachment(MessageAttachment attachment, bool isDark, WidgetRef ref, BuildContext context) {
    return VoiceMessagePlayer(
      attachment: attachment,
      isDark: isDark,
    );
  }

  Future<void> _downloadFile(MessageAttachment attachment, WidgetRef ref, BuildContext context) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final prefs = await SharedPreferences.getInstance();
      final downloadPathService = DownloadPathService(prefs);
      
      // Check if file was already downloaded
      final existingPath = await downloadPathService.getDownloadPath(attachment.url);
      if (existingPath != null) {
        final file = File(existingPath);
        if (await file.exists()) {
          debugPrint('📂 [DOWNLOAD] File already exists at: $existingPath');
          debugPrint('📂 [DOWNLOAD] Opening file with default app...');
          
          // Open file with default application
          await _openFileWithDefaultApp(existingPath, context);
          return;
        } else {
          // File was deleted, remove from storage
          debugPrint('📂 [DOWNLOAD] Stored path exists but file was deleted, removing from storage');
          await downloadPathService.removeDownloadPath(attachment.url);
        }
      }
      
      // File doesn't exist locally, download it
      var fileName = attachment.url.split('/').last.split('?').first;
      
      // Fix filename extension based on attachment type
      // If the server stored an audio file with wrong extension (e.g., .mp4 instead of .m4a)
      // we should correct it based on the attachment's type information
      if (attachment.isAudio) {
        final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
        // Check if extension is wrong (not an audio extension)
        final audioExtensions = ['m4a', 'aac', 'mp3', 'wav', 'ogg', 'flac', 'mpeg', 'mpga'];
        if (extension.isEmpty || !audioExtensions.contains(extension)) {
          // Determine correct extension from mimeType or default to m4a
          String correctExt = 'm4a'; // default for audio
          final mimeTypeLower = attachment.mimeType.toLowerCase();
          if (mimeTypeLower.contains('mp3') || mimeTypeLower.contains('mpeg')) {
            correctExt = 'mp3';
          } else if (mimeTypeLower.contains('wav')) {
            correctExt = 'wav';
          } else if (mimeTypeLower.contains('ogg') || mimeTypeLower.contains('oga')) {
            correctExt = 'ogg';
          } else if (mimeTypeLower.contains('flac')) {
            correctExt = 'flac';
          } else if (mimeTypeLower.contains('aac')) {
            correctExt = 'aac';
          } else if (mimeTypeLower.contains('m4a') || mimeTypeLower.contains('x-m4a') || mimeTypeLower.contains('mp4a')) {
            correctExt = 'm4a';
          }
          
          // Replace the extension
          String nameWithoutExt;
          if (fileName.contains('.')) {
            nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
          } else {
            nameWithoutExt = fileName;
          }
          fileName = '$nameWithoutExt.$correctExt';
          debugPrint('📂 [DOWNLOAD] Fixed audio filename extension from URL: ${attachment.url.split('/').last.split('?').first} to: $fileName (mimeType: ${attachment.mimeType})');
        }
      }
      
      // Get download directory - create GekyChat subfolder like Telegram
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${directory.path}/Downloads/GekyChat');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      
      final savePath = '${downloadDir.path}/$fileName';
      
      // Show downloading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading...')),
        );
      }
      
      debugPrint('📂 [DOWNLOAD] Downloading file to: $savePath');
      
      // Download file
      await apiService.downloadFile(attachment.displayUrl, savePath);
      
      // Save the download path for future use
      await downloadPathService.saveDownloadPath(attachment.url, savePath);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to Downloads/GekyChat/$fileName'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => _openFileWithDefaultApp(savePath, context),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('📂 [DOWNLOAD] Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    }
  }

  /// Open a file with the default system application
  Future<void> _openFileWithDefaultApp(String filePath, BuildContext context) async {
    try {
      debugPrint('📂 [OPEN FILE] Opening file: $filePath');
      
      // Convert to absolute path and normalize
      final file = File(filePath);
      final absolutePath = file.absolute.path;
      
      // Verify file exists
      if (!await file.exists()) {
        throw Exception('File does not exist: $absolutePath');
      }
      
      if (Platform.isWindows) {
        // Windows: Use explorer.exe to open file with default application
        // This is more reliable than 'start' command for files with special characters
        await Process.start(
          'explorer.exe',
          [absolutePath],
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isMacOS) {
        // macOS: use 'open' command
        await Process.start(
          'open',
          [absolutePath],
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isLinux) {
        // Linux: use 'xdg-open' command
        await Process.start(
          'xdg-open',
          [absolutePath],
          mode: ProcessStartMode.detached,
        );
      } else {
        throw UnsupportedError('Platform not supported for opening files');
      }
      
      debugPrint('📂 [OPEN FILE] Successfully opened file: $absolutePath');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening file...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('📂 [OPEN FILE] Error opening file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file. Please try opening it manually.')),
        );
      }
    }
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
        // Message Info (for sent messages in groups)
        if (isGroupMessage && isMeValue)
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20),
                SizedBox(width: 8),
                Text('Message Info'),
              ],
            ),
            onTap: () {
              Future.delayed(Duration.zero, () {
                _showMessageInfo(widgetContext);
              });
            },
          ),
        if (isGroupMessage && !isMeValue)
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
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: message.body));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
            Navigator.pop(context);
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
                ConstrainedSlideRightRoute(
                  page: ForwardMessageScreen(message: message),
                  leftOffset: 400.0, // Sidebar width
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
        if (isMeValue)
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 100), () {
                if (widgetContext.mounted && onEdit != null) {
                  _showEditDialog(widgetContext);
                }
              });
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
      onTap: () async {
        final uri = Uri.parse(mapUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          debugPrint('Could not launch $mapUrl');
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
    try {
      // Extract callId from callLink (format: /calls/join/{callId})
      final uri = Uri.parse(callLink.startsWith('http') ? callLink : 'https://chat.gekychat.com$callLink');
      final segments = uri.pathSegments;
      final callIdIndex = segments.indexOf('join');
      
      if (callIdIndex == -1 || callIdIndex >= segments.length - 1) {
        throw Exception('Invalid call link format');
      }
      
      final callId = segments[callIdIndex + 1];
      
      // Get providers
      final callRepo = ref.read(callRepositoryProvider);
      final callManager = ref.read(callManagerProvider);
      
      // Join the call
      final response = await callRepo.joinCall(callId);
      
      if (response['status'] == 'success' && response['session_id'] != null) {
        final sessionId = response['session_id'] as int;
        final callType = callData['type'] as String? ?? 'voice';
        
        // Create call session
        final call = CallSession(
          id: sessionId,
          callerId: callData['caller_id'] as int? ?? 0,
          type: callType,
          status: 'ongoing',
        );
        
        // Set up call manager
        callManager.currentCall = call;
        callManager.callType = callType;
        callManager.isCaller = false;
        callManager.callState = CallState.connecting;
        
        // Navigate to call screen
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallScreen(
                call: call,
                userName: isGroupMessage ? 'Group Call' : 'Call',
                userAvatar: null,
                isIncoming: false,
                callManager: callManager,
              ),
            ),
          );
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to join call');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCallCard(Map<String, dynamic> callData, bool isDark, bool isMe) {
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
      onTap: () async {
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
          child: Text(
            message.body,
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

  Widget _buildMessageText(BuildContext context, bool isDark, bool isMe) {
    final text = message.body;
    final baseStyle = TextStyle(
      color: isMe
          ? (isDark ? Colors.white : const Color(0xFF065F46))
          : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
      fontSize: 15,
      height: 1.4,
    );

    // Parse formatted text first
    final formattedSpan = TextFormatting.parseFormattedText(
      text,
      baseStyle: baseStyle,
      defaultColor: isMe
          ? (isDark ? Colors.white : const Color(0xFF065F46))
          : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
    );

    // Phone number regex: matches Ghana phone numbers
    // Pattern: (?:\+?233|0)?([1-9]\d{8})
    final phoneRegex = RegExp(r'(?:\+?233|0)?([1-9]\d{8})');
    final matches = phoneRegex.allMatches(text);

    if (matches.isEmpty) {
      // No phone numbers found, return formatted text
      return Text.rich(formattedSpan);
    }

    // Build TextSpan with clickable phone numbers while preserving formatting
    final spans = <TextSpan>[];
    final formattedChildren = formattedSpan.children;
    
    if (formattedChildren == null || formattedChildren.isEmpty) {
      // No children, just use the text directly
      return Text.rich(formattedSpan);
    }
    
    // Process each formatted span and add phone number detection
    for (final span in formattedChildren) {
      // Only process TextSpan elements
      if (span is! TextSpan) {
        spans.add(TextSpan(text: '', style: baseStyle));
        continue;
      }
      
      final spanText = span.text ?? '';
      final phoneMatches = phoneRegex.allMatches(spanText);
      
      if (phoneMatches.isEmpty) {
        spans.add(span);
      } else {
        // Split span text by phone numbers
        int lastEnd = 0;
        for (final match in phoneMatches) {
          if (match.start > lastEnd) {
            spans.add(TextSpan(
              text: spanText.substring(lastEnd, match.start),
              style: span.style,
            ));
          }
          
          final phoneNumber = match.group(0)!;
          final normalizedPhone = _normalizePhoneNumber(phoneNumber);
          
          spans.add(TextSpan(
            text: phoneNumber,
            style: (span.style ?? baseStyle).copyWith(
              color: AppTheme.primaryGreen,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _handlePhoneClick(context, normalizedPhone),
          ));
          
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
              onTap: () async {
                Navigator.pop(context);
                // Navigate to search/start conversation with phone
                // This would require access to chat repository and navigation
                // For now, show a message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Starting chat with $phone...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Invite to GekyChat'),
              onTap: () {
                Navigator.pop(context);
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
                Navigator.pop(context);
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
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
