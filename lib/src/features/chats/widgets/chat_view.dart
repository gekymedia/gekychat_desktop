import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationPermission, LocationAccuracy, Position;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import '../chat_repo.dart';
import '../models.dart';
import 'message_bubble.dart';
import 'date_divider.dart';
import '../../../utils/date_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/services/taskbar_badge_service.dart';
import '../../../core/database/message_queue_service.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../contacts/contacts_repository.dart' show contactsRepositoryProvider;
import 'emoji_picker_widget.dart';
import '../../media/media_gallery_screen.dart';
import 'search_in_chat_screen.dart';
import '../../contacts/contact_info_screen.dart';
import '../../../widgets/slide_route.dart';
import '../../../widgets/constrained_slide_route.dart';
import '../../quick_replies/quick_replies_repository.dart' show QuickReply, quickRepliesRepositoryProvider;
import '../../quick_replies/quick_replies_repository.dart';
import '../../../theme/app_theme.dart';
import '../../calls/call_screen.dart';
import '../../calls/providers.dart';
import '../../calls/incoming_call_handler.dart';
import 'text_formatting_toolbar.dart';
import '../../../utils/text_formatting.dart';

class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
}

class _NewLineIntent extends Intent {
  const _NewLineIntent();
}

class ChatView extends ConsumerStatefulWidget {
  final int conversationId;
  final String contactName;
  final String? contactAvatar;
  final User? otherUser; // Add User object for status info

  const ChatView({
    super.key,
    required this.conversationId,
    required this.contactName,
    this.contactAvatar,
    this.otherUser,
  });

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final List<Message> _messages = [];
  final List<File> _attachments = [];
  bool _isLoading = false;
  bool _isSending = false;
  double _uploadProgress = 0.0;
  bool _isTyping = false;
  bool _otherUserRecording = false;
  bool _showEmojiPicker = false;
  int? _currentUserId;
  
  // Quick replies
  List<QuickReply> _quickReplies = [];
  List<QuickReply> _filteredQuickReplies = [];
  bool _showQuickReplySuggestions = false;
  
  // Reply to message
  int? _replyingToId;
  Message? _replyingToMessage;
  
  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  
  // Drag and drop
  bool _isDragging = false;
  
