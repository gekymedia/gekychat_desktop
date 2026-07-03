import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationPermission, LocationAccuracy, Position;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../chat_providers.dart';
import '../providers/group_typing_status_provider.dart';
import '../sidebar_inbox_bump.dart';
import '../../calls/call_repository.dart';
import '../../calls/joinable_call_message.dart';
import '../../calls/join_call_from_link.dart';
import '../../calls/providers.dart';
import '../models.dart';
import '../../../utils/json_coercion.dart';
import '../../../core/providers.dart';
import '../../../realtime/pusher_message_payload.dart';
import '../../../services/inbox_realtime_sync.dart';
import '../../../services/message_sync_service.dart';
import '../chat_repo.dart';
import '../../../core/services/taskbar_badge_service.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../forward_message_screen.dart';
import 'message_bubble.dart';
import 'emoji_picker_widget.dart';
import 'desktop_media_preview_dialog.dart';
import 'desktop_voice_recording.dart';
import '../../../theme/app_theme.dart';
import '../../contacts/contacts_repository.dart';
import '../../contacts/contact_display_service.dart';
import '../../contacts/contact_info_screen.dart';
import 'group_info_screen.dart';
import 'chat_side_panel_layout.dart';
import '../../../widgets/constrained_slide_route.dart';
import '../../media/media_gallery_screen.dart';
import 'search_in_chat_screen.dart';
import '../../calls/call_navigation.dart';
import '../../calls/livekit_call_screen.dart';
import '../../calls/call_busy_helper.dart';
import 'chat_joinable_call_banner.dart';
import 'text_formatting_toolbar.dart';
import '../../../utils/text_formatting.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../widgets/gekychat_doodle_background.dart';
import '../../realtime/pusher_service.dart';
import '../../../utils/mention_utils.dart';
import '../../../utils/clipboard_media_helper.dart';
import 'chat_attachment_menu_sheet.dart';
import 'poll_composer_sheet.dart';
import '../../embedded_apps/embedded_app_launcher.dart';
import '../../sika/sika_send_coins_sheet.dart';
import '../../../utils/snackbar_helper.dart';
import 'chat_attachment_thumb.dart';

class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
}

class _NewLineIntent extends Intent {
  const _NewLineIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class GroupChatView extends ConsumerStatefulWidget {
  final int groupId;
  final String groupName;
  final String? groupAvatarUrl;
  final List<String> memberNames;
  final int? memberCount;
  final int? initialScrollToMessageId;
  final VoidCallback? onInitialScrollConsumed;

  const GroupChatView({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatarUrl,
    this.memberNames = const [],
    this.memberCount,
    this.initialScrollToMessageId,
    this.onInitialScrollConsumed,
  });

  @override
  ConsumerState<GroupChatView> createState() => _GroupChatViewState();
}

class _GroupChatViewState extends ConsumerState<GroupChatView> {
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  final _messageController = TextEditingController();
  final List<Message> _messages = [];
  final List<File> _attachments = [];
  bool _attachmentsViewOnce = false;
  bool _isLoading = false;
  bool _isSending = false;
  double _uploadProgress = 0.0;
  bool _showEmojiPicker = false;
  bool _isTyping = false;
  int? _currentUserId;
  bool _hasMoreOlder = true;
  bool _loadingOlder = false;
  bool _loadOlderEnabled = false;
  Timer? _groupReadRefreshDebounce;
  final Map<int, String> _peerTypers = {};
  final Map<int, String> _peerRecorders = {};
  Timer? _groupTypingDebounce;
  Timer? _groupTypingHideTimer;
  Timer? _groupRecordingHideTimer;
  Timer? _markReadDebounce;
  /// Contact-book display names for group members (populated on load).
  Map<int, String> _contactNames = {};

  final _pusherListeners = PusherListenerRegistry();
  PusherService? _pusherService;
  int? _replyingToId;
  Message? _replyingToMessage;

  /// Inline @mention suggestions (group members from [groupInfoProvider]).
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showInfoPanel = false;
  User? _infoPanelMember;
  
  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  
  // Drag and drop
  bool _isDragging = false;

  void _setDragging(bool dragging) {
    if (_isDragging == dragging) return;
    setState(() => _isDragging = dragging);
  }

  final GlobalKey _chatBodyKey = GlobalKey();
  
