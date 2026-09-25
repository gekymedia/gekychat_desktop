import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationPermission, LocationAccuracy, Position;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';
import '../../../services/video_compression_service.dart';
import 'desktop_media_preview_dialog.dart';
import '../chat_providers.dart';
import '../providers/typing_status_provider.dart';
import '../sidebar_inbox_bump.dart';
import '../../calls/call_repository.dart';
import '../../calls/joinable_call_message.dart';
import '../sidebar_inbox_bump.dart';
import '../../contacts/contacts_repository.dart';
import '../forward_message_screen.dart';
import 'message_bubble.dart';
import 'date_divider.dart';
import 'typing_indicator_bubble.dart';
import '../../../utils/json_coercion.dart';
import '../../../utils/clipboard_media_helper.dart';
import 'chat_attachment_thumb.dart';
import '../../../core/providers.dart';
import '../../realtime/pusher_service.dart';
import '../../../realtime/pusher_message_payload.dart';
import '../../../services/inbox_realtime_sync.dart';
import '../../../services/message_sync_service.dart';
import '../../../services/bot_contact_registry.dart';
import '../chat_repo.dart';
import '../../../core/services/taskbar_badge_service.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../contacts/contacts_repository.dart' show contactsRepositoryProvider;
import 'desktop_emoji_picker_popup.dart';
import 'desktop_voice_recording.dart';
import '../../media/media_gallery_screen.dart';
import 'search_in_chat_screen.dart';
import '../../contacts/contact_info_screen.dart';
import 'chat_side_panel_layout.dart';
import '../../../widgets/constrained_slide_route.dart';
import '../../quick_replies/quick_replies_repository.dart' show QuickReply, quickRepliesRepositoryProvider;
import '../../quick_replies/quick_replies_repository.dart';
import '../../../theme/app_theme.dart';
import '../../calls/call_navigation.dart';
import '../../calls/livekit_call_screen.dart';
import '../../calls/call_busy_helper.dart';
import '../../calls/providers.dart';
import 'chat_joinable_call_banner.dart';
import '../../calls/incoming_call_handler.dart';
import 'text_formatting_toolbar.dart';
import '../../../utils/text_formatting.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../widgets/gekychat_doodle_background.dart';
import '../../../widgets/desktop_shell_colors.dart';
import '../../../widgets/desktop_typography.dart';
import '../../../widgets/desktop_voice_permission.dart';
import '../../../widgets/desktop_microphone_permission_dialog.dart';
import '../../status/desktop_status_viewer.dart';
import '../../status/models.dart' show StatusSummary, StatusType, StatusUpdate;
import 'chat_attachment_menu_sheet.dart';
import 'share_contact_picker.dart';
import 'poll_composer_sheet.dart';
import 'desktop_composer_trailing_action.dart';
import 'desktop_message_composer_pill.dart';
import 'desktop_chat_metrics.dart';
import '../../embedded_apps/embedded_app_launcher.dart';
import '../../sika/sika_send_coins_sheet.dart';
import '../../../widgets/batch_selection_mode.dart';
import '../../../utils/snackbar_helper.dart';

class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
}

class _NewLineIntent extends Intent {
  const _NewLineIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

/// Slot type for message list: date divider or message (avoids building full list N+1 times).
abstract class _MessageSlot {
  const _MessageSlot();
}
class _DateSlot extends _MessageSlot {
  final DateTime date;
  const _DateSlot(this.date);
}
class _MessageBubbleSlot extends _MessageSlot {
  final Message message;
  const _MessageBubbleSlot(this.message);
}

class ChatView extends ConsumerStatefulWidget {
  final int conversationId;
  final String contactName;
  final String? contactAvatar;
  final User? otherUser; // Add User object for status info
  final bool isSavedMessages;
  final int? initialScrollToMessageId;
  final VoidCallback? onInitialScrollConsumed;

  const ChatView({
    super.key,
    required this.conversationId,
    required this.contactName,
    this.contactAvatar,
    this.otherUser,
    this.isSavedMessages = false,
    this.initialScrollToMessageId,
    this.onInitialScrollConsumed,
  });

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final List<Message> _messages = [];
  final List<File> _attachments = [];
  /// When true, next send with attachments sets API `view_once` on the message.
  bool _attachmentsViewOnce = false;
  bool _isLoading = false;
  bool _isSending = false;
  double _uploadProgress = 0.0;
  bool _isTyping = false;
  bool _otherUserRecording = false;
  int? _currentUserId;
  bool _hasMoreOlder = true;
  bool _loadingOlder = false;
  static const double _loadOlderThreshold = 200;
  bool _otherUserIsBot = false;
  int? _highlightedMessageId;
  
  // Quick replies
  List<QuickReply> _quickReplies = [];
  List<QuickReply> _filteredQuickReplies = [];
  bool _showQuickReplySuggestions = false;
  
  // Reply to message
  int? _replyingToId;
  Message? _replyingToMessage;
  PendingStatusReply? _pendingStatusReply;
  PendingGroupMessageReply? _pendingGroupMessageReply;

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  /// Notifier so only the recording row rebuilds every second, not the whole chat.
  final ValueNotifier<Duration> _recordingDurationNotifier = ValueNotifier<Duration>(Duration.zero);

  final _pusherListeners = PusherListenerRegistry();
  PusherService? _pusherService;
  
  // Drag and drop
  bool _isDragging = false;

  void _setDragging(bool dragging) {
    if (_isDragging == dragging) return;
    setState(() => _isDragging = dragging);
  }

  /// Stable host for the chat column — survives info-panel open/close.
  final GlobalKey _chatBodyKey = GlobalKey();