  // Text formatting
  bool _showFormattingToolbar = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadMessages();
    _setupRealtimeListener();
    _loadQuickReplies();
    _messageController.addListener(_onMessageChanged);
    // Listen for selection changes
    _messageController.addListener(_checkTextSelection);
    // Ensure recording state is false on init
    _isRecording = false;
  }
  
  void _onMessageChanged() {
    if (!mounted) return;
    
    final text = _messageController.text;
    final cursorPosition = _messageController.selection.baseOffset;
    
    if (cursorPosition < 0 || text.isEmpty) {
      if (mounted) {
        setState(() {
          _showQuickReplySuggestions = false;
        });
      }
      return;
    }
    
    // Check if "/" was just typed or is in the text
    if (cursorPosition > 0 && text.length >= cursorPosition) {
      final textBeforeCursor = text.substring(0, cursorPosition);
      final lastChar = cursorPosition > 0 ? textBeforeCursor[cursorPosition - 1] : '';
      
      if (lastChar == '/') {
        // Show all quick replies
        if (mounted) {
          setState(() {
            _filteredQuickReplies = _quickReplies;
            _showQuickReplySuggestions = _quickReplies.isNotEmpty;
          });
        }
      } else if (textBeforeCursor.contains('/')) {
        // Check if we're still in a "/" command
        final lastSlashIndex = textBeforeCursor.lastIndexOf('/');
        if (lastSlashIndex != -1) {
          final query = textBeforeCursor.substring(lastSlashIndex + 1).toLowerCase();
          if (mounted) {
            setState(() {
              _filteredQuickReplies = _quickReplies.where((qr) {
                return qr.title.toLowerCase().contains(query) || 
                       qr.message.toLowerCase().contains(query);
              }).toList();
              _showQuickReplySuggestions = _filteredQuickReplies.isNotEmpty;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _showQuickReplySuggestions = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _showQuickReplySuggestions = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _showQuickReplySuggestions = false;
        });
      }
    }
  }
  
  Future<void> _loadQuickReplies() async {
    try {
      final repo = ref.read(quickRepliesRepositoryProvider);
      final quickReplies = await repo.getQuickReplies();
      if (mounted) {
        setState(() {
          _quickReplies = quickReplies;
        });
      }
    } catch (e) {
      debugPrint('Error loading quick replies: $e');
      // Set empty list on error to prevent issues
      if (mounted) {
        setState(() {
          _quickReplies = [];
          _showQuickReplySuggestions = false;
        });
      }
    }
  }
  
  void _insertQuickReply(QuickReply quickReply) {
    final text = _messageController.text;
    final cursorPosition = _messageController.selection.baseOffset;
    
    if (cursorPosition < 0) {
      _messageController.text = quickReply.message;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: quickReply.message.length),
      );
      setState(() {
        _showQuickReplySuggestions = false;
      });
      return;
    }
    
    // Find the last "/" before cursor
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastSlashIndex = textBeforeCursor.lastIndexOf('/');
    
    if (lastSlashIndex != -1) {
      // Replace from "/" to cursor with the quick reply message
      final textAfterCursor = text.substring(cursorPosition);
      final newText = text.substring(0, lastSlashIndex) + quickReply.message + textAfterCursor;
      final newCursorPosition = lastSlashIndex + quickReply.message.length;
      
      _messageController.text = newText;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: newCursorPosition),
      );
      
      // Record usage
      try {
        final repo = ref.read(quickRepliesRepositoryProvider);
        repo.recordUsage(quickReply.id);
      } catch (e) {
        debugPrint('Error recording quick reply usage: $e');
      }
    } else {
      // No "/" found, just append
      _messageController.text = quickReply.message;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: quickReply.message.length),
      );
    }
    
    setState(() {
      _showQuickReplySuggestions = false;
    });
  }
  
  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload messages if conversation ID changed
    if (oldWidget.conversationId != widget.conversationId) {
      _loadMessages();
      _setupRealtimeListener();
    }
  }

  void _setupRealtimeListener() {
    final pusherService = ref.read(pusherServiceProvider);
    pusherService.connect();
    
    // Subscribe to conversation channel
    final channelName = 'conversation.${widget.conversationId}';
    
    // Listen for typing events - use correct event name and data structure
    pusherService.listen(channelName, 'UserTyping', (data) {
      if (mounted && data != null && data is Map<String, dynamic>) {
        final userId = data['user_id'] as int?;
        final isTyping = data['is_typing'] as bool? ?? false;
        
        // Only show typing if it's from the OTHER user, not current user
        if (userId != null && userId != _currentUserId && isTyping) {
          setState(() {
            _isTyping = true;
          });
          
          // Auto-hide typing indicator after 3 seconds (consistent with mobile)
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isTyping = false;
              });
            }
          });
        } else if (userId != null && userId != _currentUserId && !isTyping) {
          // Stop typing indicator when user stops typing
          if (mounted) {
            setState(() {
              _isTyping = false;
            });
          }
        }
      }
    });
    
    // Listen for recording events
    pusherService.listen(channelName, 'UserRecording', (data) {
      if (mounted && data != null && data is Map<String, dynamic>) {
        final userId = data['user_id'] as int?;
        final isRecording = data['is_recording'] as bool? ?? false;
        
        // Only show recording if it's from the OTHER user, not current user
        if (userId != null && userId != _currentUserId) {
          if (mounted) {
            setState(() {
              _otherUserRecording = isRecording;
            });
          }
        }
      }
    });
    
    // Listen for new messages
    pusherService.listen(channelName, 'MessageSent', (data) {
      if (mounted && data != null) {
        try {
          final message = Message.fromJson(data);
          setState(() {
            if (!_messages.any((m) => m.id == message.id)) {
              _messages.add(message);
            }
          });
          _scrollToBottom();
          // Update badge when new message arrives
          _updateTaskbarBadge();
        } catch (e) {
          debugPrint('Error handling real-time message: $e');
        }
      }
    });
    
    // Listen for message status updates (sending -> sent -> delivered -> read)
    pusherService.listen(channelName, 'MessageStatusUpdated', (data) {
      if (mounted && data != null) {
        try {
          final statusData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
          final messageId = statusData['message_id'] as int?;
          final status = statusData['status'] as String?;
          
          if (messageId != null && status != null) {
            setState(() {
              final messageIndex = _messages.indexWhere((m) => m.id == messageId);
              if (messageIndex != -1) {
                // Update message status by creating a new Message with updated status
                final oldMessage = _messages[messageIndex];
                _messages[messageIndex] = Message(
                  id: oldMessage.id,
                  conversationId: oldMessage.conversationId,
                  groupId: oldMessage.groupId,
                  senderId: oldMessage.senderId,
                  sender: oldMessage.sender,
                  body: oldMessage.body,
                  createdAt: oldMessage.createdAt,
                  replyToId: oldMessage.replyToId,
                  forwardedFromId: oldMessage.forwardedFromId,
                  forwardChain: oldMessage.forwardChain,
                  attachments: oldMessage.attachments,
                  reactions: oldMessage.reactions,
                  callData: oldMessage.callData,
                  linkPreviews: oldMessage.linkPreviews,
                  isDeleted: oldMessage.isDeleted,
                  deletedForMe: oldMessage.deletedForMe,
                  status: status, // Update status
                  isSystem: oldMessage.isSystem,
                  systemAction: oldMessage.systemAction,
                  readAt: oldMessage.readAt,
                  deliveredAt: oldMessage.deliveredAt,
                  locationData: oldMessage.locationData,
                  contactData: oldMessage.contactData,
                );
              }
            });
          }
        } catch (e) {
          debugPrint('Error handling message status update: $e');
        }
      }
    });
    
    // Listen for incoming calls on this conversation
    pusherService.listen(channelName, 'CallSignal', (data) {
      if (mounted && data != null) {
        try {
          final signalData = data is String ? jsonDecode(data) : data;
          final payload = signalData['payload'] is String
              ? jsonDecode(signalData['payload'] as String)
              : signalData['payload'] as Map<String, dynamic>;
          
          // Handle incoming call invite
          if (payload['action'] == 'invite') {
            final incomingCallHandler = ref.read(incomingCallHandlerProvider);
            incomingCallHandler.handleIncomingCallFromConversation(data, widget.conversationId);
          }
        } catch (e) {
          debugPrint('Error handling call signal in conversation: $e');
        }
      }
    });
  }
  
  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
    });
  }

  @override
  void dispose() {
    // Unsubscribe from Pusher channel
    final pusherService = ref.read(pusherServiceProvider);
    pusherService.unsubscribe('conversation.${widget.conversationId}');
    _messageController.removeListener(_onMessageChanged);
    _scrollController.dispose();
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final messages = await chatRepo.getConversationMessages(widget.conversationId);
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _isLoading = false;
      });
      _scrollToBottom();
      
      // Mark conversation as read after loading messages
      try {
        await chatRepo.markConversationAsRead(widget.conversationId);
        
        // Update badge immediately after marking as read to reflect new unread count
        // This ensures unread count reduces when app is open
        _updateTaskbarBadge();
      } catch (e) {
        debugPrint('Failed to mark conversation as read: $e');
        // Don't show error to user - this is a background operation
      }
      
      // Update badge after loading messages (may have changed unread count)
      _updateTaskbarBadge();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    }
  }
  
  void _updateTaskbarBadge() {
    if (!mounted) return;
    Future.microtask(() async {
      if (!mounted) return;
      try {
        final badgeService = ref.read(taskbarBadgeServiceProvider);
        await badgeService.updateBadge();
      } catch (e) {
        // Silently ignore errors when widget is disposed
        if (mounted) {
          debugPrint('Failed to update taskbar badge: $e');
        }
      }
    });
  }

  /// Build list of widgets including messages and date dividers
  List<Widget> _buildMessageList() {
    if (_messages.isEmpty) return [];

    final List<Widget> items = [];
    DateTime? previousDate;

    for (final message in _messages) {
      final messageDate = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );

      // Add date divider if this is a new day
      if (previousDate == null || messageDate != previousDate) {
        items.add(DateDivider(date: message.createdAt));
        previousDate = messageDate;
      }

      // Add the message
      items.add(
        MessageBubble(
          message: message,
          currentUserId: _currentUserId ?? 0,
          onDelete: () => _deleteMessage(message),
          onReply: () => _setReply(message),
          onReact: (emoji) => _reactToMessage(message, emoji),
          onEdit: (newBody) => _editMessage(message, newBody),
        ),
      );
    }

    return items;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _attachments.isEmpty) return;

    setState(() {
      _isSending = true;
      _uploadProgress = 0.0;
    });

    final isOnline = ref.read(connectivityProvider);
    final messageQueue = ref.read(messageQueueServiceProvider);

    try {
      if (!isOnline) {
        // Queue message for offline sending
        await messageQueue.queueMessage(
          conversationId: widget.conversationId,
          groupId: null,
          body: message,
          replyToId: _replyingToId,
          attachments: _attachments.isNotEmpty ? _attachments : null,
        );

        // Create a temporary message object for UI display
        final tempMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
          conversationId: widget.conversationId,
          senderId: _currentUserId ?? 0,
          body: message,
          createdAt: DateTime.now(),
          replyToId: _replyingToId,
          attachments: _attachments.map<MessageAttachment>((file) {
            // Create temporary attachment objects
            return MessageAttachment(
              id: 0,
              url: file.path,
              mimeType: 'application/octet-stream',
              isImage: false,
              isVideo: false,
              isAudio: false,
              isDocument: true,
            );
          }).toList(),
          reactions: [],
        );

        setState(() {
          _messages.add(tempMessage);
          _messageController.clear();
          _attachments.clear();
          _replyingToId = null;
          _replyingToMessage = null;
        });
        _scrollToBottom();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message queued. Will be sent when you\'re online.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Send immediately when online
        final chatRepo = ref.read(chatRepositoryProvider);
        final newMessage = await chatRepo.sendMessageToConversation(
          conversationId: widget.conversationId,
          body: message.isEmpty ? null : message,
          replyTo: _replyingToId,
          attachments: _attachments.isNotEmpty ? _attachments : null,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          },
        );
        
        // Check if this is an AI chat (bot phone number is 0000000000)
        final isAiChat = widget.otherUser?.phone == '0000000000' || 
                         widget.otherUser?.phone == '+2330000000000';
        
        if (isAiChat) {
          // For AI chat, just add the new message and show typing indicator instead of reloading
          setState(() {
            _messages.add(newMessage);
            _isTyping = true; // Show typing indicator for AI
            _messageController.clear();
            _attachments.clear();
            _replyingToId = null;
            _replyingToMessage = null;
          });
          _scrollToBottom();
          // Show typing indicator - actual AI response will come via Pusher/WebSocket
          // Don't reload all messages, just wait for new message to arrive via real-time updates
          // The Pusher listener will handle adding the AI response to the messages list
        } else {
          // For regular chats, add message optimistically - WhatsApp/Telegram style smooth append
          setState(() {
            // Add sent message to list immediately (optimistic update)
            if (!_messages.any((m) => m.id == newMessage.id)) {
              _messages.add(newMessage);
            }
            _messageController.clear();
            _attachments.clear();
            _replyingToId = null;
            _replyingToMessage = null;
          });
          _scrollToBottom();
          
          // Real-time Pusher listener will handle message status updates (sent -> delivered -> read)
          // No need to reload entire chat - Telegram/WhatsApp style smooth experience!
          // Status updates come via MessageStatusUpdated event in real-time
        }
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $errorMessage'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _pickPhotoOrVideo() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'mp4', 'mov', 'avi', 'mkv', 'webm'],
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      
      // Show preview dialog for images and videos
      final shouldAdd = await _showMediaPreviewDialog(files);
      
      if (shouldAdd == true) {
        setState(() {
          _attachments.addAll(files);
        });
      }
    }
  }

  Future<bool?> _showMediaPreviewDialog(List<File> files) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Preview Media',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final path = file.path.toLowerCase();
                    final isImage = path.endsWith('.jpg') || path.endsWith('.jpeg') || 
                                   path.endsWith('.png') || path.endsWith('.gif') || 
                                   path.endsWith('.webp') || path.endsWith('.bmp');
                    final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') || 
                                   path.endsWith('.avi') || path.endsWith('.mkv') || 
                                   path.endsWith('.webm');
                    
                    return Container(
                      width: 300,
                      margin: const EdgeInsets.only(right: 8),
                      child: isImage
                          ? Image.file(
                              file,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.error, size: 48),
                                  ),
                                );
                              },
                            )
                          : isVideo
                              ? VideoPreviewWidget(file: file)
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.insert_drive_file, size: 48),
                                  ),
                                ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any, // Allow all file types like WhatsApp
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _attachments.addAll(
          result.files
              .where((f) => f.path != null)
              .map((f) => File(f.path!))
              .toList(),
        );
      });
    }
  }

  Future<void> _recordAudio() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required to record audio')),
        );
      }
      return;
    }

    if (_isRecording) {
      // Stop recording
      await _stopRecording();
    } else {
      // Start recording
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/recording_$timestamp.m4a';

      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath!,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        // Send recording indicator to other user
        try {
          final chatRepo = ref.read(chatRepositoryProvider);
          await chatRepo.sendRecordingIndicator(widget.conversationId, true);
        } catch (e) {
          debugPrint('Failed to send recording indicator: $e');
        }

        // Update duration timer
        _updateRecordingDuration();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      var path = await _audioRecorder.stop();
      debugPrint('🎤 [AUDIO RECORDING] Stop recording returned path: $path');
      
      setState(() {
        _isRecording = false;
      });

      // Send recording stop indicator to other user
      try {
        final chatRepo = ref.read(chatRepositoryProvider);
        await chatRepo.sendRecordingIndicator(widget.conversationId, false);
      } catch (e) {
        debugPrint('Failed to send recording stop indicator: $e');
      }

      if (path != null && mounted) {
        // Ensure the file has .m4a extension (audio format)
        // The record package might return .mp4, so we need to rename it
        var audioPath = path;
        debugPrint('🎤 [AUDIO RECORDING] Initial audioPath: $audioPath');
        debugPrint('🎤 [AUDIO RECORDING] File extension: ${audioPath.split('.').last}');
        
        final file = File(audioPath);
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('🎤 [AUDIO RECORDING] File exists, size: $fileSize bytes');
          
          final pathLower = audioPath.toLowerCase();
          // If the file has .mp4 extension, rename it to .m4a
          if (pathLower.endsWith('.mp4')) {
            debugPrint('🎤 [AUDIO RECORDING] ⚠️ File has .mp4 extension, renaming to .m4a');
            final newPath = audioPath.replaceAll(RegExp(r'\.mp4$', caseSensitive: false), '.m4a');
            debugPrint('🎤 [AUDIO RECORDING] Renaming from: $audioPath');
            debugPrint('🎤 [AUDIO RECORDING] Renaming to: $newPath');
            final newFile = await file.rename(newPath);
            audioPath = newFile.path;
            debugPrint('🎤 [AUDIO RECORDING] ✅ Successfully renamed to: $audioPath');
            debugPrint('🎤 [AUDIO RECORDING] New file extension: ${audioPath.split('.').last}');
          } else if (!pathLower.endsWith('.m4a') && !pathLower.endsWith('.aac') && 
                     !pathLower.endsWith('.mp3') && !pathLower.endsWith('.wav')) {
            debugPrint('🎤 [AUDIO RECORDING] ⚠️ File has no recognized audio extension, adding .m4a');
            final newPath = '$audioPath.m4a';
            debugPrint('🎤 [AUDIO RECORDING] Adding extension: $newPath');
            final newFile = await file.rename(newPath);
            audioPath = newFile.path;
            debugPrint('🎤 [AUDIO RECORDING] ✅ Successfully added .m4a extension: $audioPath');
          } else {
            debugPrint('🎤 [AUDIO RECORDING] ✅ File already has valid audio extension: ${audioPath.split('.').last}');
          }
        } else {
          debugPrint('🎤 [AUDIO RECORDING] ❌ ERROR: File does not exist at path: $audioPath');
        }
        
        debugPrint('🎤 [AUDIO RECORDING] Final audioPath before dialog: $audioPath');
        // Show dialog to confirm sending or canceling with audio preview
        final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Voice Message'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Recording duration: ${_formatDuration(_recordingDuration)}'),
                const SizedBox(height: 16),
                // Audio preview player
                DesktopAudioPreviewWidget(
                  audioPath: audioPath,
                  duration: _recordingDuration,
                  audioPlayer: _audioPlayer,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        _audioPlayer.stop();
                        Navigator.pop(context, false);
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        debugPrint('🎤 [AUDIO SEND] Send button pressed!');
                        debugPrint('🎤 [AUDIO SEND] audioPath at send button: $audioPath');
                        debugPrint('🎤 [AUDIO SEND] File extension: ${audioPath.split('.').last}');
                        _audioPlayer.stop();
                        Navigator.pop(context, true);
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        if (shouldSend == true) {
          debugPrint('🎤 [AUDIO SEND] User confirmed send, calling _sendVoiceMessage');
          debugPrint('🎤 [AUDIO SEND] audioPath passed to _sendVoiceMessage: $audioPath');
          debugPrint('🎤 [AUDIO SEND] File extension: ${audioPath.split('.').last}');
          // Send voice message immediately instead of adding to attachments
          await _sendVoiceMessage(audioPath);
        } else {
          // Delete the recording file
          try {
            final file = File(audioPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('Failed to delete recording: $e');
          }
        }
      }

      _recordingPath = null;
      _recordingDuration = Duration.zero;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    }
  }

  Future<void> _sendVoiceMessage(String audioPath) async {
    debugPrint('🎤 [AUDIO SEND] _sendVoiceMessage called with path: $audioPath');
    debugPrint('🎤 [AUDIO SEND] File extension: ${audioPath.split('.').last}');
    
    // Verify file exists and get info
    final file = File(audioPath);
    if (await file.exists()) {
      final fileSize = await file.length();
      debugPrint('🎤 [AUDIO SEND] File exists, size: $fileSize bytes');
    } else {
      debugPrint('🎤 [AUDIO SEND] ❌ ERROR: File does not exist at path: $audioPath');
    }
    
    setState(() {
      _isSending = true;
      _uploadProgress = 0.0;
    });

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      debugPrint('🎤 [AUDIO SEND] Creating File object from path: $audioPath');
      final fileToSend = File(audioPath);
      debugPrint('🎤 [AUDIO SEND] File object path: ${fileToSend.path}');
      debugPrint('🎤 [AUDIO SEND] File object basename: ${fileToSend.path.split(Platform.pathSeparator).last}');
      debugPrint('🎤 [AUDIO SEND] File extension from basename: ${fileToSend.path.split(Platform.pathSeparator).last.split('.').last}');
      
      // Send voice message with no compression
      debugPrint('🎤 [AUDIO SEND] Calling sendMessageToConversation with file: ${fileToSend.path}');
      final newMessage = await chatRepo.sendMessageToConversation(
        conversationId: widget.conversationId,
        body: null,
        replyTo: _replyingToId,
        attachments: [fileToSend],
        skipCompression: true, // Voice messages shouldn't be compressed
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );
      
      setState(() {
        _messages.add(newMessage);
        _replyingToId = null;
        _replyingToMessage = null;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _updateRecordingDuration() {
    if (!_isRecording) return;
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isRecording) {
        setState(() {
          _recordingDuration = _recordingDuration + const Duration(seconds: 1);
        });
        _updateRecordingDuration();
      }
    });
  }

  Widget _buildRecordingWave() {
    // Enhanced wave animation that simulates voice level modulation
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300), // Faster animation for more responsive feel
      onEnd: () {
        if (_isRecording && mounted) {
          setState(() {}); // Restart animation
        }
      },
      builder: (context, value, child) {
        // Simulate varying voice levels with different patterns
        final waveCount = 7;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(waveCount, (index) {
            final delay = index * 0.15;
            final animationValue = ((value + delay) % 1.0);
            
            // Create varying heights to simulate voice modulation
            // Middle bars are taller (simulating center emphasis)
            final centerOffset = (index - waveCount / 2).abs() / (waveCount / 2);
            final baseHeight = 6.0;
            final maxHeight = 28.0 * (1.0 - centerOffset * 0.4); // Taller in center
            
            // Add randomness based on animation phase
            final modulation = 0.7 + (0.3 * animationValue);
            final height = baseHeight + (maxHeight * modulation);
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOut,
              width: 3,
              height: height.clamp(6.0, 32.0),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 2,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${(difference.inDays / 7).floor()} week${(difference.inDays / 7).floor() == 1 ? '' : 's'} ago';
    }
  }

  Future<void> _startCall(String type) async {
    try {
      final callManager = ref.read(callManagerProvider);
      await callManager.startCall(
        conversationId: widget.conversationId,
        type: type,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              call: callManager.currentCall!,
              userName: widget.contactName,
              userAvatar: widget.contactAvatar,
              isIncoming: false,
              callManager: callManager,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }

  Future<void> _shareLocation() async {
    // Request location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable location services.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied. Please enable them in settings.')),
        );
      }
      return;
    }

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Reverse geocoding using OpenStreetMap Nominatim API (free, no key required)
        String? address;
        String? placeName;
        
        try {
          final response = await Dio().get(
            'https://nominatim.openstreetmap.org/reverse',
            queryParameters: {
              'format': 'json',
              'lat': position.latitude,
              'lon': position.longitude,
              'zoom': 18,
              'addressdetails': 1,
            },
            options: Options(
              headers: {
                'User-Agent': 'GekyChat-Desktop/1.0', // Required by Nominatim
              },
            ),
          );
          
          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            if (data['display_name'] != null) {
              address = data['display_name'] as String;
              placeName = data['name'] as String? ?? 
                         (address.contains(',') ? address.split(',')[0] : address);
            }
          }
        } catch (e) {
          debugPrint('Reverse geocoding failed: $e');
          // Continue without address
        }

        setState(() {
          _isSending = true;
        });

        final chatRepo = ref.read(chatRepositoryProvider);
        final newMessage = await chatRepo.shareLocationInConversation(
          widget.conversationId,
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          placeName: placeName,
        );
        setState(() {
          _messages.add(newMessage);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _shareContact() async {
    // Load all contacts with pagination
    final contactsRepo = ref.read(contactsRepositoryProvider);
    List<GekyContact> allContacts = [];
    int page = 1;
    bool hasMore = true;
    
    while (hasMore) {
      try {
        final paginated = await contactsRepo.listContactsPaginated(page: page, perPage: 100);
        final contacts = paginated['data'] as List<GekyContact>;
        allContacts.addAll(contacts);
        
        final meta = paginated['meta'] as Map<String, dynamic>;
        final currentPage = meta['current_page'] as int? ?? page;
        final lastPage = meta['last_page'] as int? ?? page;
        hasMore = currentPage < lastPage;
        page++;
      } catch (e) {
        debugPrint('Error loading contacts page $page: $e');
        break;
      }
    }
    
    if (!mounted) return;
    
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Share Contact',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: allContacts.isEmpty
                    ? const Center(child: Text('No contacts available'))
                    : ListView.builder(
                        itemCount: allContacts.length,
                        itemBuilder: (context, index) {
                          final contact = allContacts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?'),
                            ),
                            title: Text(contact.name),
                            subtitle: contact.phone != null ? Text(contact.phone!) : null,
                            onTap: () => Navigator.pop(context, contact.id),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _isSending = true;
      });

      try {
        final chatRepo = ref.read(chatRepositoryProvider);
        final newMessage = await chatRepo.shareContactInConversation(
          widget.conversationId,
          contactId: selected,
        );
        setState(() {
          _messages.add(newMessage);
        });
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to share contact: $e')),
          );
        }
      } finally {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _clearChat(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages in this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final chatRepo = ref.read(chatRepositoryProvider);
        await chatRepo.clearConversation(widget.conversationId);
        setState(() {
          _messages.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear chat: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportChat(BuildContext context) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final content = await chatRepo.exportConversation(widget.conversationId);
      
      // For desktop, we'd typically save to a file
      // For now, just show a dialog with the content
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Chat Export'),
            content: SingleChildScrollView(
              child: SelectableText(content),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export chat: $e')),
        );
      }
    }
  }

  Future<void> _deleteChat(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final chatRepo = ref.read(chatRepositoryProvider);
        await chatRepo.deleteConversation(widget.conversationId);
        if (mounted) {
          Navigator.pop(context); // Go back to chat list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete chat: $e')),
          );
        }
      }
    }
  }

  void _setReply(Message message) {
    setState(() {
      _replyingToId = message.id;
      _replyingToMessage = message;
    });
  }

  void _clearReply() {
    setState(() {
      _replyingToId = null;
      _replyingToMessage = null;
    });
  }

  Future<void> _reactToMessage(Message message, String emoji) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.reactToMessage(message.id, emoji);
      // Fetch only the updated message instead of reloading all messages
      final updatedMessage = await chatRepo.getMessage(message.id);
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = updatedMessage;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to react: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(Message message) async {
    // PHASE 1: Check if message is less than 1 hour old (for "delete for everyone")
    final messageAge = DateTime.now().difference(message.createdAt);
    final canDeleteForEveryone = messageAge.inHours < 1;

    // Show confirmation dialog with options
    final deleteType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How would you like to delete this message?'),
            const SizedBox(height: 16),
            if (canDeleteForEveryone)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Delete for everyone'),
                subtitle: const Text('Remove this message for all participants'),
                onTap: () => Navigator.pop(context, 'everyone'),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for me'),
              subtitle: const Text('Remove this message only from your device'),
              onTap: () => Navigator.pop(context, 'me'),
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

    if (deleteType == null) return;

    final deleteForEveryone = deleteType == 'everyone';

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.deleteMessage(message.id, deleteForEveryone: deleteForEveryone);
      
      setState(() {
        if (deleteForEveryone) {
          // WhatsApp style: Show "This message was deleted" for other users
          // For sender, message disappears (handled by backend filtering)
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            // Create a deleted message version
            final deletedMessage = Message(
              id: message.id,
              conversationId: message.conversationId,
              groupId: message.groupId,
              senderId: message.senderId,
              sender: message.sender,
              body: '', // Empty body for deleted message
              createdAt: message.createdAt,
              replyToId: message.replyToId,
              forwardedFromId: message.forwardedFromId,
              forwardChain: message.forwardChain,
              attachments: [],
              readAt: message.readAt,
              deliveredAt: message.deliveredAt,
              reactions: [],
              locationData: null,
              contactData: null,
              callData: null,
              linkPreviews: [],
              isDeleted: true, // Mark as deleted
              deletedForMe: false,
            );
            _messages[index] = deletedMessage;
          }
        } else {
          // Delete for me: Remove message from list (Telegram style for sender)
          _messages.removeWhere((m) => m.id == message.id);
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deleteForEveryone 
              ? 'Message deleted for everyone'
              : 'Message deleted'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    }
  }

  Future<void> _editMessage(Message message, String newBody) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final updatedMessage = await chatRepo.editMessage(message.id, newBody);
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = updatedMessage;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit message: $e')),
        );
      }
    }
  }

  void _checkTextSelection() {
    final selection = _messageController.selection;
    setState(() {
      _showFormattingToolbar = selection.isValid && !selection.isCollapsed;
    });
  }

  void _applyTextFormatting(String formatType) {
    final selection = _messageController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }

    final text = _messageController.text;
    final newText = TextFormatting.wrapTextWithFormatting(
      text,
      selection.start,
      selection.end,
      formatType,
    );

    // Calculate new cursor position
    final selectedLength = selection.end - selection.start;
    final markerLength = 1; // Single character marker
    final newOffset = selection.start + selectedLength + (markerLength * 2);

    setState(() {
      _messageController.text = newText;
      _messageController.selection = TextSelection.collapsed(offset: newOffset);
      _showFormattingToolbar = false;
    });
  }

  Widget _buildAvatar({required String? avatarUrl, required String name, required double radius}) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: Text(name[0], style: TextStyle(fontSize: radius * 0.8)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image(
          image: CachedNetworkImageProvider(avatarUrl),
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                name[0],
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202C33) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildAvatar(
                avatarUrl: widget.contactAvatar,
                name: widget.contactName,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.contactName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.otherUser?.isOnline == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF008069),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_otherUserRecording)
                      Row(
                        children: [
                          Icon(
                            Icons.mic,
                            size: 14,
                            color: const Color(0xFF008069),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'recording audio...',
                            style: TextStyle(
                              color: const Color(0xFF008069),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else if (_isTyping)
                      Text(
                        'typing...',
                        style: TextStyle(
                          color: const Color(0xFF008069),
                          fontSize: 12,
                        ),
                      )
                    else if (widget.otherUser?.isOnline == true)
                      const Text(
                        'online',
                        style: TextStyle(
                          color: Color(0xFF008069),
                          fontSize: 12,
                        ),
                      )
                    else if (widget.otherUser?.lastSeenAt != null)
                      Text(
                        'last seen ${_formatLastSeen(widget.otherUser!.lastSeenAt!)}',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.call, color: isDark ? Colors.white70 : Colors.grey[600]),
                onPressed: () => _startCall('voice'),
              ),
              IconButton(
                icon: Icon(Icons.videocam, color: isDark ? Colors.white70 : Colors.grey[600]),
                onPressed: () => _startCall('video'),
              ),
              IconButton(
                icon: Icon(Icons.info_outline, color: isDark ? Colors.white70 : Colors.grey[600]),
                onPressed: () {
                  if (widget.otherUser != null) {
                    Navigator.push(
                      context,
                      ConstrainedSlideRightRoute(
                        page: ContactInfoScreen(user: widget.otherUser!),
                        leftOffset: 400.0, // Sidebar width
                      ),
                    );
                  }
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.grey[600]),
                onSelected: (value) async {
                  switch (value) {
                    case 'search':
                      Navigator.push(
                        context,
                        ConstrainedSlideRightRoute(
                          page: SearchInChatScreen(
                            conversationId: widget.conversationId,
                            title: widget.contactName,
                          ),
                          leftOffset: 400.0, // Sidebar width
                        ),
                      );
                      break;
                    case 'media':
                      Navigator.push(
                        context,
                        ConstrainedSlideRightRoute(
                          page: MediaGalleryScreen(
                            conversationId: widget.conversationId,
                            title: widget.contactName,
                          ),
                          leftOffset: 400.0, // Sidebar width
                        ),
                      );
                      break;
                    case 'clear':
                      await _clearChat(context);
                      break;
                    case 'export':
                      await _exportChat(context);
                      break;
                    case 'delete':
                      await _deleteChat(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'search', child: Text('Search')),
                  const PopupMenuItem(value: 'media', child: Text('Media')),
                  const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
                  const PopupMenuItem(value: 'export', child: Text('Export chat')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete chat')),
                ],
              ),
            ],
          ),
        ),

        // Messages List with drag and drop support
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(isDark 
                    ? 'assets/images/chatbg2.jpg' 
                    : 'assets/images/chatbg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: DropTarget(
              onDragDone: (detail) {
                setState(() {
                  _attachments.addAll(
                    detail.files
                        .where((file) => file.path != null)
                        .map((file) => File(file.path!))
                        .toList(),
                  );
                  _isDragging = false;
                });
              },
              onDragEntered: (detail) {
                setState(() {
                  _isDragging = true;
                });
              },
              onDragExited: (detail) {
                setState(() {
                  _isDragging = false;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDark 
                      ? const Color(0xFF111B21).withOpacity(_isDragging ? 0.70 : 0.85)
                      : Colors.white.withOpacity(_isDragging ? 0.70 : 0.85),
                  border: _isDragging
                      ? Border.all(
                          color: const Color(0xFF008069),
                          width: 3,
                        )
                      : null,
                ),
                child: RefreshIndicator(
                  onRefresh: _loadMessages,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isDragging 
                                      ? 'Drop files here to send'
                                      : 'No messages yet. Start a conversation!',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.grey[600],
                                    fontSize: _isDragging ? 18 : 14,
                                    fontWeight: _isDragging ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                if (_isDragging) ...[
                                  const SizedBox(height: 16),
                                  Icon(
                                    Icons.cloud_upload,
                                    size: 48,
                                    color: const Color(0xFF008069),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _buildMessageList().length,
                            itemBuilder: (context, index) {
                              return _buildMessageList()[index];
                            },
                          ),
                ),
              ),
            ),
          ),
        ),

        // Reply Preview
        if (_replyingToMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _replyingToMessage!.senderId == _currentUserId ? 'You' : widget.contactName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _replyingToMessage!.body.isNotEmpty
                            ? (_replyingToMessage!.body.length > 50
                                ? '${_replyingToMessage!.body.substring(0, 50)}...'
                                : _replyingToMessage!.body)
                            : (_replyingToMessage!.attachments.isNotEmpty
                                ? 'Attachment'
                                : 'Message'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _clearReply,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ],
            ),
          ),

        // Attachments Preview
        if (_attachments.isNotEmpty)
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                  width: 1,
                ),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _attachments.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _attachments[index].path.toLowerCase().endsWith('.mp3') ||
                                  _attachments[index].path.toLowerCase().endsWith('.wav') ||
                                  _attachments[index].path.toLowerCase().endsWith('.m4a') ||
                                  _attachments[index].path.toLowerCase().endsWith('.ogg') ||
                                  _attachments[index].path.toLowerCase().endsWith('.aac')
                              ? Icons.audiotrack
                              : Icons.insert_drive_file,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeAttachment(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Message Input
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202C33) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.emoji_emotions_outlined,
                    color: isDark ? Colors.white70 : Colors.grey[600]),
                onPressed: () {
                  setState(() {
                    _showEmojiPicker = !_showEmojiPicker;
                  });
                },
              ),
              IconButton(
                icon: Icon(_isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording 
                        ? Colors.red 
                        : (isDark ? Colors.white70 : Colors.grey[600])),
                onPressed: _recordAudio,
                tooltip: _isRecording ? 'Stop Recording' : 'Record Audio',
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.attach_file, color: isDark ? Colors.white70 : Colors.grey[600]),
                onSelected: (value) async {
                  switch (value) {
                    case 'photo_video':
                      await _pickPhotoOrVideo();
                      break;
                    case 'file':
                      await _pickFiles();
                      break;
                    case 'location':
                      await _shareLocation();
                      break;
                    case 'contact':
                      await _shareContact();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'photo_video', child: Row(
                    children: [
                      Icon(Icons.photo_library),
                      SizedBox(width: 8),
                      Text('Photo or Video'),
                    ],
                  )),
                  const PopupMenuItem(value: 'file', child: Row(
                    children: [
                      Icon(Icons.insert_drive_file),
                      SizedBox(width: 8),
                      Text('Document'),
                    ],
                  )),
                  const PopupMenuItem(value: 'location', child: Row(
                    children: [
                      Icon(Icons.location_on),
                      SizedBox(width: 8),
                      Text('Location'),
                    ],
                  )),
                  const PopupMenuItem(value: 'contact', child: Row(
                    children: [
                      Icon(Icons.contact_phone),
                      SizedBox(width: 8),
                      Text('Contact'),
                    ],
                  )),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Formatting toolbar (shown when text is selected)
                    if (_showFormattingToolbar)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: TextFormattingToolbar(
                          onFormat: (formatType) {
                            _applyTextFormatting(formatType);
                          },
                          onClose: () {
                            setState(() {
                              _showFormattingToolbar = false;
                              // Clear selection
                              _messageController.selection = TextSelection.collapsed(
                                offset: _messageController.selection.baseOffset,
                              );
                            });
                          },
                        ),
                      ),
                    // Text field
                    SelectionArea(
                      child: Shortcuts(
                        shortcuts: {
                          LogicalKeySet(LogicalKeyboardKey.enter): const _SendMessageIntent(),
                          LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.enter): const _NewLineIntent(),
                        },
                        child: Actions(
                          actions: {
                            _SendMessageIntent: CallbackAction<_SendMessageIntent>(
                              onInvoke: (_) {
                                if (_messageController.text.trim().isNotEmpty) {
                                  setState(() {
                                    _showQuickReplySuggestions = false;
                                  });
                                  _sendMessage();
                                }
                                return null;
                              },
                            ),
                            _NewLineIntent: CallbackAction<_NewLineIntent>(
                              onInvoke: (_) {
                                // Allow default behavior (new line)
                                return null;
                              },
                            ),
                          },
                          child: Focus(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                hintText: 'Type a message (Enter to send, Shift+Enter for new line)',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2A3942) : const Color(0xFFF0F2F5),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onChanged: (_) {
                                // Trigger quick reply suggestions when text changes
                                _onMessageChanged();
                                // Check selection after text change
                                _checkTextSelection();
                              },
                              onSubmitted: (_) {
                                // Enter pressed: send message
                                if (_messageController.text.trim().isNotEmpty) {
                                  setState(() {
                                    _showQuickReplySuggestions = false;
                                  });
                                  _sendMessage();
                                }
                              },
                              textInputAction: TextInputAction.newline,
                              keyboardType: TextInputType.multiline,
                              onTap: () {
                                // Keep suggestions visible on tap if "/" is in text
                                _onMessageChanged();
                                // Check selection after tap
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  _checkTextSelection();
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_isRecording)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRecordingWave(),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_recordingDuration),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        ),
                      ],
                    ),
                  ),
                )
              else
                CircleAvatar(
                  backgroundColor: const Color(0xFF008069),
                  child: IconButton(
                    icon: _isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: _uploadProgress > 0 && _uploadProgress < 1.0
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: _uploadProgress,
                                        strokeWidth: 2,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                        backgroundColor: Colors.white30,
                                      ),
                                      Text(
                                        '${(_uploadProgress * 100).toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                    tooltip: 'Send Message',
                  ),
                ),
            ],
              ),
            ),
            if (_showQuickReplySuggestions && _filteredQuickReplies.isNotEmpty)
              Positioned(
                bottom: 70,
                left: 16,
                right: 16,
                child: _buildQuickReplySuggestions(isDark),
              ),
          ],
        ),

        // Emoji Picker
        if (_showEmojiPicker)
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                  width: 1,
                ),
              ),
            ),
            child: EmojiPickerWidget(
              onEmojiSelected: (emoji) {
                final currentText = _messageController.text;
                _messageController.text = currentText + emoji;
                _messageController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _messageController.text.length),
                );
              },
              onBackspace: () {
                final currentText = _messageController.text;
                if (currentText.isNotEmpty) {
                  _messageController.text = currentText.substring(0, currentText.length - 1);
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _messageController.text.length),
                  );
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQuickReplySuggestions(bool isDark) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: isDark ? const Color(0xFF202C33) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202C33) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3942) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _filteredQuickReplies.length > 5 ? 5 : _filteredQuickReplies.length,
          itemBuilder: (context, index) {
            final quickReply = _filteredQuickReplies[index];
            return ListTile(
              dense: true,
              title: Text(
                quickReply.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                quickReply.message.length > 50 
                    ? '${quickReply.message.substring(0, 50)}...' 
                    : quickReply.message,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                _insertQuickReply(quickReply);
              },
            );
          },
        ),
      ),
    );
  }
}

