import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../chat_repo.dart';
import '../models.dart';
import 'message_bubble.dart';
import 'emoji_picker_widget.dart';
import 'chat_view.dart' show DesktopAudioPreviewWidget, VideoPreviewWidget;
import '../../../theme/app_theme.dart';
import '../../contacts/contacts_repository.dart';
import 'group_info_screen.dart'; // Provides groupInfoProvider
import '../../../widgets/constrained_slide_route.dart';
import '../../media/media_gallery_screen.dart';
import 'search_in_chat_screen.dart';
import '../../calls/call_screen.dart';
import '../../calls/providers.dart';
import 'text_formatting_toolbar.dart';
import '../../../utils/text_formatting.dart';

class GroupChatView extends ConsumerStatefulWidget {
  final int groupId;
  final String groupName;
  final String? groupAvatarUrl;
  final List<String> memberNames;
  final int? memberCount;

  const GroupChatView({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatarUrl,
    this.memberNames = const [],
    this.memberCount,
  });

  @override
  ConsumerState<GroupChatView> createState() => _GroupChatViewState();
}

class _GroupChatViewState extends ConsumerState<GroupChatView> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final List<Message> _messages = [];
  final List<File> _attachments = [];
  bool _isLoading = false;
  bool _isSending = false;
  double _uploadProgress = 0.0;
  bool _showEmojiPicker = false;
  int? _currentUserId;
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
    // Listen for selection changes
    _messageController.addListener(_checkTextSelection);
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
    });
  }

  @override
  void dispose() {
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
      final messages = await chatRepo.getGroupMessages(widget.groupId);
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
      _uploadProgress = 0.0;
    });

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final newMessage = await chatRepo.sendMessageToGroup(
        groupId: widget.groupId,
        body: message.isEmpty ? null : message,
        attachments: _attachments.isNotEmpty ? _attachments : null,
        replyToId: _replyingToId,
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
        _messageController.clear();
        _attachments.clear();
        _replyingToId = null;
        _replyingToMessage = null;
      });
      _scrollToBottom();
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
                DesktopAudioPreviewWidget(
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
          // Send voice message immediately instead of adding to attachments
          await _sendVoiceMessage(path);
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

  Future<void> _sendVoiceMessage(String audioPath) async {
    setState(() {
      _isSending = true;
    });

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      // Send voice message with no compression
      final newMessage = await chatRepo.sendMessageToGroup(
        groupId: widget.groupId,
        body: null,
        replyToId: _replyingToId,
        attachments: [File(audioPath)],
        skipCompression: true, // Voice messages shouldn't be compressed
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

  Future<void> _startCall(String type) async {
    try {
      final callManager = ref.read(callManagerProvider);
      await callManager.startCall(
        groupId: widget.groupId,
        type: type,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              call: callManager.currentCall!,
              userName: widget.groupName,
              userAvatar: widget.groupAvatarUrl,
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
        final newMessage = await chatRepo.shareLocationInGroup(
          widget.groupId,
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
        final newMessage = await chatRepo.shareContactInGroup(
          widget.groupId,
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


  Future<void> _replyPrivately(Message message) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final result = await chatRepo.replyPrivatelyToGroupMessage(widget.groupId, message.id);
      
      if (mounted) {
        // Show success message - user can find the conversation in their chat list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation opened with ${result['group_message_sender']}. Check your chats list.'),
            duration: const Duration(seconds: 3),
          ),
        );
        // Navigate back to chats tab to see the conversation
        context.go('/chats');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reply privately: $e')),
        );
      }
    }
  }

  Future<void> _reactToMessage(Message message, String emoji) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.reactToMessage(message.id, emoji, isGroupMessage: true);
      // Fetch only the updated message instead of reloading all messages
      final updatedMessage = await chatRepo.getGroupMessage(message.id);
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
                subtitle: const Text('Remove this message for all group members'),
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
          // Show deleted message indicator instead of removing
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            _messages.removeAt(index);
          }
        } else {
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

  Widget _buildGroupAvatar() {
    if (widget.groupAvatarUrl == null || widget.groupAvatarUrl!.isEmpty) {
      return const CircleAvatar(
        radius: 20,
        child: Icon(Icons.group, size: 20),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image(
          image: CachedNetworkImageProvider(widget.groupAvatarUrl!),
          fit: BoxFit.cover,
          width: 40,
          height: 40,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.group, size: 20),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupAsync = ref.watch(groupInfoProvider(widget.groupId));
    final isChannel = groupAsync.maybeWhen(
      data: (group) => group['type'] == 'channel',
      orElse: () => false,
    );

    return Column(
      children: [
        // Group Chat Header
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
              _buildGroupAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      isChannel
                          ? '${widget.memberCount ?? widget.memberNames.length} ${widget.memberCount == 1 ? 'follower' : 'followers'}'
                          : '${widget.memberCount ?? widget.memberNames.length} ${widget.memberCount == 1 ? 'member' : 'members'}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Commented out call buttons for channels temporarily
              if (!isChannel) ...[
                IconButton(
                  icon: Icon(Icons.call, color: isDark ? Colors.white70 : Colors.grey[600]),
                  onPressed: () => _startCall('voice'),
                ),
                IconButton(
                  icon: Icon(Icons.videocam, color: isDark ? Colors.white70 : Colors.grey[600]),
                  onPressed: () => _startCall('video'),
                ),
              ],
              IconButton(
                icon: Icon(Icons.info_outline, color: isDark ? Colors.white70 : Colors.grey[600]),
                onPressed: () {
                  Navigator.push(
                    context,
                    ConstrainedSlideRightRoute(
                      page: GroupInfoScreen(groupId: widget.groupId),
                      leftOffset: 400.0, // Sidebar width
                    ),
                  );
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
                            groupId: widget.groupId,
                            title: widget.groupName,
                          ),
                        ),
                      );
                      break;
                    case 'media':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MediaGalleryScreen(
                            groupId: widget.groupId,
                            title: widget.groupName,
                          ),
                        ),
                      );
                      break;
                    case 'group_info':
                      Navigator.push(
                        context,
                        ConstrainedSlideRightRoute(
                          page: GroupInfoScreen(groupId: widget.groupId),
                          leftOffset: 400.0, // Sidebar width
                        ),
                      );
                      break;
                    case 'mute':
                      // Mute/unmute group notifications
                      try {
                        final chatRepo = ref.read(chatRepositoryProvider);
                        // Check if group is muted (would need to get group info)
                        // For now, mute for 24 hours
                        await chatRepo.muteGroup(widget.groupId, minutes: 1440);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Group muted for 24 hours')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to mute group: $e')),
                          );
                        }
                      }
                      break;
                    case 'archive':
                      // Groups don't have archive endpoints - only conversations do
                      // Remove this option or show info message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Group archiving is not available. You can leave the group instead.')),
                        );
                      }
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'search', child: Row(
                    children: [
                      Icon(Icons.search, size: 20),
                      SizedBox(width: 8),
                      Text('Search'),
                    ],
                  )),
                  const PopupMenuItem(value: 'media', child: Row(
                    children: [
                      Icon(Icons.photo_library, size: 20),
                      SizedBox(width: 8),
                      Text('Media'),
                    ],
                  )),
                  const PopupMenuItem(value: 'group_info', child: Row(
                    children: [
                      Icon(Icons.info, size: 20),
                      SizedBox(width: 8),
                      Text('Group Info'),
                    ],
                  )),
                  const PopupMenuItem(value: 'mute', child: Row(
                    children: [
                      Icon(Icons.notifications_off, size: 20),
                      SizedBox(width: 8),
                      Text('Mute Notifications'),
                    ],
                  )),
                  const PopupMenuItem(value: 'archive', child: Row(
                    children: [
                      Icon(Icons.archive, size: 20),
                      SizedBox(width: 8),
                      Text('Archive'),
                    ],
                  )),
                ],
              ),
            ],
          ),
        ),

        // Messages List with drag and drop support
        Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMessages,
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
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return MessageBubble(
                                message: message,
                                currentUserId: _currentUserId ?? 0,
                                onDelete: () => _deleteMessage(message),
                                onReplyPrivately: () => _replyPrivately(message),
                                onReact: (emoji) => _reactToMessage(message, emoji),
                                onEdit: (newBody) => _editMessage(message, newBody),
                                isGroupMessage: true,
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
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
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.insert_drive_file),
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
                        onSubmitted: (_) => _sendMessage(),
                        onTap: () {
                          Future.delayed(const Duration(milliseconds: 50), () {
                            _checkTextSelection();
                          });
                        },
                        onChanged: (_) {
                          _checkTextSelection();
                        },
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
                  ),
                ),
            ],
          ),
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
}