  void _sortMessagesInPlace() {
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  
  // Text formatting
  bool _showFormattingToolbar = false;
  bool _showInfoPanel = false;
  bool _composerShowSend = false;
  User? _peerUser;
  Timer? _markReadDebounce;
  Timer? _dmTypingDebounce;
  Timer? _presencePollTimer;
  bool _dmTypingActive = false;
  final _messageSelection = BatchSelectionManager<int>();

  @override
  void initState() {
    super.initState();
    _peerUser = widget.otherUser;
    unawaited(ref.read(botContactRegistryProvider).ensureLoaded());
    _syncBotFlag(notify: false);
    _loadCurrentUserId();
    _loadMessages();
    _setupRealtimeListener();
    _loadQuickReplies();
    _refreshPeerProfile();
    _presencePollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted || widget.isSavedMessages || _otherUserIsBot) return;
      unawaited(_refreshPeerProfile());
    });
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onMessageChanged);
    _messageController.addListener(_syncComposerTrailing);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(typingStatusProvider.notifier)
          .subscribeToConversation(widget.conversationId);
    });
    // Listen for selection changes
    _messageController.addListener(_checkTextSelection);
    _messageSelection.addListener(_onMessageSelectionChanged);
    // Ensure recording state is false on init
    _isRecording = false;
  }
  
  Future<void> _refreshPeerProfile() async {
    if (widget.isSavedMessages) return;
    final other = widget.otherUser ?? _peerUser;
    if (other == null || other.id <= 0) return;
    if (_otherUserIsBot) return;
    try {
      final profile =
          await ref.read(contactsRepositoryProvider).getUserProfile(other.id);
      if (!mounted) return;
      final lastSeen =
          profile.user.lastSeenAt?.toLocal() ?? other.lastSeenAt?.toLocal();
      // Match conversation API: treat recent last_seen as online when cache flag lags.
      final recentlyActive = lastSeen != null &&
          DateTime.now().difference(lastSeen) < const Duration(minutes: 5);
      setState(() {
        _peerUser = User(
          id: profile.user.id,
          name: other.name.isNotEmpty &&
                  other.name != 'Unknown' &&
                  !other.name.startsWith('DM #')
              ? other.name
              : profile.user.name,
          phone: profile.user.phone ?? other.phone,
          avatarUrl: profile.user.avatarUrl ?? other.avatarUrl,
          isOnline: profile.user.isOnline == true || recentlyActive,
          lastSeenAt: lastSeen,
        );
        _syncBotFlag();
      });
    } catch (e) {
      debugPrint('chat_view: refresh peer profile: $e');
    }
  }

  /// Peer is active in this chat — keep header presence in sync.
  void _touchPeerPresence({DateTime? at, bool markOnline = true}) {
    if (widget.isSavedMessages || _otherUserIsBot) return;
    final peer = _effectiveOtherUser;
    if (peer == null || peer.id <= 0) return;
    final stamp = (at ?? DateTime.now()).toLocal();
    final prev = peer.lastSeenAt;
    if (!markOnline &&
        prev != null &&
        !stamp.isAfter(prev) &&
        peer.isOnline != true) {
      return;
    }
    setState(() {
      _peerUser = User(
        id: peer.id,
        name: peer.name,
        phone: peer.phone,
        avatarUrl: peer.avatarUrl,
        isOnline: markOnline ? true : peer.isOnline,
        lastSeenAt: prev == null || stamp.isAfter(prev) ? stamp : prev,
      );
    });
  }

  DateTime? _effectiveLastSeenForSubtitle() {
    final peer = _effectiveOtherUser;
    final ls = peer?.lastSeenAt?.toLocal();
    if (peer == null || peer.id <= 0) return ls;
    DateTime? latestPeerMessage;
    for (final m in _messages) {
      if (m.isSystem) continue;
      if (m.senderId != peer.id) continue;
      if (latestPeerMessage == null || m.createdAt.isAfter(latestPeerMessage)) {
        latestPeerMessage = m.createdAt.toLocal();
      }
    }
    if (latestPeerMessage == null) return ls;
    if (ls == null) return latestPeerMessage;
    return latestPeerMessage.isAfter(ls) ? latestPeerMessage : ls;
  }

  User? get _effectiveOtherUser => _peerUser ?? widget.otherUser;

  void _onMessageSelectionChanged() {
    if (mounted) setState(() {});
  }

  List<Message> get _selectedMessages {
    final ids = _messageSelection.selectedItems.toSet();
    return _messages.where((m) => ids.contains(m.id)).toList();
  }

  bool get _selectionIsCallOnly =>
      _selectedMessages.isNotEmpty &&
      _selectedMessages.every(Message.isCallMessage);

  void _enterMessageSelection(Message message) {
    if (!_messageSelection.isSelectionMode) {
      _messageSelection.enterSelectionMode();
    }
    _toggleMessageSelection(message);
  }

  void _toggleMessageSelection(Message message) {
    final next = _messageSelection.selectedItems.toSet();
    toggleChatBubbleSelection(
      selectedIds: next,
      message: message,
      allMessages: _messages,
    );
    _applyMessageSelection(next);
  }

  void _applyMessageSelection(Set<int> next) {
    final current = _messageSelection.selectedItems.toSet();
    if (next.isEmpty) {
      _messageSelection.exitSelectionMode();
      return;
    }
    for (final id in current.difference(next)) {
      if (_messageSelection.isSelected(id)) {
        _messageSelection.toggleSelection(id);
      }
    }
    if (!_messageSelection.isSelectionMode) {
      _messageSelection.enterSelectionMode();
    }
    final afterRemoves = _messageSelection.selectedItems.toSet();
    for (final id in next.difference(afterRemoves)) {
      if (!_messageSelection.isSelected(id)) {
        _messageSelection.toggleSelection(id);
      }
    }
  }

  Future<void> _pinMessage(Message message, bool pin) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      if (pin) {
        await chatRepo.pinMessageInConversation(widget.conversationId, message.id);
        if (mounted) {
          context.showSuccessToast('Message pinned');
        }
      } else {
        await chatRepo.unpinMessageInConversation(widget.conversationId);
        if (mounted) {
          context.showSuccessToast('Message unpinned');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to pin message: $e');
      }
    }
  }

  void _syncBotFlag({bool notify = true}) {
    final other = _effectiveOtherUser ?? widget.otherUser;
    if (other == null) {
      if (_otherUserIsBot) {
        if (notify && mounted) {
          setState(() => _otherUserIsBot = false);
        } else {
          _otherUserIsBot = false;
        }
      }
      return;
    }
    final registry = ref.read(botContactRegistryProvider);
    final isBot = registry.isBot(userId: other.id, phone: other.phone);
    if (isBot != _otherUserIsBot) {
      if (notify && mounted) {
        setState(() => _otherUserIsBot = isBot);
      } else {
        _otherUserIsBot = isBot;
      }
    }
  }

  Future<void> _openInfoPanel() async {
    if (widget.isSavedMessages) {
      if (mounted) setState(() => _showInfoPanel = true);
      return;
    }
    if (_effectiveOtherUser != null) {
      if (mounted) setState(() => _showInfoPanel = true);
      return;
    }
    try {
      final conversation = await ref
          .read(chatRepositoryProvider)
          .getConversation(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _peerUser = conversation.otherUser;
        _showInfoPanel = true;
      });
    } catch (e) {
      debugPrint('chat_view: open info panel: $e');
      if (!mounted) return;
      setState(() {
        _peerUser = User(
          id: 0,
          name: widget.contactName,
          avatarUrl: widget.contactAvatar,
        );
        _showInfoPanel = true;
      });
    }
  }

  void _syncComposerTrailing() {
    if (!mounted) return;
    final next =
        _messageController.text.trim().isNotEmpty || _attachments.isNotEmpty;
    if (next != _composerShowSend) {
      setState(() => _composerShowSend = next);
    }
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
    if (oldWidget.conversationId != widget.conversationId) {
      _loadMessages();
      _setupRealtimeListener();
      _syncBotFlag();
    } else if (widget.initialScrollToMessageId != null &&
        widget.initialScrollToMessageId != oldWidget.initialScrollToMessageId) {
      _scheduleScrollAfterLoad(targetId: widget.initialScrollToMessageId);
    }
    if (oldWidget.otherUser?.id != widget.otherUser?.id ||
        oldWidget.otherUser?.phone != widget.otherUser?.phone) {
      _syncBotFlag();
    }
  }

  void _setupRealtimeListener() {
    _pusherListeners.removeAll(_pusherService);
    final pusherService = ref.read(pusherServiceProvider);
    _pusherService = pusherService;
    pusherService.connect();
    
    // Subscribe to conversation channel
    final channelName = 'conversation.${widget.conversationId}';
    
    // Listen for typing events - use correct event name and data structure
    _pusherListeners.listen(pusherService, channelName, 'UserTyping', (data) {
      if (!mounted || data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final userId = asInt(map['user_id']);
      final isTyping = map['is_typing'] == true ||
          map['is_typing'] == 1 ||
          map['is_typing'] == '1';
      final otherId = _effectiveOtherUser?.id;

      final isFromOther = otherId != null
          ? userId == otherId
          : (userId != null && userId != _currentUserId);
      if (!isFromOther) return;

      if (isTyping) {
        setState(() => _isTyping = true);
        _touchPeerPresence();
        _scrollToBottom();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isTyping = false);
        });
      } else if (mounted) {
        setState(() => _isTyping = false);
      }
    });
    
    // Listen for recording events
    _pusherListeners.listen(pusherService, channelName, 'UserRecording', (data) {
      if (!mounted || data == null || data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final userId = asInt(map['user_id']);
      final isRecording = map['is_recording'] == true ||
          map['is_recording'] == 1 ||
          map['is_recording'] == '1';
      final otherId = _effectiveOtherUser?.id;

      final isFromOther = otherId != null
          ? userId == otherId
          : (userId != null && userId != _currentUserId);
      if (!isFromOther) return;

      setState(() => _otherUserRecording = isRecording);
      if (isRecording) {
        _touchPeerPresence();
        _scrollToBottom();
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) setState(() => _otherUserRecording = false);
        });
      }
    });
    
    // Listen for new messages
    _pusherListeners.listen(pusherService, channelName, 'MessageSent', (data) {
      if (mounted && data != null) {
        try {
          final raw = data is Map<String, dynamic>
              ? data
              : Map<String, dynamic>.from(data as Map);
          final messageMap = (raw['message'] is Map)
              ? mergeLaravelMessageBroadcastPayload(raw)
              : raw;
          _applyRealtimeMessage(messageMap);
        } catch (e) {
          debugPrint('Error handling real-time message: $e');
        }
      }
    });

    // Listen for message status updates.
    // The backend fires `MessageStatusUpdated` (via ReceiptUpdated) with
    // `message_id`, `delivered_at`, `read_at` — and sometimes a `status` string.
    _pusherListeners.listen(pusherService, channelName, 'MessageStatusUpdated', (data) {
      if (!mounted || data == null) return;
      try {
        final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
        final messageId = d['message_id'] as int?;
        if (messageId == null) return;
        final statusStr = d['status'] as String?;
        final rawReadAt = d['read_at'] as String?;
        final rawDelivAt = d['delivered_at'] as String?;
        _applyReceiptUpdate(messageId,
            statusStr: statusStr, rawReadAt: rawReadAt, rawDelivAt: rawDelivAt);
      } catch (e) {
        debugPrint('chat_view: MessageStatusUpdated error: $e');
      }
    });

    void onMessageDelivered(dynamic data) {
      if (!mounted || data == null) return;
      try {
        final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
        final rawDelivAt = d['delivered_at'] as String?;
        final ids = d['message_ids'];
        if (ids is List) {
          for (final id in ids) {
            final mid = id is int ? id : int.tryParse(id.toString());
            if (mid != null) {
              _applyReceiptUpdate(mid,
                  statusStr: 'delivered', rawDelivAt: rawDelivAt);
            }
          }
          return;
        }
        final messageId = d['message_id'] as int?;
        if (messageId == null) return;
        _applyReceiptUpdate(messageId,
            statusStr: 'delivered', rawDelivAt: rawDelivAt);
      } catch (e) {
        debugPrint('chat_view: message.delivered error: $e');
      }
    }

    _pusherListeners.listen(pusherService, channelName, 'message.delivered', onMessageDelivered);
    _pusherListeners.listen(pusherService, channelName, 'MessageDelivered', onMessageDelivered);

    // Backend also fires `message.read` (MessageRead event) with message_ids array.
    _pusherListeners.listen(pusherService, channelName, 'message.read', (data) {
      if (!mounted || data == null) return;
      try {
        final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
        final rawReadAt = d['read_at'] as String?;
        final ids = d['message_ids'];
        if (ids is List) {
          for (final id in ids) {
            _applyReceiptUpdate(id as int, statusStr: 'read', rawReadAt: rawReadAt);
          }
        }
      } catch (e) {
        debugPrint('chat_view: message.read error: $e');
      }
    });

    // Listen for message edits from the OTHER party.
    // Payload: id, body, edited_at, conversation_id
    _pusherListeners.listen(pusherService, channelName, 'MessageEdited', (data) {
      if (!mounted || data == null) return;
      try {
        final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
        final id = d['id'] as int?;
        final body = d['body'] as String?;
        final editedAtStr = d['edited_at'] as String?;
        if (id == null) return;
        final parsedEditedAt =
            editedAtStr != null ? DateTime.tryParse(editedAtStr) : null;
        unawaited(
          ref.read(chatRepositoryProvider).applyRemoteMessageEdit(
                messageId: id,
                body: body ?? '',
                editedAt: parsedEditedAt,
              ),
        );
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == id);
          if (idx != -1) {
            final old = _messages[idx];
            _messages[idx] = Message(
              id: old.id,
              clientId: old.clientId,
              conversationId: old.conversationId,
              groupId: old.groupId,
              senderId: old.senderId,
              sender: old.sender,
              body: body ?? old.body,
              createdAt: old.createdAt,
              editedAt: editedAtStr != null ? DateTime.tryParse(editedAtStr) : old.editedAt,
              replyToId: old.replyToId,
              forwardedFromId: old.forwardedFromId,
              forwardChain: old.forwardChain,
              attachments: old.attachments,
              reactions: old.reactions,
              callData: old.callData,
              linkPreviews: old.linkPreviews,
              isDeleted: old.isDeleted,
              deletedForMe: old.deletedForMe,
              status: old.status,
              isSystem: old.isSystem,
              systemAction: old.systemAction,
              readAt: old.readAt,
              deliveredAt: old.deliveredAt,
              locationData: old.locationData,
              contactData: old.contactData,
              mentionCount: old.mentionCount,
              mentions: old.mentions,
              messageType: old.messageType,
              isViewOnce: old.isViewOnce,
              viewOnceOpened: old.viewOnceOpened,
              sikaTransferData: old.sikaTransferData,
              scheduledAt: old.scheduledAt,
              referencedStatusId: old.referencedStatusId,
              referencedStatus: old.referencedStatus,
              referencedGroupId: old.referencedGroupId,
              referencedGroupMessageId: old.referencedGroupMessageId,
              referencedGroup: old.referencedGroup,
              pollData: old.pollData,
            );
          }
        });
      } catch (e) {
        debugPrint('chat_view: MessageEdited error: $e');
      }
    });

    // Listen for deletions — show "This message was deleted" stub when deleted for everyone.
    // Payload: message_id, deleted_for_everyone (bool), deleted_by
    _pusherListeners.listen(pusherService, channelName, 'MessageDeleted', (data) {
      if (!mounted || data == null) return;
      try {
        final d = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
        final messageId = d['message_id'] as int?;
        final deletedForEveryone = d['deleted_for_everyone'] as bool? ?? false;
        if (messageId == null || !deletedForEveryone) return;
        unawaited(
          ref.read(chatRepositoryProvider).applyRemoteDeleteForEveryone(messageId),
        );
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            final old = _messages[idx];
            _messages[idx] = Message(
              id: old.id,
              clientId: old.clientId,
              conversationId: old.conversationId,
              groupId: old.groupId,
              senderId: old.senderId,
              sender: old.sender,
              body: '',
              createdAt: old.createdAt,
              attachments: const [],
              reactions: const [],
              isDeleted: true,
              deletedForMe: false,
            );
          }
        });
      } catch (e) {
        debugPrint('chat_view: MessageDeleted error: $e');
      }
    });

    // Listen for incoming calls on this conversation
    _pusherListeners.listen(pusherService, channelName, 'CallSignal', (data) {
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
    _markReadDebounce?.cancel();
    _dmTypingDebounce?.cancel();
    _presencePollTimer?.cancel();
    if (_dmTypingActive) {
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .sendTypingIndicator(widget.conversationId, false),
      );
    }
    _recordingDurationNotifier.dispose();
    _messageSelection.removeListener(_onMessageSelectionChanged);
    _messageSelection.dispose();
    _pusherListeners.removeAll(_pusherService);
    _messageController.removeListener(_onMessageChanged);
    _messageController.removeListener(_syncComposerTrailing);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Shared helper: update a single message's read/delivered timestamps and status string.
  /// Called by both `MessageStatusUpdated` and `message.read` Pusher handlers.
  void _applyReceiptUpdate(int messageId,
      {String? statusStr, String? rawReadAt, String? rawDelivAt}) {
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx == -1) return;
      final old = _messages[idx];
      DateTime? readAt = old.readAt;
      DateTime? delivAt = old.deliveredAt;
      String? newStatus = statusStr ?? old.status;

      if (rawReadAt != null) {
        readAt = DateTime.tryParse(rawReadAt) ?? readAt;
        newStatus = 'read';
      } else if (statusStr == 'read') {
        readAt ??= DateTime.now();
      }

      if (rawDelivAt != null) {
        delivAt = DateTime.tryParse(rawDelivAt) ?? delivAt;
        if (newStatus != 'read') newStatus = 'delivered';
      } else if (statusStr == 'delivered' || statusStr == 'read') {
        delivAt ??= DateTime.now();
      }

      _messages[idx] = Message(
        id: old.id,
        clientId: old.clientId,
        conversationId: old.conversationId,
        groupId: old.groupId,
        senderId: old.senderId,
        sender: old.sender,
        body: old.body,
        createdAt: old.createdAt,
        editedAt: old.editedAt,
        replyToId: old.replyToId,
        forwardedFromId: old.forwardedFromId,
        forwardChain: old.forwardChain,
        attachments: old.attachments,
        reactions: old.reactions,
        callData: old.callData,
        linkPreviews: old.linkPreviews,
        isDeleted: old.isDeleted,
        deletedForMe: old.deletedForMe,
        status: newStatus,
        isSystem: old.isSystem,
        systemAction: old.systemAction,
        readAt: readAt,
        deliveredAt: delivAt,
        locationData: old.locationData,
        contactData: old.contactData,
        mentionCount: old.mentionCount,
        mentions: old.mentions,
        messageType: old.messageType,
        isViewOnce: old.isViewOnce,
        viewOnceOpened: old.viewOnceOpened,
        sikaTransferData: old.sikaTransferData,
        scheduledAt: old.scheduledAt,
        referencedStatusId: old.referencedStatusId,
        referencedStatus: old.referencedStatus,
        referencedGroupId: old.referencedGroupId,
        referencedGroupMessageId: old.referencedGroupMessageId,
        referencedGroup: old.referencedGroup,
        pollData: old.pollData,
      );
    });
  }

  void _broadcastDmTyping(bool isTyping) {
    _dmTypingDebounce?.cancel();
    if (isTyping) {
      if (!_dmTypingActive) {
        _dmTypingActive = true;
        unawaited(
          ref
              .read(chatRepositoryProvider)
              .sendTypingIndicator(widget.conversationId, true),
        );
      }
      _dmTypingDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _dmTypingActive = false;
        unawaited(
          ref
              .read(chatRepositoryProvider)
              .sendTypingIndicator(widget.conversationId, false),
        );
      });
    } else {
      _dmTypingActive = false;
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .sendTypingIndicator(widget.conversationId, false),
      );
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = ref.read(localStorageServiceProvider);
      final cached = await storage.loadMessages(widget.conversationId);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(cached);
          _sortMessagesInPlace();
          _dedupeMessagesInPlace();
        });
        _scheduleScrollAfterLoad(targetId: widget.initialScrollToMessageId);
      }

      final chatRepo = ref.read(chatRepositoryProvider);
      final rawMessages =
          await chatRepo.getConversationMessages(widget.conversationId);
      final container = ProviderScope.containerOf(context);
      final messages = await reconcileStaleJoinableCallMessages(
        messages: rawMessages,
        repo: ref.read(callRepositoryProvider),
        container: container,
      );
      setState(() {
        if (messages.isNotEmpty) {
          _messages
            ..clear()
            ..addAll(messages);
          _sortMessagesInPlace();
          _dedupeMessagesInPlace();
          _hasMoreOlder = messages.length >= 100;
        }
        _isLoading = false;
      });
      _scheduleScrollAfterLoad(targetId: widget.initialScrollToMessageId);
      
      await clearConversationUnreadInSidebar(ref, widget.conversationId);
      _updateTaskbarBadge();

      unawaited(syncConversationSidebarFromLoadedMessages(
        ref,
        conversationId: widget.conversationId,
        messages: _messages,
        currentUserId: _currentUserId,
      ));
      
      try {
        await chatRepo.markConversationAsRead(widget.conversationId);
        ref.read(inboxListRefreshTickProvider.notifier).state++;
        _updateTaskbarBadge();
      } catch (e) {
        debugPrint('Failed to mark conversation as read (server): $e');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        context.showErrorToast('Failed to load messages: $e');
      }
    }
  }

  void _scheduleMarkConversationAsRead() {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(_markConversationAsReadQuiet());
    });
  }

  Future<void> _refreshAfterBackgroundSync() async {
    try {
      final storage = ref.read(localStorageServiceProvider);
      final dbMessages = await storage.loadMessages(widget.conversationId);
      if (!mounted || dbMessages.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(ChatRepository.mergeMessageHistory(_messages, dbMessages));
        _sortMessagesInPlace();
      });
    } catch (e) {
      debugPrint('ChatView background sync refresh: $e');
    }
  }

  Future<void> _markConversationAsReadQuiet() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await clearConversationUnreadInSidebar(ref, widget.conversationId);
      await chatRepo.markConversationAsReadLocally(widget.conversationId);
      await chatRepo.markConversationAsRead(widget.conversationId);
      ref.read(inboxListRefreshTickProvider.notifier).state++;
      _updateTaskbarBadge();
    } catch (e) {
      debugPrint('Conversation mark-read while open: $e');
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

  void _applyRealtimeMessage(Map<String, dynamic> messageMap) {
    if (!mounted) return;
    try {
      final message = Message.fromJson(messageMap);
      _applyRealtimeMessageModel(message, clientId: messageMap['client_message_id'] as String? ??
          messageMap['client_uuid'] as String?);
    } catch (e) {
      debugPrint('Error applying real-time message: $e');
    }
  }

  void _applyRealtimeMessageModel(Message message, {String? clientId}) {
    if (!mounted) return;
    if (message.id > 0 &&
        _currentUserId != null &&
        message.senderId != _currentUserId) {
      ref.read(deliveryConfirmationServiceProvider).reportDelivered(message.id);
      _touchPeerPresence(at: message.createdAt);
    }
    setState(() {
      final effectiveClientId =
          (clientId != null && clientId.isNotEmpty) ? clientId : message.clientId;
      var existingIdx = _messages.indexWhere((m) =>
          (message.id > 0 && m.id == message.id) ||
          (effectiveClientId != null &&
              effectiveClientId.isNotEmpty &&
              m.clientId != null &&
              m.clientId == effectiveClientId));
      // MessageSent often omits client_uuid — merge into our optimistic bubble.
      if (existingIdx < 0 &&
          message.id > 0 &&
          _currentUserId != null &&
          message.senderId == _currentUserId) {
        existingIdx = _messages.indexWhere((m) =>
            m.id <= 0 &&
            (m.status == 'sending' || m.status == 'queued') &&
            m.senderId == _currentUserId &&
            (m.body ?? '') == (message.body ?? ''));
      }
      if (existingIdx == -1) {
        _messages.add(message);
      } else {
        _messages[existingIdx] = message;
      }
      _dedupeMessagesInPlace();
      _sortMessagesInPlace();
    });
    _scrollToBottom();
    _updateTaskbarBadge();
    unawaited(
      ref
          .read(chatRepositoryProvider)
          .persistConversationMessages(widget.conversationId, [message]),
    );
  }

  /// Collapse optimistic + server duplicates (same id or clientId).
  void _dedupeMessagesInPlace() {
    if (_messages.length < 2) return;
    final serverClientIds = <String>{
      for (final m in _messages)
        if (m.id > 0 && (m.clientId?.isNotEmpty ?? false)) m.clientId!,
    };
    final seenIds = <int>{};
    final seenPendingClients = <String>{};
    final kept = <Message>[];
    for (final m in _messages.reversed) {
      if (m.id > 0) {
        if (!seenIds.add(m.id)) continue;
        kept.add(m);
        continue;
      }
      final cid = m.clientId;
      if (cid != null && cid.isNotEmpty) {
        if (serverClientIds.contains(cid)) continue;
        if (!seenPendingClients.add(cid)) continue;
      }
      kept.add(m);
    }
    _messages
      ..clear()
      ..addAll(kept.reversed);
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loadingOlder ||
        !_hasMoreOlder ||
        _messages.isEmpty) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels <= _loadOlderThreshold) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreOlder || _messages.isEmpty) return;
    final withServerId = _messages.where((m) => m.id > 0).toList();
    if (withServerId.isEmpty) return;

    final beforeMessageId = withServerId.first.id;
    final oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldPixels =
        _scrollController.hasClients ? _scrollController.position.pixels : 0.0;

    setState(() => _loadingOlder = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final result = await chatRepo.getOlderConversationMessages(
        widget.conversationId,
        beforeMessageId,
      );
      if (!mounted) return;

      if (result.messages.isNotEmpty) {
        final existingIds = _messages.map((m) => m.id).toSet();
        final toAdd =
            result.messages.where((m) => !existingIds.contains(m.id)).toList();
        setState(() {
          _messages.insertAll(0, toAdd);
          _sortMessagesInPlace();
          _hasMoreOlder = result.hasMore;
          _loadingOlder = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final delta = _scrollController.position.maxScrollExtent -
              oldMaxExtent;
          _scrollController.jumpTo(oldPixels + delta);
        });
      } else {
        setState(() {
          _hasMoreOlder = false;
          _loadingOlder = false;
        });
      }
    } catch (e) {
      debugPrint('Load older DM messages failed: $e');
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  /// Build the list of slots (dates + messages) once. Used for itemCount and per-item build.
  List<_MessageSlot> _buildMessageSlots() {
    if (_messages.isEmpty) return [];
    final List<_MessageSlot> slots = [];
    DateTime? previousDate;
    for (final message in _messages) {
      final messageDate = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (previousDate == null || messageDate != previousDate) {
        slots.add(_DateSlot(message.createdAt));
        previousDate = messageDate;
      }
      slots.add(_MessageBubbleSlot(message));
    }
    return slots;
  }

  /// Build a single list item from a slot. Used with slots built once per ListView build.
  Widget _buildItemFromSlot(List<_MessageSlot> slots, int index) {
    final slot = slots[index];
    if (slot is _DateSlot) {
      return DateDivider(
        key: ValueKey('date-${widget.conversationId}-$index'),
        date: slot.date,
      );
    }
    if (slot is _MessageBubbleSlot) {
      final message = slot.message;
      Message? previousMessage;
      Message? nextMessage;
      for (var i = index - 1; i >= 0; i--) {
        final earlier = slots[i];
        if (earlier is _MessageBubbleSlot) {
          previousMessage = earlier.message;
          break;
        }
      }
      for (var i = index + 1; i < slots.length; i++) {
        final later = slots[i];
        if (later is _MessageBubbleSlot) {
          nextMessage = later.message;
          break;
        }
      }
      final bubble = MessageBubble(
        key: ValueKey(
          message.id > 0
              ? 'msg-${widget.conversationId}-${message.id}'
              : 'msg-${widget.conversationId}-c-${message.clientId ?? index}',
        ),
        message: message,
        currentUserId: _currentUserId ?? 0,
        allMessages: _messages,
        previousMessage: previousMessage,
        nextMessage: nextMessage,
        dmContactName: widget.contactName,
        onReplyPreviewTap: (id) => _scrollToMessageId(id),
        onDelete: () => _deleteMessage(message),
        onReply: () => _setReply(message),
        onReact: (emoji) => _reactToMessage(message, emoji),
        onForward: Message.isCallMessage(message)
            ? null
            : () => _forwardMessage(message),
        onReplyToMessage: _setReply,
        onForwardToMessage:
            Message.isCallMessage(message) ? null : _forwardMessage,
        onDeleteMessage: _deleteMessage,
        onReactToMessage: _reactToMessage,
        onPinToMessage: _pinMessage,
        onEdit: Message.isCallMessage(message)
            ? null
            : (newBody) => _editMessage(message, newBody),
        onPin: (pin) => _pinMessage(message, pin),
        onRetry: message.status == 'failed'
            ? () => unawaited(_retryFailedMessage(message))
            : null,
        isSelectionMode: _messageSelection.isSelectionMode &&
            messageShowsSelectionChrome(
              message: message,
              selectedIds: _messageSelection.selectedItems.toSet(),
              selectionMode: _messageSelection.isSelectionMode,
            ),
        isSelected: _messageSelection.isSelected(message.id),
        onSelectMode: () => _enterMessageSelection(message),
        onSelectionToggle: () => _toggleMessageSelection(message),
        onReferencedStatusTap: () => _openReferencedStatus(message),
        onReferencedGroupTap: () => _openReferencedGroup(message),
        onViewOnceOpened: (msg) => _markViewOnceOpened(msg),
      );
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        color: _highlightedMessageId == message.id
            ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
            : Colors.transparent,
        child: bubble,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPeerActivityRow({required bool isRecording}) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 72, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecording)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.mic_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
            TypingIndicatorBubble(
              size: 44,
              dotRadius: 3.2,
              backgroundColor: scheme.surfaceContainerHighest,
              dotColor:
                  isRecording ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageListBody(bool isDark) {
    if (_isLoading && _messages.isEmpty) {
      return ListView.builder(
        key: ValueKey('chat-skeleton-${widget.conversationId}'),
        itemCount: 8,
        itemBuilder: (context, index) => SkeletonMessageBubble(
          isMe: index % 3 == 0,
        ),
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        key: ValueKey('chat-empty-${widget.conversationId}'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 240,
            child: Center(
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
                      fontWeight:
                          _isDragging ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (_isDragging) ...[
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.cloud_upload,
                      size: 48,
                      color: Color(0xFF008069),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    final slots = _buildMessageSlots();
    return ListView.builder(
      key: ValueKey('chat-msgs-${widget.conversationId}'),
      controller: _scrollController,
      padding: DesktopChatMetrics.messageListPadding,
      itemCount: slots.length,
      itemBuilder: (context, index) => _buildItemFromSlot(slots, index),
    );
  }

  void _scheduleScrollAfterLoad({int? targetId}) {
    if (!mounted || _messages.isEmpty) {
      if (targetId != null) widget.onInitialScrollConsumed?.call();
      return;
    }
    void run({int attemptsLeft = 6}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _messages.isEmpty) return;
        if (!_scrollController.hasClients) {
          if (attemptsLeft > 0) run(attemptsLeft: attemptsLeft - 1);
          return;
        }
        if (targetId != null) {
          _scrollToMessageId(targetId, highlight: true);
          widget.onInitialScrollConsumed?.call();
          return;
        }
        final pos = _scrollController.position;
        pos.jumpTo(pos.maxScrollExtent);
        if (attemptsLeft > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            final p = _scrollController.position;
            p.jumpTo(p.maxScrollExtent);
          });
        }
      });
    }
    run();
  }

  void _scrollToBottom({bool instant = false}) {
    void attempt({required bool retry}) {
      if (!mounted) return;
      if (!_scrollController.hasClients) {
        if (retry) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            attempt(retry: false);
          });
        }
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (instant) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attempt(retry: true);
    });
  }

  void _openReferencedStatus(Message message) {
    final snap = message.referencedStatus;
    final id = message.referencedStatusId;
    if (id == null) return;
    final uid = snap?['user_id'] as int? ?? 0;
    StatusType stype;
    switch (snap?['type']?.toString() ?? 'text') {
      case 'image':
        stype = StatusType.image;
        break;
      case 'video':
        stype = StatusType.video;
        break;
      case 'audio':
        stype = StatusType.audio;
        break;
      default:
        stype = StatusType.text;
    }
    final expiresStr = snap?['expires_at']?.toString();
    final expiresAt = expiresStr != null
        ? DateTime.tryParse(expiresStr) ??
            DateTime.now().add(const Duration(days: 1))
        : DateTime.now().add(const Duration(days: 1));
    final createdAt =
        DateTime.tryParse(snap?['created_at']?.toString() ?? '') ??
            DateTime.now();
    final update = StatusUpdate(
      id: id,
      userId: uid,
      type: stype,
      text: snap?['text'] as String?,
      mediaUrl: snap?['media_url'] as String?,
      thumbnailUrl: snap?['thumbnail_url'] as String?,
      backgroundColor: null,
      fontFamily: null,
      createdAt: createdAt,
      expiresAt: expiresAt,
      viewCount: 0,
      viewed: false,
    );
    final summary = StatusSummary(
      userId: uid,
      userName: widget.contactName,
      userAvatar: widget.contactAvatar,
      updates: [update],
      lastUpdatedAt: createdAt,
      hasUnviewed: false,
    );
    showDesktopStatusViewer(
      context,
      statusSummary: summary,
      startIndex: 0,
      isOwnStatus: false,
    );
  }

  void _openReferencedGroup(Message message) {
    final gid = message.referencedGroupId;
    final mid = message.referencedGroupMessageId;
    if (gid == null || mid == null) return;
    ref.read(pendingDesktopGroupDeepLinkProvider.notifier).state =
        (groupId: gid, messageId: mid);
  }

  ({
    int? referencedStatusId,
    int? referencedGroupId,
    int? referencedGroupMessageId,
  }) _consumeOutgoingReferences() {
    int? refStatusId;
    int? refGid;
    int? refGmid;
    if (_pendingStatusReply != null) {
      refStatusId = _pendingStatusReply!.statusId;
      setState(() => _pendingStatusReply = null);
    }
    if (_pendingGroupMessageReply != null) {
      refGid = _pendingGroupMessageReply!.groupId;
      refGmid = _pendingGroupMessageReply!.groupMessageId;
      setState(() => _pendingGroupMessageReply = null);
    }
    return (
      referencedStatusId: refStatusId,
      referencedGroupId: refGid,
      referencedGroupMessageId: refGmid,
    );
  }

  List<MessageAttachment> _messageAttachmentsFromFiles(List<File> files) {
    return files.map<MessageAttachment>((file) {
      final path = file.path.toLowerCase();
      final isImage = ClipboardMediaHelper.isImagePath(path);
      final isVideo = ClipboardMediaHelper.isVideoPath(path);
      final isAudio = path.endsWith('.m4a') ||
          path.endsWith('.aac') ||
          path.endsWith('.mp3') ||
          path.endsWith('.wav') ||
          path.endsWith('.ogg');
      return MessageAttachment(
        id: 0,
        url: file.path,
        mimeType: isImage
            ? 'image/jpeg'
            : isVideo
                ? 'video/mp4'
                : isAudio
                    ? 'audio/mpeg'
                    : 'application/octet-stream',
        isImage: isImage,
        isVideo: isVideo,
        isAudio: isAudio,
        isDocument: !isImage && !isVideo && !isAudio,
      );
    }).toList();
  }

  void _mergeSentMessage(Message serverMessage, {required String clientUuid}) {
    final idx = _messages.indexWhere(
      (m) =>
          (m.clientId != null && m.clientId == clientUuid) ||
          (serverMessage.id > 0 && m.id == serverMessage.id),
    );
    if (idx >= 0) {
      _messages[idx] = serverMessage;
    } else if (serverMessage.id > 0 &&
        !_messages.any((m) => m.id == serverMessage.id)) {
      _messages.add(serverMessage);
    }
    _dedupeMessagesInPlace();
    _sortMessagesInPlace();
  }

  void _markOptimisticSendFailed(String clientUuid) {
    final idx = _messages.indexWhere((m) => m.clientId == clientUuid);
    if (idx >= 0) {
      _messages[idx] = _messages[idx].copyWith(status: 'failed');
      unawaited(bumpConversationInSidebar(
        ref,
        conversationId: widget.conversationId,
        message: _messages[idx],
      ));
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _attachments.isEmpty) return;

    final isOnline = ref.read(connectivityProvider);
    final messageQueue = ref.read(messageQueueServiceProvider);

    try {
      if (!isOnline) {
        final pendingStatus = _pendingStatusReply;
        final pendingGroup = _pendingGroupMessageReply;
        Map<String, dynamic>? statusPreview;
        Map<String, dynamic>? groupPreview;
        int? refStatusId;
        int? refGroupId;
        int? refGroupMsgId;
        if (pendingStatus != null) {
          refStatusId = pendingStatus.statusId;
          statusPreview = pendingStatus.toPreviewMap();
        }
        if (pendingGroup != null) {
          refGroupId = pendingGroup.groupId;
          refGroupMsgId = pendingGroup.groupMessageId;
          groupPreview = pendingGroup.toPreviewMap();
        }
        String? refContextJson;
        if (statusPreview != null || groupPreview != null) {
          refContextJson = jsonEncode({
            if (statusPreview != null) 'referenced_status': statusPreview,
            if (groupPreview != null) 'referenced_group': groupPreview,
          });
        }

        final queuedClientUuid = await messageQueue.queueMessage(
          conversationId: widget.conversationId,
          groupId: null,
          body: message,
          replyToId: _replyingToId,
          attachments: _attachments.isNotEmpty ? _attachments : null,
          referencedStatusId: refStatusId,
          referencedGroupId: refGroupId,
          referencedGroupMessageId: refGroupMsgId,
          referencedContextJson: refContextJson,
          viewOnce: _attachmentsViewOnce && _attachments.isNotEmpty,
        );

        // Create a temporary message object for UI display
        final tempMessage = Message(
          id: 0, // Optimistic placeholder — mergeMessageHistory drops id<=0 when clientId matches
          clientId: queuedClientUuid, // UUID stored for reconciliation when server confirms
          conversationId: widget.conversationId,
          senderId: _currentUserId ?? 0,
          body: message,
          createdAt: DateTime.now(),
          status: 'queued',
          replyToId: _replyingToId,
          attachments: _attachments.map<MessageAttachment>((file) {
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
          referencedStatusId: refStatusId,
          referencedStatus: statusPreview,
          referencedGroupId: refGroupId,
          referencedGroupMessageId: refGroupMsgId,
          referencedGroup: groupPreview,
        );

        setState(() {
          _messages.add(tempMessage);
          _messageController.clear();
          _attachments.clear();
          _attachmentsViewOnce = false;
          _replyingToId = null;
          _replyingToMessage = null;
          _pendingStatusReply = null;
          _pendingGroupMessageReply = null;
        });
        _scrollToBottom();

        if (mounted) {
                    context.showSuccessToast('Message queued. Will be sent when you\'re online.');        }
        unawaited(bumpConversationInSidebar(
          ref,
          conversationId: widget.conversationId,
          message: tempMessage,
        ));
        return;
      }

      // Optimistic bubble with clock icon while the network request runs.
      final chatRepo = ref.read(chatRepositoryProvider);
      final statusPreview = _pendingStatusReply?.toPreviewMap();
      final groupPreview = _pendingGroupMessageReply?.toPreviewMap();
      final outgoingRefs = _consumeOutgoingReferences();
      const uuid = Uuid();
      final clientUuid = uuid.v4();
      final replyToId = _replyingToId;
      final attachmentsCopy = List<File>.from(_attachments);
      final viewOnce = _attachmentsViewOnce && _attachments.isNotEmpty;

      final optimisticMessage = Message(
        id: 0,
        clientId: clientUuid,
        conversationId: widget.conversationId,
        senderId: _currentUserId ?? 0,
        body: message,
        createdAt: DateTime.now(),
        status: 'sending',
        replyToId: replyToId,
        attachments: _messageAttachmentsFromFiles(attachmentsCopy),
        reactions: const [],
        referencedStatusId: outgoingRefs.referencedStatusId,
        referencedStatus: statusPreview,
        referencedGroupId: outgoingRefs.referencedGroupId,
        referencedGroupMessageId: outgoingRefs.referencedGroupMessageId,
        referencedGroup: groupPreview,
        isViewOnce: viewOnce,
      );

      setState(() {
        _messages.add(optimisticMessage);
        _messageController.clear();
        _attachments.clear();
        _attachmentsViewOnce = false;
        _replyingToId = null;
        _replyingToMessage = null;
      });
      _scrollToBottom();
      unawaited(bumpConversationInSidebar(
        ref,
        conversationId: widget.conversationId,
        message: optimisticMessage,
      ));

      try {
        final newMessage = await chatRepo.sendMessageToConversation(
          conversationId: widget.conversationId,
          body: message.isEmpty ? null : message,
          replyTo: replyToId,
          attachments: attachmentsCopy.isNotEmpty ? attachmentsCopy : null,
          clientUuid: clientUuid,
          referencedStatusId: outgoingRefs.referencedStatusId,
          referencedGroupId: outgoingRefs.referencedGroupId,
          referencedGroupMessageId: outgoingRefs.referencedGroupMessageId,
          viewOnce: viewOnce,
        );

        if (!mounted) return;

        final isAiChat = widget.otherUser?.phone == '0000000000' ||
            widget.otherUser?.phone == '+2330000000000';

        setState(() {
          _mergeSentMessage(newMessage, clientUuid: clientUuid);
          if (isAiChat) {
            _isTyping = true;
          }
        });
        _scrollToBottom();
        unawaited(bumpConversationInSidebar(
          ref,
          conversationId: widget.conversationId,
          message: newMessage,
        ));
      } catch (e) {
        debugPrint('Error sending message: $e');
        if (mounted) {
          setState(() => _markOptimisticSendFailed(clientUuid));
          context.showErrorToast('Failed to send message: ${unwrapExceptionMessage(e)}');        }
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        context.showErrorToast('Failed to send message: ${unwrapExceptionMessage(e)}');      }
    }
  }

  Future<void> _handleClipboardPaste() async {
    try {
      final files = await ClipboardMediaHelper.readMediaFiles();
      if (files.isNotEmpty) {
        await _previewAndSendMedia(files);
        return;
      }

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) return;
      _insertTextAtSelection(text);
    } catch (e) {
      debugPrint('Clipboard paste failed: $e');
    }
  }

  void _insertTextAtSelection(String text) {
    final selection = _messageController.selection;
    final oldText = _messageController.text;
    final start = selection.start >= 0 ? selection.start : oldText.length;
    final end = selection.end >= 0 ? selection.end : oldText.length;
    final newText = oldText.replaceRange(start, end, text);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _onMessageChanged();
  }

  Future<void> _previewAndSendMedia(List<File> files) async {
    final result = await DesktopMediaPreviewDialog.show(context, files: files);
    if (result == null || !mounted) return;
    await _sendMediaPreviewResult(result);
  }

  Future<void> _sendMediaPreviewResult(DesktopMediaPreviewResult result) async {
    if (result.files.isEmpty) return;

    final isOnline = ref.read(connectivityProvider);
    final messageQueue = ref.read(messageQueueServiceProvider);
    final chatRepo = ref.read(chatRepositoryProvider);
    final replyToId = _replyingToId;
    final outgoingRefs = _consumeOutgoingReferences();
    final viewOnce = result.isViewOnce;

    try {
      Future<void> sendBatch({
        required List<File> files,
        String? body,
        bool attachReply = false,
      }) async {
        if (!isOnline) {
          final refStatusId =
              attachReply ? outgoingRefs.referencedStatusId : null;
          final refGroupId =
              attachReply ? outgoingRefs.referencedGroupId : null;
          final refGroupMsgId =
              attachReply ? outgoingRefs.referencedGroupMessageId : null;
          String? refContextJson;
          if (attachReply &&
              (refStatusId != null || refGroupId != null)) {
            refContextJson = jsonEncode({
              if (refStatusId != null)
                'referenced_status': {'id': refStatusId},
              if (refGroupId != null)
                'referenced_group': {'group_id': refGroupId},
            });
          }

          final queuedClientUuid = await messageQueue.queueMessage(
            conversationId: widget.conversationId,
            groupId: null,
            body: body ?? '',
            replyToId: attachReply ? replyToId : null,
            attachments: files,
            referencedStatusId: attachReply ? refStatusId : null,
            referencedGroupId: attachReply ? refGroupId : null,
            referencedGroupMessageId: attachReply ? refGroupMsgId : null,
            referencedContextJson: refContextJson,
            viewOnce: viewOnce,
          );

          final tempMessage = Message(
            id: 0,
            clientId: queuedClientUuid,
            conversationId: widget.conversationId,
            senderId: _currentUserId ?? 0,
            body: body ?? '',
            createdAt: DateTime.now(),
            status: 'queued',
            replyToId: attachReply ? replyToId : null,
            attachments: files.map<MessageAttachment>((file) {
              final path = file.path.toLowerCase();
              final isImage = ClipboardMediaHelper.isImagePath(path);
              final isVideo = ClipboardMediaHelper.isVideoPath(path);
              return MessageAttachment(
                id: 0,
                url: file.path,
                mimeType: isImage
                    ? 'image/jpeg'
                    : isVideo
                        ? 'video/mp4'
                        : 'application/octet-stream',
                isImage: isImage,
                isVideo: isVideo,
                isAudio: false,
                isDocument: !isImage && !isVideo,
              );
            }).toList(),
            reactions: const [],
            referencedStatusId: refStatusId,
            referencedGroupId: refGroupId,
            referencedGroupMessageId: refGroupMsgId,
            isViewOnce: viewOnce,
          );

          if (!mounted) return;
          setState(() {
            _messages.add(tempMessage);
          });
          _scrollToBottom();
          unawaited(bumpConversationInSidebar(
            ref,
            conversationId: widget.conversationId,
            message: tempMessage,
          ));
          return;
        }

        const uuid = Uuid();
        final clientUuid = uuid.v4();
        final optimisticMessage = Message(
          id: 0,
          clientId: clientUuid,
          conversationId: widget.conversationId,
          senderId: _currentUserId ?? 0,
          body: body ?? '',
          createdAt: DateTime.now(),
          status: 'sending',
          replyToId: attachReply ? replyToId : null,
          attachments: _messageAttachmentsFromFiles(files),
          reactions: const [],
          referencedStatusId:
              attachReply ? outgoingRefs.referencedStatusId : null,
          referencedGroupId: attachReply ? outgoingRefs.referencedGroupId : null,
          referencedGroupMessageId:
              attachReply ? outgoingRefs.referencedGroupMessageId : null,
          isViewOnce: viewOnce,
        );

        if (!mounted) return;
        setState(() => _messages.add(optimisticMessage));
        _scrollToBottom();
        unawaited(bumpConversationInSidebar(
          ref,
          conversationId: widget.conversationId,
          message: optimisticMessage,
        ));

        try {
          final newMessage = await chatRepo.sendMessageToConversation(
            conversationId: widget.conversationId,
            body: body,
            replyTo: attachReply ? replyToId : null,
            attachments: files,
            clientUuid: clientUuid,
            referencedStatusId:
                attachReply ? outgoingRefs.referencedStatusId : null,
            referencedGroupId:
                attachReply ? outgoingRefs.referencedGroupId : null,
            referencedGroupMessageId:
                attachReply ? outgoingRefs.referencedGroupMessageId : null,
            viewOnce: viewOnce,
          );

          if (!mounted) return;
          setState(() => _mergeSentMessage(newMessage, clientUuid: clientUuid));
          _scrollToBottom();
          unawaited(bumpConversationInSidebar(
            ref,
            conversationId: widget.conversationId,
            message: newMessage,
          ));
        } catch (e) {
          if (mounted) {
            setState(() => _markOptimisticSendFailed(clientUuid));
          }
          rethrow;
        }
      }

      if (result.sendAsAlbum && result.files.length > 1) {
        final caption = result.sharedCaption?.trim();
        await sendBatch(
          files: result.files,
          body: caption != null && caption.isNotEmpty ? caption : null,
          attachReply: true,
        );
      } else {
        for (var i = 0; i < result.files.length; i++) {
          final caption = result.sendAsAlbum
              ? (result.sharedCaption ?? '')
              : (i < result.captions.length ? result.captions[i] : '');
          final trimmed = caption.trim();
          await sendBatch(
            files: [result.files[i]],
            body: trimmed.isEmpty ? null : trimmed,
            attachReply: i == 0,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _replyingToId = null;
        _replyingToMessage = null;
        _pendingStatusReply = null;
        _pendingGroupMessageReply = null;
      });

      if (!isOnline && mounted) {
                context.showSuccessToast('Messages queued. Will be sent when you\'re online.');      }
    } catch (e) {
      debugPrint('Error sending media: $e');
      if (mounted) {
        context.showErrorToast('Failed to send media: ${unwrapExceptionMessage(e)}');      }
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
      
      await _previewAndSendMedia(files);
    }
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
        _composerShowSend =
            _messageController.text.trim().isNotEmpty || _attachments.isNotEmpty;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera);
      if (xfile == null || !mounted) return;

      await _previewAndSendMedia([File(xfile.path)]);
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to open camera: $e');
      }
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'wma', 'opus',
      ],
    );

    if (result != null && result.files.isNotEmpty && mounted) {
      setState(() {
        _attachments.addAll(
          result.files
              .where((f) => f.path != null)
              .map((f) => File(f.path!))
              .toList(),
        );
        _composerShowSend =
            _messageController.text.trim().isNotEmpty || _attachments.isNotEmpty;
      });
    }
  }

  void _showAttachmentMenu(BuildContext anchorContext) {
    ChatAttachmentMenuSheet.show(
      context,
      ref,
      ChatAttachmentMenuCallbacks(
        onGallery: _pickPhotoOrVideo,
        onCamera: _pickFromCamera,
        onDocument: _pickFiles,
        onAudio: _pickAudio,
        onLocation: _shareLocation,
        onContact: _shareContact,
        onBlackTask: _openBlackTask,
        onSika: _openSikaWallet,
      ),
      anchorContext: anchorContext,
    );
  }

  void _showEmojiPickerMenu(BuildContext anchorContext) {
    DesktopEmojiPickerPopup.show(
      context,
      anchorContext: anchorContext,
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
          _messageController.text =
              currentText.substring(0, currentText.length - 1);
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        }
      },
    );
  }

  void _openSikaWallet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SikaSendCoinsSheet(
          preselectedUserId: widget.otherUser?.id,
          preselectedUserName: widget.contactName,
        ),
      ),
    );
  }

  Future<void> _openBlackTask() async {
    try {
      await EmbeddedAppLauncher.openBlackTask(
        recipientUserId: widget.otherUser?.id,
        recipientName: widget.contactName,
      );
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Could not open BlackTask: $e');
      }
    }
  }

  Future<void> _recordAudio() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }

    final allowed = await ensureDesktopMicrophoneForRecording(context);
    if (!allowed || !mounted) return;

    try {
      await _startRecording();
    } catch (e) {
      if (!mounted) return;
      if (desktopMicrophoneNotFoundError(e)) {
        await showDesktopMicrophoneNotFoundDialog(context);
      } else {
        context.showErrorToast('Failed to start recording: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final encoder = recordConfigForPlatform();
      _recordingPath = '${tempDir.path}/recording_$timestamp.${encoder.extension}';

      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          encoder.config,
          path: _recordingPath!,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        _recordingDurationNotifier.value = Duration.zero;

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
          await showDesktopMicrophoneNotFoundDialog(context);
        }
      }
    } catch (e) {
      if (mounted) {
        if (desktopMicrophoneNotFoundError(e)) {
          await showDesktopMicrophoneNotFoundDialog(context);
        } else {
          context.showErrorToast('Failed to start recording: $e');
        }
      }
    }
  }

  Future<void> _cancelRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
    final path = _recordingPath;
    setState(() {
      _isRecording = false;
      _recordingPath = null;
      _recordingDuration = Duration.zero;
    });
    _recordingDurationNotifier.value = Duration.zero;
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.sendRecordingIndicator(widget.conversationId, false);
    } catch (_) {}
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
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
        await Future<void>.delayed(const Duration(milliseconds: 80));
        var audioPath = await normalizeRecordedAudioPath(path);
        final file = File(audioPath);
        if (!await file.exists() || await file.length() < 512) {
          if (mounted) {
                        context.showInfoToast('Recording was too short or empty. Try again.');          }
          return;
        }

        final shouldSend = await showDesktopVoicePreviewSheet(
          context: context,
          audioPath: audioPath,
          duration: _recordingDuration,
          audioPlayer: _audioPlayer,
        );

        if (shouldSend == true) {
          await _sendVoiceMessage(audioPath);
        } else {
          try {
            if (await file.exists()) await file.delete();
          } catch (e) {
            debugPrint('Failed to delete recording: $e');
          }
        }
      }

      _recordingPath = null;
      _recordingDuration = Duration.zero;
      _recordingDurationNotifier.value = Duration.zero;
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to stop recording: $e');      }
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

    const uuid = Uuid();
    final clientUuid = uuid.v4();
    final replyToId = _replyingToId;
    final outgoingRefs = _consumeOutgoingReferences();
    final optimisticMessage = Message(
      id: 0,
      clientId: clientUuid,
      conversationId: widget.conversationId,
      senderId: _currentUserId ?? 0,
      body: '',
      createdAt: DateTime.now(),
      status: 'sending',
      replyToId: replyToId,
      attachments: [
        MessageAttachment(
          id: 0,
          url: audioPath,
          mimeType: 'audio/mpeg',
          isImage: false,
          isVideo: false,
          isAudio: true,
          isDocument: false,
        ),
      ],
      reactions: const [],
      referencedStatusId: outgoingRefs.referencedStatusId,
      referencedGroupId: outgoingRefs.referencedGroupId,
      referencedGroupMessageId: outgoingRefs.referencedGroupMessageId,
    );

    setState(() {
      _messages.add(optimisticMessage);
      _replyingToId = null;
      _replyingToMessage = null;
    });
    _scrollToBottom();

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      debugPrint('🎤 [AUDIO SEND] Creating File object from path: $audioPath');
      final fileToSend = File(audioPath);
      
      debugPrint('🎤 [AUDIO SEND] Calling sendMessageToConversation with file: ${fileToSend.path}');
      final newMessage = await chatRepo.sendMessageToConversation(
        conversationId: widget.conversationId,
        body: null,
        replyTo: replyToId,
        attachments: [fileToSend],
        skipCompression: true,
        voiceNote: true,
        clientUuid: clientUuid,
        referencedStatusId: outgoingRefs.referencedStatusId,
        referencedGroupId: outgoingRefs.referencedGroupId,
        referencedGroupMessageId: outgoingRefs.referencedGroupMessageId,
      );
      
      if (!mounted) return;
      setState(() => _mergeSentMessage(newMessage, clientUuid: clientUuid));
      _scrollToBottom();
      unawaited(bumpConversationInSidebar(
        ref,
        conversationId: widget.conversationId,
        message: newMessage,
      ));
    } catch (e) {
      debugPrint('Error sending voice message: $e');
      if (mounted) {
        setState(() => _markOptimisticSendFailed(clientUuid));
                context.showErrorToast('Failed to send voice message: $e');      }
    }
  }

  void _updateRecordingDuration() {
    if (!_isRecording) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isRecording) {
        _recordingDuration = _recordingDuration + const Duration(seconds: 1);
        _recordingDurationNotifier.value = _recordingDuration;
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
    final local = lastSeen.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    String timeOfDay(DateTime dt) {
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }

    if (diff.inMinutes < 1) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }

    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfThatDay = DateTime(local.year, local.month, local.day);
    final dayDiff = startOfToday.difference(startOfThatDay).inDays;

    if (dayDiff == 0) {
      return 'today at ${timeOfDay(local)}';
    }
    if (dayDiff == 1) {
      return 'yesterday at ${timeOfDay(local)}';
    }
    if (dayDiff < 7) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return '${days[local.weekday - 1]} at ${timeOfDay(local)}';
    }
    return '${local.day}/${local.month}/${local.year}';
  }

  Future<void> _startCall(String type) async {
    if (_otherUserIsBot) {
      if (mounted) {
                context.showErrorToast('Calls are not available for this contact');      }
      return;
    }
    try {
      final container = ProviderScope.containerOf(context);
      await reconcileLocalCallStateWithServer(container);
      if (userIsBusyInCall(container)) {
        if (mounted) showAlreadyInCallSnackBar(context);
        return;
      }
      final callManager = ref.read(callManagerProvider);
      await callManager.startCall(
        conversationId: widget.conversationId,
        type: type,
      );

      final callSession = callManager.currentCall;
      if (callSession == null) return;

      final roomName = 'call_${callSession.id}';
      final tokenResult = await ref
          .read(liveKitTokenServiceProvider)
          .fetchToken(roomName: roomName, displayName: 'User');

      if (mounted) {
        await pushLiveKitCallScreenOnRoot(
          url: tokenResult.url,
          token: tokenResult.token,
          roomName: roomName,
          callId: callSession.id,
          videoEnabled: type == 'video',
          peerName: widget.contactName,
          peerAvatar: _effectiveOtherUser?.avatarUrl ?? widget.contactAvatar,
          conversationId: widget.conversationId,
          isOutgoingCall: true,
        );
      }
    } catch (e) {
      if (mounted) {
        if (!showCallStartFailureIfAny(context, e)) {
                    context.showErrorToast('Failed to start call: $e');        }
      }
    }
  }

  Future<void> _shareLocation() async {
    // Request location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
                context.showInfoToast('Location services are disabled. Please enable location services.');      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
                    context.showErrorToast('Location permissions are denied');        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
                context.showErrorToast('Location permissions are permanently denied. Please enable them in settings.');      }
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
                context.showErrorToast('Failed to get location: $e');      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _shareContact() async {
    final selected = await showShareContactPicker(context: context);
    if (selected == null) return;

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
        context.showErrorToast('Failed to share contact: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      if (_attachments.isEmpty) {
        _attachmentsViewOnce = false;
      }
      _composerShowSend =
          _messageController.text.trim().isNotEmpty || _attachments.isNotEmpty;
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
                    context.showSuccessToast('Chat cleared');        }
      } catch (e) {
        if (mounted) {
                    context.showErrorToast('Failed to clear chat: $e');        }
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
                context.showErrorToast('Failed to export chat: $e');      }
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
                    context.showSuccessToast('Chat deleted');        }
      } catch (e) {
        if (mounted) {
                    context.showErrorToast('Failed to delete chat: $e');        }
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

  void _scrollToMessageId(int messageId, {bool highlight = false}) {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    final slots = _buildMessageSlots();
    final slotIndex = slots.indexWhere(
      (s) => s is _MessageBubbleSlot && s.message.id == messageId,
    );
    if (slotIndex < 0) return;
    try {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;
      final target = (maxExtent * slotIndex / slots.length).clamp(0.0, maxExtent);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (highlight) {
        setState(() => _highlightedMessageId = messageId);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _highlightedMessageId == messageId) {
            setState(() => _highlightedMessageId = null);
          }
        });
      }
    } catch (e) {
      debugPrint('ChatView: scrollToMessageId skipped: $e');
    }
  }

  Future<void> _reactToMessage(Message message, String emoji) async {
    final index = _messages.indexWhere((m) => m.id == message.id);
    Message? previous;
    if (index != -1 && mounted) {
      previous = _messages[index];
      setState(() {
        final current = _messages[index];
        final userId = _currentUserId ?? 0;
        final existing = current.reactions.indexWhere(
          (r) => r.userId == userId && r.emoji == emoji,
        );
        List<Reaction> updatedReactions;
        if (existing != -1) {
          updatedReactions = List<Reaction>.from(current.reactions)
            ..removeAt(existing);
        } else {
          updatedReactions =
              current.reactions.where((r) => r.userId != userId).toList()
                ..add(Reaction(userId: userId, emoji: emoji));
        }
        _messages[index] = current.copyWith(reactions: updatedReactions);
      });
    }

    try {
      await ref.read(chatRepositoryProvider).reactToMessage(message.id, emoji);
    } catch (e) {
      if (previous != null && index != -1 && mounted) {
        setState(() {
          _messages[index] = previous!;
        });
      }
      if (mounted) {
                context.showErrorToast('Failed to react: $e');      }
    }
  }

  Future<void> _forwardMessage(Message message) async {
    if (Message.isCallMessage(message)) return;
    await ForwardMessageScreen.showModal(context, message);
  }

  void _forwardSelectedMessages() {
    final ids = _messageSelection.selectedItems.toSet();
    final toForward = _messages
        .where((m) => ids.contains(m.id) && !Message.isCallMessage(m))
        .toList();
    if (toForward.isEmpty) return;
    _messageSelection.exitSelectionMode();
    unawaited(ForwardMessageScreen.showModalForMessages(context, toForward));
  }

  void _deleteSelectedMessages() {
    final ids = _messageSelection.selectedItems.toSet();
    final toDelete = _messages.where((m) => ids.contains(m.id)).toList();
    if (toDelete.isEmpty) return;
    _messageSelection.exitSelectionMode();
    for (final msg in toDelete) {
      unawaited(_deleteMessage(msg));
    }
  }

  Future<void> _markViewOnceOpened(Message message) async {
    if (message.id <= 0) return;

    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(viewOnceOpened: true);
      }
    });

    try {
      await ref.read(chatRepositoryProvider).markViewOnceOpened(message.id);
    } catch (e) {
      debugPrint('Failed to mark view-once as opened: $e');
    }
  }

  Future<void> _retryFailedMessage(Message message) async {
    final idx = _messages.indexWhere(
      (m) =>
          (message.clientId != null && m.clientId == message.clientId) ||
          (m.id == message.id && message.id > 0) ||
          (m.id <= 0 && m.status == 'failed' && m.body == message.body),
    );
    if (idx < 0) return;
    setState(() {
      _messages[idx] = message.copyWith(status: 'sending');
    });
    try {
      final repo = ref.read(chatRepositoryProvider);
      final sent = await repo.sendMessageToConversation(
        conversationId: widget.conversationId,
        body: message.body.isEmpty ? null : message.body,
        replyTo: message.replyToId,
        clientUuid: message.clientId,
      );
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere(
          (m) =>
              (message.clientId != null && m.clientId == message.clientId) ||
              m.status == 'sending' && m.body == message.body,
        );
        if (i >= 0) {
          _messages[i] = sent.copyWith(
            clientId: sent.clientId ?? message.clientId,
            status: 'sent',
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere(
          (m) => m.status == 'sending' && m.body == message.body,
        );
        if (i >= 0) {
          _messages[i] = message.copyWith(status: 'failed');
        }
      });
      context.showErrorToast('Failed to resend message');
    }
  }

  Future<void> _deleteMessage(Message message) async {
    // PHASE 1: Check if message is less than 1 hour old (for "delete for everyone")
    final messageAge = DateTime.now().difference(message.createdAt);
    final canDeleteForEveryone = message.senderId == _currentUserId &&
        messageAge.inHours < 1 &&
        !Message.isCallMessage(message);

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
                context.showSuccessToast(deleteForEveryone 
              ? 'Message deleted for everyone'
              : 'Message deleted');      }
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to delete message: $e');      }
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
                context.showSuccessToast('Message updated');      }
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to edit message: $e');      }
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
    final sidebarTyping =
        ref.watch(typingStatusProvider)[widget.conversationId] ?? false;
    final sidebarRecording =
        ref.watch(recordingStatusProvider)[widget.conversationId] ?? false;
    final showTyping = _isTyping || sidebarTyping;
    final showRecording = _otherUserRecording || sidebarRecording;

    ref.listen<DesktopPendingStatusChatOpen?>(
        pendingDesktopStatusChatOpenProvider, (previous, next) {
      if (next == null ||
          next.conversationId != widget.conversationId) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _pendingStatusReply = next.reply;
          final draft = next.draftText;
          if (draft != null && draft.isNotEmpty) {
            _messageController.text = draft;
            _messageController.selection = TextSelection.collapsed(
              offset: _messageController.text.length,
            );
          }
        });
        ref.read(pendingDesktopStatusChatOpenProvider.notifier).state = null;
      });
    });
    ref.listen<DesktopPendingComposerDraft?>(
        pendingDesktopComposerDraftProvider, (previous, next) {
      if (next == null || next.conversationId != widget.conversationId) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _messageController.text = next.text;
        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
        ref.read(pendingDesktopComposerDraftProvider.notifier).state = null;
      });
    });
    ref.listen<DesktopPendingGroupPrivateOpen?>(
        pendingDesktopGroupPrivateOpenProvider, (previous, next) {
      if (next == null ||
          next.conversationId != widget.conversationId) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _pendingGroupMessageReply = next.toPendingReply());
        ref.read(pendingDesktopGroupPrivateOpenProvider.notifier).state = null;
      });
    });
    ref.listen<InboxLiveMessage?>(inboxLiveMessageProvider, (previous, next) {
      if (next == null || next.conversationId != widget.conversationId) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyRealtimeMessageModel(
          next.message,
          clientId: next.message.clientId,
        );
        if (_currentUserId != null &&
            next.message.senderId != null &&
            next.message.senderId != _currentUserId) {
          _scheduleMarkConversationAsRead();
        }
      });
    });
    ref.listen<int>(inboxBackgroundSyncTickProvider, (previous, next) {
      if (next == 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refreshAfterBackgroundSync());
      });
    });

    return ChatSidePanelLayout(
      showSidePanel:
          _showInfoPanel && (_effectiveOtherUser != null || widget.isSavedMessages),
      onDismissPanel: () {
        if (!mounted) return;
        setState(() => _showInfoPanel = false);
      },
      sidePanel: _buildInfoSidePanel(isDark),
      chat: Column(
      key: _chatBodyKey,
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
          child: _messageSelection.isSelectionMode
              ? MessageSelectionToolbar(
                  selectedCount: _messageSelection.selectedCount,
                  onCancel: _messageSelection.exitSelectionMode,
                  onForward:
                      _selectionIsCallOnly ? null : _forwardSelectedMessages,
                  onDelete: _deleteSelectedMessages,
                )
              : Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openInfoPanel,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        _buildAvatar(
                          avatarUrl: _effectiveOtherUser?.avatarUrl ?? widget.contactAvatar,
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
                                  Expanded(
                                    child: Text(
                                      widget.contactName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: DesktopTypography.fontFamily,
                                        color: isDark ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (_effectiveOtherUser?.isOnline == true) ...[
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
                              if (widget.isSavedMessages || _otherUserIsBot)
                                const SizedBox.shrink()
                              else if (showRecording)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.mic,
                                      size: 14,
                                      color: const Color(0xFF008069),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'recording audio...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF008069),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else if (showTyping)
                                Text(
                                  'typing...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF008069),
                                    fontSize: 12,
                                  ),
                                )
                              else if (_effectiveOtherUser?.isOnline == true)
                                const Text(
                                  'online',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFF008069),
                                    fontSize: 12,
                                  ),
                                )
                              else if (_effectiveLastSeenForSubtitle() != null)
                                Text(
                                  'last seen ${_formatLastSeen(_effectiveLastSeenForSubtitle()!)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                )
                              else if (_effectiveOtherUser?.isOnline == false)
                                Text(
                                  'offline',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.grey[600],
                                    fontSize: 12,
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
              if (!widget.isSavedMessages && !_otherUserIsBot) ...[
              IconButton(
                icon: Icon(Icons.call, color: isDark ? Colors.white70 : Colors.grey[600]),
                tooltip: 'Voice call',
                onPressed: () => _startCall('voice'),
              ),
              IconButton(
                icon: Icon(Icons.videocam, color: isDark ? Colors.white70 : Colors.grey[600]),
                tooltip: 'Video call',
                onPressed: () => _startCall('video'),
              ),
              ],
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

        ChatJoinableCallBanner(
          messages: _messages,
          conversationId: widget.conversationId,
        ),

        // Messages List with drag and drop support
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!isDark)
                      Positioned.fill(
                        child: ColoredBox(
                          color: DesktopShellColors.chatThreadBackground(
                            context,
                            isDark: false,
                          ),
                        ),
                      ),
                    GekyChatDoodleBackground(isDark: isDark),
                    Positioned.fill(
                      child: DropTarget(
                        onDragDone: (detail) {
                          setState(() {
                            _attachments.addAll(
                              detail.files
                                  .map((file) => File(file.path))
                                  .toList(),
                            );
                            _isDragging = false;
                            _composerShowSend =
                                _messageController.text.trim().isNotEmpty ||
                                    _attachments.isNotEmpty;
                          });
                        },
                        onDragEntered: (detail) => _setDragging(true),
                        onDragExited: (detail) => _setDragging(false),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                GekyChatDoodleBackground.chatMessageAreaOverlay(
                              context,
                              isDark: isDark,
                              isDragging: _isDragging,
                            ),
                            border: _isDragging
                                ? Border.all(
                                    color: const Color(0xFF008069),
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              RefreshIndicator(
                                onRefresh: _loadMessages,
                                child: _buildMessageListBody(isDark),
                              ),
                              if (_isDragging)
                                Positioned.fill(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF008069)
                                          .withOpacity(0.1),
                                      border: Border.all(
                                        color: const Color(0xFF008069),
                                        width: 4,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 24,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF202C33)
                                                  .withOpacity(0.95)
                                              : Colors.white.withOpacity(0.95),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.cloud_upload,
                                              size: 64,
                                              color: Color(0xFF008069),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Drop files here to send',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Images, videos, documents, and more',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? Colors.white60
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Fixed above the composer (not inside the scrollable list).
              if (showRecording || showTyping)
                _buildPeerActivityRow(isRecording: showRecording),
            ],
          ),
        ),

        if (_pendingStatusReply != null)
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
                Icon(Icons.auto_stories_outlined,
                    size: 20, color: AppTheme.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Replying to status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey[800],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _pendingStatusReply = null),
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ],
            ),
          ),
        if (_pendingGroupMessageReply != null)
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
                Icon(Icons.groups_rounded,
                    size: 20, color: AppTheme.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pendingGroupMessageReply!.groupName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[800],
                        ),
                      ),
                      if (_pendingGroupMessageReply!.bodyPreview != null &&
                          _pendingGroupMessageReply!.bodyPreview!.trim().isNotEmpty)
                        Text(
                          _pendingGroupMessageReply!.bodyPreview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () =>
                      setState(() => _pendingGroupMessageReply = null),
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ],
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
                return ChatAttachmentThumb(
                  file: _attachments[index],
                  isDark: isDark,
                  onRemove: () => _removeAttachment(index),
                );
              },
            ),
          ),

        if (_isRecording)
          ValueListenableBuilder<Duration>(
            valueListenable: _recordingDurationNotifier,
            builder: (context, duration, _) {
              return DesktopVoiceRecordingBar(
                duration: duration,
                waveform: _buildRecordingWave(),
                onCancel: _cancelRecording,
                onDone: _stopRecording,
              );
            },
          ),

        // Message Input — floating composer strip
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF202C33).withValues(alpha: 0.92)
                    : DesktopShellColors.chatThreadBackground(context, isDark: false)
                        .withValues(alpha: 0.98),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showFormattingToolbar)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: TextFormattingToolbar(
                              onFormat: (formatType) {
                                _applyTextFormatting(formatType);
                              },
                              onClose: () {
                                setState(() {
                                  _showFormattingToolbar = false;
                                  _messageController.selection =
                                      TextSelection.collapsed(
                                    offset: _messageController
                                        .selection.baseOffset,
                                  );
                                });
                              },
                            ),
                          ),
                        DesktopMessageComposerPill(
                          isDark: isDark,
                          onEmoji: _showEmojiPickerMenu,
                          onAttach: _showAttachmentMenu,
                          textField: SelectionArea(
                            child: Shortcuts(
                              shortcuts: {
                                LogicalKeySet(LogicalKeyboardKey.enter):
                                    const _SendMessageIntent(),
                                LogicalKeySet(
                                  LogicalKeyboardKey.shift,
                                  LogicalKeyboardKey.enter,
                                ): const _NewLineIntent(),
                                LogicalKeySet(
                                  LogicalKeyboardKey.control,
                                  LogicalKeyboardKey.keyV,
                                ): const _PasteIntent(),
                                LogicalKeySet(
                                  LogicalKeyboardKey.meta,
                                  LogicalKeyboardKey.keyV,
                                ): const _PasteIntent(),
                              },
                              child: Actions(
                                actions: {
                                  _SendMessageIntent:
                                      CallbackAction<_SendMessageIntent>(
                                    onInvoke: (_) {
                                      if (_messageController.text
                                          .trim()
                                          .isNotEmpty) {
                                        setState(() {
                                          _showQuickReplySuggestions = false;
                                        });
                                        _sendMessage();
                                      }
                                      return null;
                                    },
                                  ),
                                  _NewLineIntent:
                                      CallbackAction<_NewLineIntent>(
                                    onInvoke: (_) => null,
                                  ),
                                  _PasteIntent: CallbackAction<_PasteIntent>(
                                    onInvoke: (_) {
                                      unawaited(_handleClipboardPaste());
                                      return null;
                                    },
                                  ),
                                },
                                child: Focus(
                                  child: TextField(
                                    controller: _messageController,
                                    minLines: 1,
                                    maxLines: 4,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      fontFamily:
                                          DesktopTypography.fontFamily,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize:
                                          DesktopTypography.messageBodySize,
                                    ),
                                    decoration:
                                        DesktopMessageComposerPill
                                            .fieldDecoration(isDark),
                                    onChanged: (_) {
                                      _broadcastDmTyping(
                                        _messageController.text
                                            .trim()
                                            .isNotEmpty,
                                      );
                                      _onMessageChanged();
                                      _checkTextSelection();
                                    },
                                    onSubmitted: (_) {
                                      if (_messageController.text
                                          .trim()
                                          .isNotEmpty) {
                                        setState(() {
                                          _showQuickReplySuggestions = false;
                                        });
                                        _sendMessage();
                                      }
                                    },
                                    textInputAction: TextInputAction.newline,
                                    keyboardType: TextInputType.multiline,
                                    onTap: () {
                                      _onMessageChanged();
                                      Future.delayed(
                                        const Duration(milliseconds: 50),
                                        () => _checkTextSelection(),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          trailing: DesktopComposerTrailingAction(
                            showSend: _composerShowSend,
                            isRecording: _isRecording,
                            onSend: _sendMessage,
                            onMicPress: _recordAudio,
                            isDark: isDark,
                          ),
                        ),
                      ],
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

      ],
    ),
    );
  }

  Widget? _buildInfoSidePanel(bool isDark) {
    if (!widget.isSavedMessages && _effectiveOtherUser == null) return null;
    final user = _effectiveOtherUser ??
        User(
          id: 0,
          name: widget.contactName,
          avatarUrl: widget.contactAvatar,
        );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
          ),
        ),
      ),
      child: ContactInfoScreen(
        user: user,
        embedded: true,
        isSavedMessages: widget.isSavedMessages,
        conversationId: widget.conversationId,
        onClose: () {
          if (!mounted) return;
          setState(() => _showInfoPanel = false);
        },
      ),
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

// Audio preview widget for voice recording playback (Desktop) — see desktop_voice_recording.dart