// Audio preview widget for voice recording playback (Desktop)
class VideoPreviewWidget extends StatefulWidget {
  final File file;

  const VideoPreviewWidget({required this.file});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.file);
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        IconButton(
          icon: Icon(
            _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
          onPressed: () {
            setState(() {
              if (_controller!.value.isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
            });
          },
        ),
      ],
    );
  }
}

class DesktopAudioPreviewWidget extends StatefulWidget {
  final String audioPath;
  final Duration duration;
  final AudioPlayer audioPlayer;

  const DesktopAudioPreviewWidget({
    required this.audioPath,
    required this.duration,
    required this.audioPlayer,
  });

  @override
  @override
  State<DesktopAudioPreviewWidget> createState() => DesktopAudioPreviewWidgetState();
}

class DesktopAudioPreviewWidgetState extends State<DesktopAudioPreviewWidget> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _totalDuration = widget.duration;
    _setupListeners();
  }

  void _setupListeners() {
    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    widget.audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    widget.audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await widget.audioPlayer.pause();
    } else {
      await widget.audioPlayer.play(DeviceFileSource(widget.audioPath));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _togglePlayback,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  Slider(
                    value: _position.inMilliseconds.toDouble(),
                    min: 0,
                    max: _totalDuration.inMilliseconds > 0
                        ? _totalDuration.inMilliseconds.toDouble()
                        : widget.duration.inMilliseconds.toDouble(),
                    onChanged: (value) async {
                      await widget.audioPlayer.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        _formatDuration(_totalDuration > Duration.zero
                            ? _totalDuration
                            : widget.duration),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.audioPlayer.stop();
    super.dispose();
  }
}