  // Text formatting
  bool _showFormattingToolbar = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadMessages();
    _setupRealtimeListener();
    _itemPositionsListener.itemPositions.addListener(_onGroupScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(groupTypingStatusProvider.notifier).subscribeToGroup(widget.groupId);
      unawaited(hydrateDismissedDeadCallKeys(ProviderScope.containerOf(context)));
      unawaited(_refreshContactNames());
    });
    // Listen for selection changes
    _messageController.addListener(_checkTextSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(groupInfoProvider(widget.groupId).future));
    });
  }

  static bool _contactNameMapsEqual(Map<int, String> a, Map<int, String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<void> _refreshContactNames() async {
    if (!mounted) return;
    final service = ref.read(contactDisplayServiceProvider);
    if (!service.isLoaded) {
      await service.warmUp();
    }
    if (!mounted) return;

    final names = Map<int, String>.from(service.exportCache());

    final group = ref.read(groupInfoProvider(widget.groupId)).valueOrNull;
    if (group != null) {
      final members = (group['members'] as List?) ?? [];
      for (final raw in members) {
        if (raw is! Map) continue;
        final user = User.fromJson(Map<String, dynamic>.from(raw));
        if (user.id <= 0) continue;
        names[user.id] = service.resolve(
          userId: user.id,
          phone: user.phone,
          apiName: user.name,
        );
      }
    }

    for (final msg in _messages) {
      if (msg.senderId <= 0) continue;
      final apiName = msg.sender?['name'] as String? ?? 'Unknown';
      final phone = msg.sender?['phone'] as String?;
      names[msg.senderId] = service.resolve(
        userId: msg.senderId,
        phone: phone,
        apiName: apiName,
      );
    }

    if (!mounted) return;
    if (_contactNameMapsEqual(_contactNames, names)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_contactNameMapsEqual(_contactNames, names)) return;
      setState(() => _contactNames = names);
    });
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id');
    });
  }

  void _setupRealtimeListener() {
    _pusherListeners.removeAll(_pusherService);
    final pusherService = ref.read(pusherServiceProvider);
    _pusherService = pusherService;
    pusherService.connect();
    final channelName = 'group.${widget.groupId}';

    // New message from anyone in the group
    _pusherListeners.listen(pusherService, channelName, 'GroupMessageSent', (data) {
      if (!mounted || data == null) return;
      try {
        final raw = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map);
        final messageMap = (raw['message'] is Map)
            ? mergeLaravelMessageBroadcastPayload(raw)
            : raw;
        _applyRealtimeMessage(messageMap);
      } catch (e) {
        debugPrint('GroupChatView: error handling GroupMessageSent: $e');
      }
    });

    // Message status updates (delivered / read)
    _pusherListeners.listen(pusherService, channelName, 'MessageStatusUpdated', (data) {
      if (!mounted || data == null) return;
      try {
        final statusData = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map);
        final messageId = statusData['message_id'] as int?;
        final status = statusData['status'] as String?;
        if (messageId == null || status == null) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            final old = _messages[idx];
            final readAt = status == 'read'
                ? (old.readAt ?? DateTime.now())
                : old.readAt;
            final deliveredAt = (status == 'delivered' || status == 'read')
                ? (old.deliveredAt ?? DateTime.now())
                : old.deliveredAt;
            _messages[idx] = Message(
              id: old.id,
              clientId: old.clientId,
              conversationId: old.conversationId,
              groupId: old.groupId,
              senderId: old.senderId,
              sender: old.sender,
              body: old.body,
              createdAt: old.createdAt,
              replyToId: old.replyToId,
              forwardedFromId: old.forwardedFromId,
              forwardChain: old.forwardChain,
              attachments: old.attachments,
              reactions: old.reactions,
              locationData: old.locationData,
              contactData: old.contactData,
              callData: old.callData,
              linkPreviews: old.linkPreviews,
              isDeleted: old.isDeleted,
              deletedForMe: old.deletedForMe,
              status: status,
              isSystem: old.isSystem,
              systemAction: old.systemAction,
              mentionCount: old.mentionCount,
              mentions: old.mentions,
              messageType: old.messageType,
              editedAt: old.editedAt,
              isViewOnce: old.isViewOnce,
              viewOnceOpened: old.viewOnceOpened,
              sikaTransferData: old.sikaTransferData,
              scheduledAt: old.scheduledAt,
              referencedStatusId: old.referencedStatusId,
              referencedStatus: old.referencedStatus,
              referencedGroupId: old.referencedGroupId,
              referencedGroupMessageId: old.referencedGroupMessageId,
              referencedGroup: old.referencedGroup,
              readAt: readAt,
              deliveredAt: deliveredAt,
              pollData: old.pollData,
            );
          }
        });
      } catch (e) {
        debugPrint('GroupChatView: error handling MessageStatusUpdated: $e');
      }
    });

    // Group message edited — backend fires GroupMessageEdited on group.{id}
    // Payload: id, body, edited_at, group_id
    _pusherListeners.listen(pusherService, channelName, 'GroupMessageEdited', (data) {
      if (!mounted || data == null) return;
      try {
        final d = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map);
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
              editedAt: parsedEditedAt ?? old.editedAt,
              replyToId: old.replyToId,
              forwardedFromId: old.forwardedFromId,
              forwardChain: old.forwardChain,
              attachments: old.attachments,
              reactions: old.reactions,
              locationData: old.locationData,
              contactData: old.contactData,
              callData: old.callData,
              linkPreviews: old.linkPreviews,
              isDeleted: old.isDeleted,
              deletedForMe: old.deletedForMe,
              status: old.status,
              isSystem: old.isSystem,
              systemAction: old.systemAction,
              readAt: old.readAt,
              deliveredAt: old.deliveredAt,
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
        debugPrint('GroupChatView: error handling GroupMessageEdited: $e');
      }
    });

    // Group message deleted for everyone — backend fires GroupMessageDeleted on group.{id}
    // Payload: message_id, deleted_by, is_group, timestamp
    // Note: GroupMessageDeleted is always "for everyone" (delete for me is local only)
    _pusherListeners.listen(pusherService, channelName, 'GroupMessageDeleted', (data) {
      if (!mounted || data == null) return;
      try {
        final d = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map);
        final messageId = d['message_id'] as int?;
        if (messageId == null) return;
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
        debugPrint('GroupChatView: error handling GroupMessageDeleted: $e');
      }
    });

    // Group messages read by someone — refresh read counts without wiping the thread.
    _pusherListeners.listen(pusherService, channelName, 'GroupMessageReadEvent', (data) {
      if (!mounted || data == null) return;
      _groupReadRefreshDebounce?.cancel();
      _groupReadRefreshDebounce = Timer(const Duration(milliseconds: 800), () {
        if (mounted) unawaited(_refreshMessagesQuietly());
      });
    });

    _pusherListeners.listen(
      pusherService,
      channelName,
      'TypingInGroup',
      _handleGroupTypingEvent,
    );
    _pusherListeners.listen(
      pusherService,
      channelName,
      'GroupTyping',
      _handleGroupTypingEvent,
    );
    _pusherListeners.listen(
      pusherService,
      channelName,
      '.UserRecording',
      _handleGroupRecordingEvent,
    );
    _pusherListeners.listen(
      pusherService,
      channelName,
      'UserRecording',
      _handleGroupRecordingEvent,
    );

    final callChannel = 'group.${widget.groupId}.call';
    unawaited(pusherService.subscribePrivate(callChannel, (_) {}));
    _pusherListeners.listen(pusherService, callChannel, 'CallSignal', (data) {
      if (!mounted || data == null) return;
      try {
        final signalData = data is String ? jsonDecode(data) : data;
        final payload = signalData['payload'] is String
            ? jsonDecode(signalData['payload'] as String)
            : signalData['payload'] as Map<String, dynamic>;
        final action = payload['action']?.toString();
        if (action != 'ended' &&
            action != 'declined' &&
            action != 'cancelled' &&
            action != 'canceled') {
          return;
        }
        final sid = int.tryParse(
          payload['session_id']?.toString() ??
              payload['call_session_id']?.toString() ??
              '',
        );
        if (sid == null || sid <= 0) return;
        final duration = int.tryParse(payload['duration']?.toString() ?? '');
        _patchCallSessionEnded(sid, durationSeconds: duration);
      } catch (e) {
        debugPrint('GroupChatView: CallSignal error: $e');
      }
    });
  }

  void _patchCallSessionEnded(int sessionId, {int? durationSeconds}) {
    if (!mounted) return;
    var changed = false;
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        final cd = m.callData;
        if (cd == null) continue;
        if (sessionIdFromCallData(cd) != sessionId) continue;
        final link = cd['call_link'];
        if (link is String && link.isNotEmpty) {
          rememberDismissedDeadCall(
            ProviderScope.containerOf(context),
            link,
            cd,
          );
        }
        final patched = mergeCallDataMaps(
          cd,
          <String, dynamic>{
            'status': 'ended',
            if (durationSeconds != null && durationSeconds > 0)
              'duration': durationSeconds,
          },
          forceEnded: true,
        );
        _messages[i] = Message(
          id: m.id,
          clientId: m.clientId,
          conversationId: m.conversationId,
          groupId: m.groupId,
          senderId: m.senderId,
          sender: m.sender,
          body: m.body,
          createdAt: m.createdAt,
          replyToId: m.replyToId,
          forwardedFromId: m.forwardedFromId,
          forwardChain: m.forwardChain,
          attachments: m.attachments,
          readAt: m.readAt,
          deliveredAt: m.deliveredAt,
          reactions: m.reactions,
          locationData: m.locationData,
          contactData: m.contactData,
          callData: patched,
          linkPreviews: m.linkPreviews,
          isDeleted: m.isDeleted,
          deletedForMe: m.deletedForMe,
          status: m.status,
          isSystem: m.isSystem,
          systemAction: m.systemAction,
          mentionCount: m.mentionCount,
          mentions: m.mentions,
          messageType: m.messageType,
          referencedStatusId: m.referencedStatusId,
          referencedStatus: m.referencedStatus,
          referencedGroupId: m.referencedGroupId,
          referencedGroupMessageId: m.referencedGroupMessageId,
          referencedGroup: m.referencedGroup,
          editedAt: m.editedAt,
          isViewOnce: m.isViewOnce,
          viewOnceOpened: m.viewOnceOpened,
          sikaTransferData: m.sikaTransferData,
          scheduledAt: m.scheduledAt,
          pollData: m.pollData,
          metadata: m.metadata,
        );
        changed = true;
      }
    });
    if (changed) {
      ref.invalidate(callSessionJoinableProvider(sessionId));
    }
  }

  void _scheduleMarkGroupAsRead() {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(_markGroupAsReadQuiet());
    });
  }

  Future<void> _markGroupAsReadQuiet() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await clearGroupUnreadInSidebar(ref, widget.groupId);
      await chatRepo.markGroupAsReadLocally(widget.groupId);
      await chatRepo.markGroupAsRead(widget.groupId);
      ref.read(inboxListRefreshTickProvider.notifier).state++;
      _updateTaskbarBadge();
    } catch (e) {
      debugPrint('Group mark-read while open: $e');
    }
  }

  void _handleGroupTypingEvent(dynamic data) {
    if (data is! Map || !mounted) return;
    final userId = asInt(data['user_id']);
    final isTyping = data['is_typing'] == true ||
        data['is_typing'] == 1 ||
        data['is_typing'] == '1';
    final userName =
        data['user_name']?.toString() ?? data['name']?.toString() ?? 'Someone';
    if (userId == null || userId == _currentUserId) return;

    _groupTypingHideTimer?.cancel();
    setState(() {
      if (!isTyping) {
        _peerTypers.remove(userId);
      } else {
        _peerTypers[userId] = userName;
        _peerRecorders.remove(userId);
      }
    });
    if (isTyping) {
      _groupTypingHideTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _peerTypers.remove(userId));
      });
    }
  }

  void _handleGroupRecordingEvent(dynamic data) {
    if (data is! Map || !mounted) return;
    final userId = asInt(data['user_id']);
    final isRecording = data['is_recording'] as bool? ?? false;
    final userName =
        data['user_name']?.toString() ?? data['name']?.toString() ?? 'Someone';
    if (userId == null || userId == _currentUserId) return;

    _groupRecordingHideTimer?.cancel();
    setState(() {
      if (!isRecording) {
        _peerRecorders.remove(userId);
      } else {
        _peerRecorders[userId] = userName;
        _peerTypers.remove(userId);
      }
    });
    if (isRecording) {
      _groupRecordingHideTimer = Timer(const Duration(seconds: 6), () {
        if (!mounted) return;
        setState(() => _peerRecorders.remove(userId));
      });
    }
  }

  Future<void> _broadcastGroupRecording(bool isRecording) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendGroupRecordingIndicator(widget.groupId, isRecording);
    } catch (e) {
      debugPrint('Failed to send group recording indicator: $e');
    }
  }

  void _broadcastGroupTyping(bool isTyping) {
    _groupTypingDebounce?.cancel();
    if (isTyping) {
      if (!_isTyping) {
        setState(() => _isTyping = true);
        unawaited(
          ref
              .read(chatRepositoryProvider)
              .sendGroupTypingIndicator(widget.groupId, true),
        );
      }
      _groupTypingDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() => _isTyping = false);
        unawaited(
          ref
              .read(chatRepositoryProvider)
              .sendGroupTypingIndicator(widget.groupId, false),
        );
      });
    } else {
      setState(() => _isTyping = false);
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .sendGroupTypingIndicator(widget.groupId, false),
      );
    }
  }

  String? get _groupTypingLabel {
    if (_peerTypers.isEmpty) return null;
    final names = _peerTypers.values.toList();
    if (names.length == 1) return '${names.first} is typing…';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing…';
    return '${names.length} people are typing…';
  }

  String? get _groupActivityLabel {
    if (_peerRecorders.isNotEmpty) {
      final names = _peerRecorders.values.toList();
      if (names.length == 1) return '${names.first} is recording audio…';
      if (names.length == 2) {
        return '${names[0]} and ${names[1]} are recording audio…';
      }
      return '${names.length} people are recording audio…';
    }
    return _groupTypingLabel;
  }

  @override
  void dispose() {
    _groupReadRefreshDebounce?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onGroupScroll);
    _groupTypingDebounce?.cancel();
    _groupTypingHideTimer?.cancel();
    _groupRecordingHideTimer?.cancel();
    _markReadDebounce?.cancel();
    _pusherListeners.removeAll(_pusherService);
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    _loadOlderEnabled = false;
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = ref.read(localStorageServiceProvider);
      final cached = await storage.loadGroupMessages(widget.groupId);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(cached);
        });
        unawaited(_refreshContactNames());
        _scheduleScrollAfterLoad(targetId: widget.initialScrollToMessageId);
      }

      final chatRepo = ref.read(chatRepositoryProvider);
      final rawMessages = await chatRepo.getGroupMessages(widget.groupId);
      if (!mounted) return;
      final messages = await reconcileStaleJoinableCallMessages(
        messages: rawMessages,
        repo: ref.read(callRepositoryProvider),
        container: ProviderScope.containerOf(context),
      );
      if (!mounted) return;
      setState(() {
        if (messages.isNotEmpty) {
          _messages
            ..clear()
            ..addAll(messages);
          _hasMoreOlder = messages.length >= 100;
        }
        _isLoading = false;
      });
      _scheduleScrollAfterLoad(targetId: widget.initialScrollToMessageId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_applyPostLoadSidebarEffects());
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages: $e')),
      );
    }
  }

  Future<void> _applyPostLoadSidebarEffects() async {
    if (!mounted) return;
    final chatRepo = ref.read(chatRepositoryProvider);
    await clearGroupUnreadInSidebar(ref, widget.groupId);
    if (!mounted) return;
    _updateTaskbarBadge();
    unawaited(_refreshContactNames());
    unawaited(
      syncGroupSidebarFromLoadedMessages(
        ref,
        groupId: widget.groupId,
        messages: _messages,
        currentUserId: _currentUserId,
      ),
    );
    try {
      await chatRepo.markGroupAsRead(widget.groupId);
      if (!mounted) return;
      ref.read(inboxListRefreshTickProvider.notifier).state++;
      _updateTaskbarBadge();
    } catch (e) {
      debugPrint('Failed to mark group as read (server): $e');
    }
  }

  void _applyRealtimeMessage(Map<String, dynamic> messageMap) {
    if (!mounted) return;
    try {
      final message = Message.fromJson(messageMap);
      _applyRealtimeMessageModel(message, clientId: messageMap['client_message_id'] as String? ??
          messageMap['client_uuid'] as String?);
    } catch (e) {
      debugPrint('GroupChatView: error applying real-time message: $e');
    }
  }

  void _applyRealtimeMessageModel(Message message, {String? clientId}) {
    if (!mounted) return;
    setState(() {
      final existingIdx = _messages.indexWhere((m) =>
          m.id == message.id ||
          (clientId != null &&
              clientId.isNotEmpty &&
              m.clientId == clientId));
      if (existingIdx == -1) {
        _messages.add(message);
      } else {
        _messages[existingIdx] = message;
      }
    });
    _scrollToBottom();
    unawaited(
      ref.read(chatRepositoryProvider).persistGroupMessages(widget.groupId, [
        message,
      ]),
    );
    unawaited(_refreshContactNames());
  }

  Future<void> _refreshAfterBackgroundSync() async {
    if (!mounted) return;
    try {
      final storage = ref.read(localStorageServiceProvider);
      final dbMessages = await storage.loadGroupMessages(widget.groupId);
      if (!mounted || dbMessages.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(ChatRepository.mergeMessageHistory(_messages, dbMessages));
      });
      unawaited(_refreshContactNames());
    } catch (e) {
      debugPrint('GroupChatView background sync refresh: $e');
    }
  }

  Future<void> _refreshMessagesQuietly() async {
    if (!mounted) return;
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final rawMessages = await chatRepo.getGroupMessages(widget.groupId);
      if (!mounted || rawMessages.isEmpty) return;
      final messages = await reconcileStaleJoinableCallMessages(
        messages: rawMessages,
        repo: ref.read(callRepositoryProvider),
        container: ProviderScope.containerOf(context),
      );
      if (!mounted || messages.isEmpty) return;
      setState(() {
        final byId = {for (final m in _messages) m.id: m};
        for (final m in messages) {
          byId[m.id] = m;
        }
        _messages
          ..clear()
          ..addAll(byId.values)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
    } catch (e) {
      debugPrint('Group quiet refresh failed: $e');
    }
  }

  void _onGroupScroll() {
    if (!_loadOlderEnabled ||
        _loadingOlder ||
        !_hasMoreOlder ||
        _messages.isEmpty) {
      return;
    }
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final minIndex =
        positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    if (minIndex <= 3) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreOlder || _messages.isEmpty) return;
    final withServerId = _messages.where((m) => m.id > 0).toList();
    if (withServerId.isEmpty) return;

    final oldest = withServerId.first;
    final anchorIndex = _messages.indexWhere((m) => m.id == oldest.id);

    setState(() => _loadingOlder = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final result = await chatRepo.getOlderGroupMessages(
        widget.groupId,
        oldest.createdAt,
      );
      if (!mounted) return;

      if (result.messages.isNotEmpty) {
        final existingIds = _messages.map((m) => m.id).toSet();
        final toAdd =
            result.messages.where((m) => !existingIds.contains(m.id)).toList();
        setState(() {
          _messages.insertAll(0, toAdd);
          _hasMoreOlder = result.hasMore;
          _loadingOlder = false;
        });
        if (anchorIndex >= 0 && _itemScrollController.isAttached) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_positionedListActive || !_itemScrollController.isAttached) {
              return;
            }
            final newIndex = _messages.indexWhere((m) => m.id == oldest.id);
            if (newIndex >= 0) {
              _scrollToIndex(newIndex, alignment: 0.12, animate: false);
            }
          });
        }
      } else {
        setState(() {
          _hasMoreOlder = false;
          _loadingOlder = false;
        });
      }
    } catch (e) {
      debugPrint('Load older group messages failed: $e');
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _scheduleScrollAfterLoad({int? targetId}) {
    if (!mounted || _messages.isEmpty) {
      if (targetId != null) widget.onInitialScrollConsumed?.call();
      return;
    }
    void run({int attemptsLeft = 6}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_positionedListActive) {
          if (targetId != null) widget.onInitialScrollConsumed?.call();
          return;
        }
        if (targetId != null) {
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx >= 0) {
            _scrollToIndex(idx, alignment: 0.12, animate: false);
          }
          widget.onInitialScrollConsumed?.call();
          _enableLoadOlderAfterInitialScroll();
          return;
        }
        if (!_itemScrollController.isAttached) {
          if (attemptsLeft > 0) run(attemptsLeft: attemptsLeft - 1);
          return;
        }
        _scrollToIndex(_messages.length - 1, animate: false);
        if (attemptsLeft > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_positionedListActive || !_itemScrollController.isAttached) {
              return;
            }
            _scrollToIndex(_messages.length - 1, animate: false);
            _enableLoadOlderAfterInitialScroll();
          });
        } else {
          _enableLoadOlderAfterInitialScroll();
        }
      });
    }
    run();
  }

  void _enableLoadOlderAfterInitialScroll() {
    _loadOlderEnabled = false;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _loadOlderEnabled = true;
    });
  }

  bool get _positionedListActive => mounted && _messages.isNotEmpty;

  void _scrollToIndex(
    int index, {
    double alignment = 1.0,
    bool animate = true,
  }) {
    if (!_positionedListActive) return;
    final safeIndex = index.clamp(0, _messages.length - 1);

    void attempt({required bool retry}) {
      if (!_positionedListActive) return;
      if (!_itemScrollController.isAttached) {
        if (retry) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            attempt(retry: false);
          });
        }
        return;
      }
      try {
        // scrollTo spins up a secondary list + post-frame callbacks; if the chat
        // is closed first (e.g. sidebar selection cleared), that asserts.
        // jumpTo is synchronous and safe for off-screen indices.
        final visible = _itemPositionsListener.itemPositions.value
            .any((p) => p.index == safeIndex);
        if (animate && visible) {
          unawaited(
            _itemScrollController
                .scrollTo(
                  index: safeIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  alignment: alignment,
                )
                .catchError((Object e) {
              debugPrint('GroupChatView: scrollTo index $safeIndex skipped: $e');
            }),
          );
        } else {
          _itemScrollController.jumpTo(
            index: safeIndex,
            alignment: alignment,
          );
        }
      } catch (e) {
        debugPrint('GroupChatView: scroll index $safeIndex skipped: $e');
      }
    }

    attempt(retry: true);
  }

  void _scrollToBottom() {
    if (_messages.isEmpty) return;
    _scrollToIndex(_messages.length - 1);
  }

  void _updateTaskbarBadge() {
    if (!mounted) return;
    Future.microtask(() async {
      if (!mounted) return;
      try {
        final badgeService = ref.read(taskbarBadgeServiceProvider);
        await badgeService.updateBadge();
      } catch (e) {
        if (mounted) debugPrint('Failed to update taskbar badge: $e');
      }
    });
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
        // Queue for later delivery — same offline-first pattern as 1:1 chat
        final clientUuid = await messageQueue.queueMessage(
          conversationId: null,
          groupId: widget.groupId,
          body: message,
          replyToId: _replyingToId,
          attachments: _attachments.isNotEmpty ? List.of(_attachments) : null,
          viewOnce: _attachmentsViewOnce && _attachments.isNotEmpty,
        );

        // Optimistic placeholder so the user sees the message immediately
        final tempMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch,
          clientId: clientUuid,
          groupId: widget.groupId,
          senderId: _currentUserId ?? 0,
          body: message,
          createdAt: DateTime.now(),
          replyToId: _replyingToId,
          attachments: _attachments.map<MessageAttachment>((file) {
            final path = file.path.toLowerCase();
            final isImage = path.endsWith('.jpg') || path.endsWith('.jpeg') ||
                path.endsWith('.png') || path.endsWith('.gif') ||
                path.endsWith('.webp');
            final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') ||
                path.endsWith('.avi') || path.endsWith('.mkv');
            final isAudio = path.endsWith('.m4a') || path.endsWith('.aac') ||
                path.endsWith('.mp3') || path.endsWith('.wav') ||
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
          }).toList(),
          reactions: const [],
          status: 'queued',
        );

        setState(() {
          _messages.add(tempMessage);
          _messageController.clear();
          _attachments.clear();
          _attachmentsViewOnce = false;
          _replyingToId = null;
          _replyingToMessage = null;
        });
        _scrollToBottom();
        unawaited(bumpGroupInSidebar(
          ref,
          groupId: widget.groupId,
          message: tempMessage,
        ));
        return;
      }

      final chatRepo = ref.read(chatRepositoryProvider);
      final newMessage = await chatRepo.sendMessageToGroup(
        groupId: widget.groupId,
        body: message.isEmpty ? null : message,
        attachments: _attachments.isNotEmpty ? _attachments : null,
        replyToId: _replyingToId,
        viewOnce: _attachmentsViewOnce && _attachments.isNotEmpty,
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
        _attachmentsViewOnce = false;
        _replyingToId = null;
        _replyingToMessage = null;
      });
      _scrollToBottom();
      unawaited(bumpGroupInSidebar(
        ref,
        groupId: widget.groupId,
        message: newMessage,
      ));
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
    _messageController.value = TextEditingValue(
      text: oldText.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  Future<void> _previewAndSendMedia(List<File> files) async {
    final result = await DesktopMediaPreviewDialog.show(context, files: files);
    if (result == null || !mounted) return;
    await _sendMediaPreviewResult(result);
  }

  Future<void> _sendMediaPreviewResult(DesktopMediaPreviewResult result) async {
    if (result.files.isEmpty) return;

    setState(() {
      _isSending = true;
      _uploadProgress = 0.0;
    });

    final isOnline = ref.read(connectivityProvider);
    final messageQueue = ref.read(messageQueueServiceProvider);
    final chatRepo = ref.read(chatRepositoryProvider);
    final replyToId = _replyingToId;
    final viewOnce = result.isViewOnce;

    try {
      Future<void> sendBatch({
        required List<File> files,
        String? body,
        bool attachReply = false,
      }) async {
        if (!isOnline) {
          final clientUuid = await messageQueue.queueMessage(
            conversationId: null,
            groupId: widget.groupId,
            body: body ?? '',
            replyToId: attachReply ? replyToId : null,
            attachments: files,
            viewOnce: viewOnce,
          );

          final tempMessage = Message(
            id: DateTime.now().millisecondsSinceEpoch,
            clientId: clientUuid,
            groupId: widget.groupId,
            senderId: _currentUserId ?? 0,
            body: body ?? '',
            createdAt: DateTime.now(),
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
            status: 'queued',
            isViewOnce: viewOnce,
          );

          if (!mounted) return;
          setState(() => _messages.add(tempMessage));
          _scrollToBottom();
          unawaited(bumpGroupInSidebar(
            ref,
            groupId: widget.groupId,
            message: tempMessage,
          ));
          return;
        }

        final newMessage = await chatRepo.sendMessageToGroup(
          groupId: widget.groupId,
          body: body,
          attachments: files,
          replyToId: attachReply ? replyToId : null,
          viewOnce: viewOnce,
          onProgress: (progress) {
            if (mounted) setState(() => _uploadProgress = progress);
          },
        );

        if (!mounted) return;
        setState(() {
          if (!_messages.any((m) => m.id == newMessage.id)) {
            _messages.add(newMessage);
          }
        });
        _scrollToBottom();
        unawaited(bumpGroupInSidebar(
          ref,
          groupId: widget.groupId,
          message: newMessage,
        ));
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
      });

      if (!isOnline && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages queued. Will be sent when you\'re online.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending media: $e');
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send media: $errorMessage'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _uploadProgress = 0.0;
        });
      }
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
      });
    }
  }

  void _showAttachmentMenu() {
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
        onPoll: _createPoll,
        onBlackTask: _openBlackTask,
        onSika: _openSikaWallet,
      ),
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
        builder: (context, scrollController) => const SikaSendCoinsSheet(),
      ),
    );
  }

  Future<void> _openBlackTask() async {
    try {
      await EmbeddedAppLauncher.openBlackTask(
        recipientName: widget.groupName,
      );
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Could not open BlackTask: $e');
      }
    }
  }

  Future<void> _createPoll() async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const PollComposerSheet(),
    );
    if (data == null || !mounted) return;

    final question = (data['question'] as String?) ?? 'Poll';
    const uuid = Uuid();
    final clientUuid = uuid.v4();

    try {
      final optimisticMessage = Message(
        id: 0,
        clientId: clientUuid,
        conversationId: 0,
        groupId: widget.groupId,
        senderId: _currentUserId ?? 0,
        body: question,
        createdAt: DateTime.now(),
        status: 'sending',
        reactions: const [],
        attachments: const [],
        messageType: 'poll',
        pollData: data,
      );
      setState(() => _messages.add(optimisticMessage));
      _scrollToBottom();

      final chatRepo = ref.read(chatRepositoryProvider);
      final serverMessage = await chatRepo.sendPollToGroup(
        widget.groupId,
        data,
        clientId: clientUuid,
      );
      if (!mounted) return;

      if (serverMessage != null) {
        var merged = serverMessage;
        if (merged.pollData == null && data.isNotEmpty) {
          merged = merged.copyWith(pollData: data);
        }
        if (merged.messageType != 'poll') {
          merged = merged.copyWith(messageType: 'poll');
        }
        setState(() {
          _messages.removeWhere((m) => m.clientId == clientUuid);
          final idx = _messages.indexWhere((m) => m.id == merged.id);
          if (idx >= 0) {
            _messages[idx] = merged;
          } else {
            _messages.add(merged);
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          }
        });
        _scrollToBottom();
        context.showSuccessSnackbar('Poll sent');
      } else {
        setState(() => _messages.removeWhere((m) => m.clientId == clientUuid));
        context.showErrorSnackbar('Failed to send poll');
      }
    } catch (e) {
      setState(() => _messages.removeWhere((m) => m.clientId == clientUuid));
      if (mounted) {
        context.showErrorSnackbar('Failed to send poll: $e');
      }
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

  Future<void> _cancelRecording() async {
    try {
      if (_isRecording) await _audioRecorder.stop();
    } catch (_) {}
    final path = _recordingPath;
    setState(() {
      _isRecording = false;
      _recordingPath = null;
      _recordingDuration = Duration.zero;
    });
    unawaited(_broadcastGroupRecording(false));
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
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
        unawaited(_broadcastGroupRecording(true));

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
      
      setState(() {
        _isRecording = false;
      });
      unawaited(_broadcastGroupRecording(false));

      if (path != null && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        var audioPath = await normalizeRecordedAudioPath(path);
        final file = File(audioPath);
        if (!await file.exists() || await file.length() < 512) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recording was too short or empty. Try again.')),
            );
          }
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
        voiceNote: true,
      );
      
      setState(() {
        _messages.add(newMessage);
        _replyingToId = null;
        _replyingToMessage = null;
      });
      _scrollToBottom();
      unawaited(bumpGroupInSidebar(
        ref,
        groupId: widget.groupId,
        message: newMessage,
      ));
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
      final container = ProviderScope.containerOf(context);
      await reconcileLocalCallStateWithServer(container);
      if (userIsBusyInCall(container)) {
        if (mounted) showAlreadyInCallSnackBar(context);
        return;
      }
      final callManager = ref.read(callManagerProvider);
      await callManager.startCall(
        groupId: widget.groupId,
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
          peerName: widget.groupName,
          peerAvatar: widget.groupAvatarUrl,
          groupId: widget.groupId,
          isOutgoingCall: true,
        );
      }
    } catch (e) {
      if (mounted) {
        if (!showCallStartFailureIfAny(context, e)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start call: $e')),
          );
        }
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
      if (_attachments.isEmpty) {
        _attachmentsViewOnce = false;
      }
    });
  }

  List<Map<String, dynamic>> _membersFromGroupPayload(
      Map<String, dynamic>? group) {
    final raw = (group?['members'] as List?) ?? [];
    final out = <Map<String, dynamic>>[];
    for (final m in raw) {
      if (m is! Map) continue;
      final map = Map<String, dynamic>.from(m);
      final idRaw = map['user_id'] ?? map['id'];
      final id = idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0;
      if (id <= 0) continue;
      out.add({
        'id': id,
        'name': map['name'] ?? map['user_name'] ?? 'Unknown',
        'username': map['username'],
      });
    }
    return out;
  }

  /// Token that matches server MentionService: @([a-zA-Z0-9_]{3,30})
  String _mentionTokenForApi(Map<String, dynamic> m) {
    final raw = (m['username'] as String?)?.trim();
    if (raw != null && raw.isNotEmpty) {
      final cleaned =
          raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      if (cleaned.length >= 3) {
        return cleaned.length > 30 ? cleaned.substring(0, 30) : cleaned;
      }
    }
    var fromName = (m['name'] as String? ?? 'user')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    fromName = fromName.replaceAll(RegExp(r'^_|_$'), '');
    if (fromName.length < 3) {
      fromName = '${fromName}user';
    }
    if (fromName.length < 3) {
      fromName = 'usr';
    }
    return fromName.length > 30 ? fromName.substring(0, 30) : fromName;
  }

  void _updateMentionSuggestions() {
    final text = _messageController.text;
    final cursor =
        _messageController.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, cursor);

    if (!before.contains('@')) {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }

    final at = before.lastIndexOf('@');
    if (at < 0) return;

    if (at > 0) {
      final prev = before[at - 1];
      if (prev != ' ' && prev != '\n' && prev != '\t') {
        if (_mentionSuggestions.isNotEmpty) {
          setState(() => _mentionSuggestions = []);
        }
        return;
      }
    }

    final partial = before.substring(at + 1);
    if (partial.contains(' ') ||
        partial.contains('\n') ||
        partial.contains('\t')) {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }

    final query = partial.toLowerCase();
    final group = ref.read(groupInfoProvider(widget.groupId)).valueOrNull;
    final members = _membersFromGroupPayload(group);
    final selfId = _currentUserId;

    final filtered = members
        .where((m) => m['id'] != selfId)
        .where((m) {
          if (query.isEmpty) return true;
          final name = (m['name'] as String).toLowerCase();
          final un = (m['username'] as String?)?.toLowerCase() ?? '';
          return name.contains(query) || un.contains(query);
        })
        .take(8)
        .toList();

    setState(() {
      _mentionSuggestions = filtered;
    });
  }

  void _insertGroupMention(Map<String, dynamic> m) {
    final token = _mentionTokenForApi(m);
    final text = _messageController.text;
    final cursor =
        _messageController.selection.baseOffset.clamp(0, text.length);
    final newText = MentionUtils.insertMention(
      text: text,
      cursorPosition: cursor,
      username: token,
    );

    final before = text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    final newCursor = at >= 0
        ? (at + 1 + token.length + 1).clamp(0, newText.length)
        : newText.length;

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    setState(() => _mentionSuggestions = []);
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

  Future<void> _replyPrivately(Message message) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final result = await chatRepo.replyPrivatelyToGroupMessage(widget.groupId, message.id);
      final cid = result['conversation_id'] as int?;
      if (cid == null) {
        throw Exception('No conversation_id in response');
      }
      ref.read(pendingDesktopGroupPrivateOpenProvider.notifier).state =
          DesktopPendingGroupPrivateOpen(
        conversationId: cid,
        groupId: result['group_id'] as int? ?? widget.groupId,
        groupMessageId: result['group_message_id'] as int? ?? message.id,
        groupName: result['group_name']?.toString() ?? widget.groupName,
        bodyPreview: result['group_message_body']?.toString(),
      );
      if (mounted) {
        ref.read(currentSectionProvider.notifier).setSection('/chats');
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
      await ref.read(chatRepositoryProvider).reactToMessage(
            message.id,
            emoji,
            isGroupMessage: true,
          );
    } catch (e) {
      if (previous != null && index != -1 && mounted) {
        setState(() {
          _messages[index] = previous!;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to react: $e')),
        );
      }
    }
  }

  Future<void> _forwardMessage(Message message) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ForwardMessageScreen(message: message),
      ),
    );
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
      await chatRepo.deleteMessage(
        message.id,
        deleteForEveryone: deleteForEveryone,
        groupId: widget.groupId,
      );
      
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx == -1) return;
        if (deleteForEveryone) {
          // Show "This message was deleted" stub — consistent with mobile and DM
          final old = _messages[idx];
          _messages[idx] = Message(
            id: old.id,
            clientId: old.clientId,
            groupId: old.groupId,
            senderId: old.senderId,
            body: old.body,
            createdAt: old.createdAt,
            attachments: const [],
            reactions: const [],
            isDeleted: true,
          );
        } else {
          // Delete for me — remove only from local list
          _messages.removeAt(idx);
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
      final updatedMessage = await chatRepo.editGroupMessage(message.id, newBody);
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
    _updateMentionSuggestions();
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
    final sidebarGroupTyping =
        ref.watch(groupTypingStatusProvider)[widget.groupId] ?? false;
    final memberSubtitle = isChannel
        ? '${widget.memberCount ?? widget.memberNames.length} ${widget.memberCount == 1 ? 'follower' : 'followers'}'
        : '${widget.memberCount ?? widget.memberNames.length} ${widget.memberCount == 1 ? 'member' : 'members'}';
    final headerSubtitle =
        _groupActivityLabel ?? (sidebarGroupTyping ? 'typing…' : memberSubtitle);
    final headerSubtitleIsActivity =
        _groupActivityLabel != null || sidebarGroupTyping;

    ref.listen<InboxLiveMessage?>(inboxLiveMessageProvider, (previous, next) {
      if (next == null || next.groupId != widget.groupId) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyRealtimeMessageModel(next.message);
        if (_currentUserId != null &&
            next.message.senderId != null &&
            next.message.senderId != _currentUserId) {
          _scheduleMarkGroupAsRead();
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
      showSidePanel: _showInfoPanel,
      onDismissPanel: () {
        if (!mounted) return;
        setState(() {
          _showInfoPanel = false;
          _infoPanelMember = null;
        });
      },
      sidePanel: _buildGroupInfoSidePanel(isDark),
      chat: Column(
      key: _chatBodyKey,
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
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _infoPanelMember = null;
                    _showInfoPanel = true;
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
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
                                headerSubtitle,
                                style: TextStyle(
                                  color: headerSubtitleIsActivity
                                      ? const Color(0xFF008069)
                                      : (isDark ? Colors.white70 : Colors.grey[600]),
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
              if (!isChannel) ...[
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
                            groupId: widget.groupId,
                            title: widget.groupName,
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
                            groupId: widget.groupId,
                            title: widget.groupName,
                          ),
                          leftOffset: 400.0, // Sidebar width
                        ),
                      );
                      break;
                    case 'group_info':
                      setState(() {
                        _infoPanelMember = null;
                        _showInfoPanel = true;
                      });
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

        if (!isChannel)
          ChatJoinableCallBanner(
            messages: _messages,
            groupId: widget.groupId,
          ),

        // Messages List with drag and drop support
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GekyChatDoodleBackground(isDark: isDark),
              Positioned.fill(
                child: DropTarget(
              onDragDone: (detail) {
                setState(() {
                  _attachments.addAll(
                    detail.files
                        .where((file) => file.path != null)
                        .map((file) => File(file.path))
                        .toList(),
                  );
                  _isDragging = false;
                });
              },
              onDragEntered: (detail) => _setDragging(true),
              onDragExited: (detail) => _setDragging(false),
              child: Container(
                decoration: BoxDecoration(
                  color: GekyChatDoodleBackground.chatMessageAreaOverlay(
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
                child: RefreshIndicator(
                  key: ValueKey('group-msgs-${widget.groupId}'),
                  onRefresh: _loadMessages,
                  child: _isLoading && _messages.isEmpty
                      ? ListView.builder(
                          itemCount: 8,
                          itemBuilder: (context, index) => SkeletonMessageBubble(
                            isMe: index % 3 == 0, // Mix of sent/received messages
                          ),
                        )
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
                        : ScrollablePositionedList.builder(
                            itemScrollController: _itemScrollController,
                            itemPositionsListener: _itemPositionsListener,
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              // Get group info to check if it's a channel and if sender is admin
                              final group = groupAsync.value;
                              final isChannel = group?['type'] == 'channel';
                              final admins = (group?['admins'] as List<dynamic>?)
                                  ?.map((a) => a['id'] as int?)
                                  .whereType<int>()
                                  .toList() ?? [];
                              final senderIsAdmin = admins.contains(message.senderId);
                              final channelName = isChannel ? (group?['name'] as String?) : null;
                              
                              return MessageBubble(
                                key: ValueKey(
                                  message.id > 0
                                      ? 'group-msg-${widget.groupId}-${message.id}'
                                      : 'group-msg-${widget.groupId}-c-${message.clientId ?? index}',
                                ),
                                message: message,
                                currentUserId: _currentUserId ?? 0,
                                allMessages: _messages,
                                isGroupMessage: true,
                                contactNames: _contactNames,
                                onReply: () => _setReply(message),
                                onReplyPreviewTap: (id) {
                                  final idx =
                                      _messages.indexWhere((m) => m.id == id);
                                  if (idx >= 0) {
                                    _scrollToIndex(idx, alignment: 0.35);
                                  }
                                },
                                onDelete: () => _deleteMessage(message),
                                onReplyPrivately: () => _replyPrivately(message),
                                onReact: (emoji) => _reactToMessage(message, emoji),
                                onForward: () => _forwardMessage(message),
                                onReplyToMessage: _setReply,
                                onForwardToMessage: _forwardMessage,
                                onDeleteMessage: _deleteMessage,
                                onEdit: (newBody) => _editMessage(message, newBody),
                                isChannel: isChannel,
                                channelName: channelName,
                                senderIsAdmin: senderIsAdmin,
                                onViewOnceOpened: (msg) => _markViewOnceOpened(msg),
                              );
                            },
                          ),
                ),
              ),
            ),
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

        if (_groupActivityLabel != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
            child: Text(
              _groupActivityLabel!,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),

        if (_replyingToMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 40,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _replyingToMessage!.sender?['name']?.toString() ??
                            'Message',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                      Text(
                        _replyingToMessage!.body.isNotEmpty
                            ? (_replyingToMessage!.body.length > 50
                                ? '${_replyingToMessage!.body.substring(0, 50)}...'
                                : _replyingToMessage!.body)
                            : 'Attachment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
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

        // Message Input
        if (_isRecording)
          DesktopVoiceRecordingBar(
            duration: _recordingDuration,
            waveform: _buildRecordingWave(),
            onCancel: _cancelRecording,
            onDone: _stopRecording,
          ),
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
                icon: Icon(_isRecording ? Icons.mic : Icons.mic_none_outlined,
                    color: _isRecording
                        ? Colors.red
                        : (isDark ? Colors.white70 : Colors.grey[600])),
                onPressed: _isRecording ? _stopRecording : _recordAudio,
                tooltip: _isRecording ? 'Finish recording' : 'Record voice message',
              ),
              IconButton(
                icon: Icon(Icons.attach_file, color: isDark ? Colors.white70 : Colors.grey[600]),
                onPressed: _showAttachmentMenu,
                tooltip: 'Attach',
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_mentionSuggestions.isNotEmpty)
                      Material(
                        color: isDark ? const Color(0xFF202C33) : Colors.white,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _mentionSuggestions.length,
                            itemBuilder: (context, i) {
                              final m = _mentionSuggestions[i];
                              final name = m['name'] as String? ?? 'User';
                              final un = m['username'] as String?;
                              return ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  radius: 16,
                                  child: Icon(Icons.person, size: 18),
                                ),
                                title: Text(name),
                                subtitle: un != null && un.isNotEmpty
                                    ? Text('@$un')
                                    : null,
                                onTap: () => _insertGroupMention(m),
                              );
                            },
                          ),
                        ),
                      ),
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
                                  _sendMessage();
                                }
                                return null;
                              },
                            ),
                            _NewLineIntent: CallbackAction<_NewLineIntent>(
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
                              onChanged: (text) {
                                _broadcastGroupTyping(text.trim().isNotEmpty);
                              },
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                hintText:
                                    'Type a message (Enter to send, Shift+Enter for new line)',
                                hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey[500]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF2A3942)
                                    : const Color(0xFFF0F2F5),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              onSubmitted: (_) {
                                if (_messageController.text
                                    .trim()
                                    .isNotEmpty) {
                                  _sendMessage();
                                }
                              },
                              textInputAction: TextInputAction.newline,
                              keyboardType: TextInputType.multiline,
                              onTap: () {
                                Future.delayed(
                                    const Duration(milliseconds: 50), () {
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
              if (!_isRecording)
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
    ),
    );
  }

  Widget? _buildGroupInfoSidePanel(bool isDark) {
    final borderColor =
        isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB);
    final panelDecoration = BoxDecoration(
      border: Border(left: BorderSide(color: borderColor)),
    );

    if (_infoPanelMember != null) {
      return Container(
        decoration: panelDecoration,
        child: ContactInfoScreen(
          user: _infoPanelMember!,
          embedded: true,
          onClose: () => setState(() => _infoPanelMember = null),
        ),
      );
    }

    return Container(
      decoration: panelDecoration,
      child: GroupInfoScreen(
        groupId: widget.groupId,
        embedded: true,
        onClose: () => setState(() {
          _showInfoPanel = false;
          _infoPanelMember = null;
        }),
        onMemberTap: (member) => setState(() => _infoPanelMember = member),
      ),
    );
  }
}



