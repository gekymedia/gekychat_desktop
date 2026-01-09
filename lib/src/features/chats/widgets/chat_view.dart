import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationPermission, LocationAccuracy, Position;
import 'package:path_provider/path_provider.dart';
import '../chat_repo.dart';
import '../models.dart';
import 'message_bubble.dart';
import '../../../core/providers.dart';
import '../../contacts/contacts_repository.dart' show contactsRepositoryProvider;
import 'emoji_picker_widget.dart';
import '../../media/media_gallery_screen.dart';
import 'search_in_chat_screen.dart';
import '../../contacts/contact_info_screen.dart';
import '../../quick_replies/quick_replies_repository.dart' show QuickReply, quickRepliesRepositoryProvider;
import '../../quick_replies/quick_replies_repository.dart';
import '../../../theme/app_theme.dart';
import '../../calls/call_screen.dart';
import '../../calls/providers.dart';

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
  bool _isTyping = false;
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

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadMessages();
    _setupRealtimeListener();
    _loadQuickReplies();
    _messageController.addListener(_onMessageChanged);
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
    pusherService.subscribePrivate(channelName, (data) {
      // Handle real-time updates
      if (mounted && data != null) {
        _handleRealtimeUpdate(data);
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
        } catch (e) {
          debugPrint('Error handling real-time message: $e');
        }
      }
    });
  }
  
  void _handleRealtimeUpdate(dynamic data) {
    // Handle various real-time events (typing, read receipts, etc.)
    if (data is Map<String, dynamic> && data['type'] == 'typing') {
      setState(() {
        _isTyping = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
        }
      });
    }
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
    });

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final newMessage = await chatRepo.sendMessageToConversation(
        conversationId: widget.conversationId,
        body: message.isEmpty ? null : message,
        replyTo: _replyingToId,
        attachments: _attachments.isNotEmpty ? _attachments : null,
      );
      
      setState(() {
        _messages.add(newMessage);
        _messageController.clear();
        _attachments.clear();
        _replyingToId = null;
        _replyingToMessage = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'txt', 'zip', 'rar'],
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
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });

      if (path != null && mounted) {
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
                _DesktopAudioPreviewWidget(
                  audioPath: path,
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
          setState(() {
            _attachments.add(File(path));
          });
        } else {
          // Delete the recording file
          try {
            final file = File(path);
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

        // Note: Reverse geocoding (getting address from coordinates) requires the geocoding package
        // For now, we'll just use coordinates. To enable address lookup, add geocoding package.
        String? address;

        setState(() {
          _isSending = true;
        });

        final chatRepo = ref.read(chatRepositoryProvider);
        final newMessage = await chatRepo.shareLocationInConversation(
          widget.conversationId,
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          placeName: null,
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
    // Show contact picker
    final contacts = await ref.read(contactsRepositoryProvider).listContacts();
    
    if (!mounted) return;
    
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Contact'),
        content: SizedBox(
          width: 300,
          child: contacts.isEmpty
              ? const Text('No contacts available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(contact.name.isNotEmpty ? contact.name[0] : '?'),
                      ),
                      title: Text(contact.name),
                      subtitle: contact.phone != null ? Text(contact.phone!) : null,
                      onTap: () => Navigator.pop(context, contact.id),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
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
      // Reload messages to get updated reactions
      _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to react: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.deleteMessage(message.id);
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
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
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.contactAvatar != null
                    ? CachedNetworkImageProvider(widget.contactAvatar!)
                    : null,
                child: widget.contactAvatar == null
                    ? Text(widget.contactName[0], style: const TextStyle(fontSize: 16))
                    : null,
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
                    if (_isTyping)
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
                      MaterialPageRoute(
                        builder: (context) => ContactInfoScreen(user: widget.otherUser!),
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
                        MaterialPageRoute(
                          builder: (context) => SearchInChatScreen(
                            conversationId: widget.conversationId,
                            title: widget.contactName,
                          ),
                        ),
                      );
                      break;
                    case 'media':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MediaGalleryScreen(
                            conversationId: widget.conversationId,
                            title: widget.contactName,
                          ),
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

        // Messages List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet. Start a conversation!',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return MessageBubble(
                          message: message,
                          currentUserId: _currentUserId ?? 0,
                          onDelete: () => _deleteMessage(message),
                          onReply: () => _setReply(message),
                          onReact: (emoji) => _reactToMessage(message, emoji),
                          onEdit: (newBody) => _editMessage(message, newBody),
                        );
                      },
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
                    color: isDark ? Colors.white70 : Colors.grey[600]),
                onPressed: _recordAudio,
                tooltip: _isRecording ? 'Stop Recording' : 'Record Audio',
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.attach_file, color: isDark ? Colors.white70 : Colors.grey[600]),
                onSelected: (value) async {
                  switch (value) {
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
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Type a message',
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
                  },
                  onSubmitted: (_) {
                    setState(() {
                      _showQuickReplySuggestions = false;
                    });
                    _sendMessage();
                  },
                  onTap: () {
                    // Keep suggestions visible on tap if "/" is in text
                    _onMessageChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (_isRecording)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_recordingDuration),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.red,
                      child: IconButton(
                        icon: const Icon(Icons.stop, color: Colors.white),
                        onPressed: _stopRecording,
                      ),
                    ),
                  ],
                )
              else
                CircleAvatar(
                  backgroundColor: const Color(0xFF008069),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
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
class _DesktopAudioPreviewWidget extends StatefulWidget {
  final String audioPath;
  final Duration duration;
  final AudioPlayer audioPlayer;

  const _DesktopAudioPreviewWidget({
    required this.audioPath,
    required this.duration,
    required this.audioPlayer,
  });

  @override
  State<_DesktopAudioPreviewWidget> createState() => _DesktopAudioPreviewWidgetState();
}

class _DesktopAudioPreviewWidgetState extends State<_DesktopAudioPreviewWidget> {
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


