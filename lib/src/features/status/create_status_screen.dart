import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'status_repository.dart';
import 'status_text_limits.dart';
import '../../core/providers.dart';
import '../../utils/avatar_utils.dart';
import '../../utils/storage_url.dart';
import '../../utils/clipboard_media_helper.dart';
import '../world/widgets/video_trimmer_widget.dart';
import '../chats/chat_providers.dart';
import '../contacts/contacts_repository.dart';
import '../chats/models.dart' show GekyContact;
import '../../utils/snackbar_helper.dart';
import '../../services/product_analytics_service.dart';
import '../../widgets/desktop_center_modal.dart';

class CreateStatusScreen extends ConsumerStatefulWidget {
  final bool forModal;

  const CreateStatusScreen({super.key, this.forModal = false});

  static Future<bool?> showModal(BuildContext context) {
    return showDesktopCenterModal<bool>(
      context: context,
      title: 'Create status',
      maxWidth: 640,
      maxHeightFraction: 0.88,
      child: const CreateStatusScreen(forModal: true),
    );
  }

  @override
  ConsumerState<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends ConsumerState<CreateStatusScreen> {
  static const _statusMediaExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
    'm4v',
  ];

  final _textController = TextEditingController();

  final List<_StatusMentionTarget> _mentionedTargets = [];

  /// Matches API `privacy`: contacts | only_share_with | contacts_except
  String _statusPrivacy = 'contacts';
  List<int> _privacyIncludedUserIds = [];
  List<int> _privacyExcludedUserIds = [];

  File? _selectedMedia;
  bool _isVideo = false;
  bool _isLoading = false;
  bool _showEmojiPicker = false;
  Map<String, dynamic>? _uploadLimits;
  
  final List<Color> _backgroundColors = [
    const Color(0xFF00A884),
    const Color(0xFF6C5CE7),
    const Color(0xFFFF7675),
    const Color(0xFF74B9FF),
    const Color(0xFFFAB1A0),
    const Color(0xFFFDCB6E),
    const Color(0xFF00B894),
    const Color(0xFFD63031),
    const Color(0xFF0984E3),
    const Color(0xFFFF6348),
  ];
  
  Color _selectedColor = const Color(0xFF00A884);

  @override
  void initState() {
    super.initState();
    _loadUploadLimits();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatusPrivacy());
  }

  Future<void> _loadStatusPrivacy() async {
    try {
      final m = await ref.read(statusRepositoryProvider).getStatusPrivacySettings();
      if (!mounted) return;
      final p = m['privacy']?.toString() ?? 'contacts';
      setState(() {
        _statusPrivacy = p;
        _privacyIncludedUserIds = _parseIdList(m['included_user_ids']);
        _privacyExcludedUserIds = _parseIdList(m['excluded_user_ids']);
      });
    } catch (_) {}
  }

  List<int> _parseIdList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e is int ? e : int.tryParse('$e') ?? 0).where((i) => i > 0).toList();
  }

  String _privacySummary() {
    switch (_statusPrivacy) {
      case 'only_share_with':
        return _privacyIncludedUserIds.isEmpty
            ? 'Only selected people…'
            : 'Only ${_privacyIncludedUserIds.length} contact(s)';
      case 'contacts_except':
        return _privacyExcludedUserIds.isEmpty
            ? 'All contacts'
            : 'All contacts except ${_privacyExcludedUserIds.length}';
      case 'everyone':
        return 'Everyone';
      default:
        return 'All contacts';
    }
  }

  Future<void> _openPrivacyEditor() async {
    if (_isLoading) return;
    var mode = _statusPrivacy;
    var inc = List<int>.from(_privacyIncludedUserIds);
    var exc = List<int>.from(_privacyExcludedUserIds);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Who can see your status'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Applied when you tap Share (same as your status privacy in settings).',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    title: const Text('All my contacts'),
                    value: 'contacts',
                    groupValue: mode,
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() {
                        mode = v;
                        inc = [];
                        exc = [];
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Only selected people'),
                    subtitle: Text(inc.isEmpty ? 'Tap Choose…' : '${inc.length} selected'),
                    value: 'only_share_with',
                    groupValue: mode,
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => mode = v);
                    },
                  ),
                  if (mode == 'only_share_with')
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          final ids = await _pickRegisteredUserIds(
                            title: 'Share with',
                            initial: inc,
                          );
                          if (ids != null) setLocal(() => inc = ids);
                        },
                        child: const Text('Choose…'),
                      ),
                    ),
                  RadioListTile<String>(
                    title: const Text('My contacts except…'),
                    subtitle: Text(exc.isEmpty ? 'Optional' : '${exc.length} excluded'),
                    value: 'contacts_except',
                    groupValue: mode,
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => mode = v);
                    },
                  ),
                  if (mode == 'contacts_except')
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          final ids = await _pickRegisteredUserIds(
                            title: 'Exclude',
                            initial: exc,
                          );
                          if (ids != null) setLocal(() => exc = ids);
                        },
                        child: const Text('Choose to exclude…'),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (mode == 'only_share_with' && inc.isEmpty) {
                                        context.showInfoToast('Pick at least one person for “Only selected”.');                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true && mounted) {
      setState(() {
        _statusPrivacy = mode;
        _privacyIncludedUserIds = mode == 'only_share_with' ? inc : [];
        _privacyExcludedUserIds = mode == 'contacts_except' ? exc : [];
      });
    }
  }

  Future<List<int>?> _pickRegisteredUserIds({
    required String title,
    required List<int> initial,
  }) async {
    final repo = ref.read(contactsRepositoryProvider);
    List<GekyContact> contacts;
    try {
      contacts = await repo.listContacts();
    } catch (_) {
      return null;
    }
    final rows = <({int id, String label})>[];
    for (final c in contacts) {
      final uidRaw = c.contactUserId ?? c.contactUser?['id'];
      final uid = uidRaw is int ? uidRaw : int.tryParse('$uidRaw');
      if (uid == null || uid <= 0) continue;
      final name = c.name.trim();
      rows.add((id: uid, label: name.isNotEmpty ? name : (c.phone ?? 'User')));
    }
    rows.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    return showDialog<List<int>>(
      context: context,
      builder: (ctx) {
        final sel = Set<int>.from(initial);
        return StatefulBuilder(
          builder: (ctx, setL) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                height: 400,
                child: rows.isEmpty
                    ? const Center(child: Text('No registered contacts'))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          return CheckboxListTile(
                            value: sel.contains(r.id),
                            onChanged: (v) {
                              setL(() {
                                if (v == true) {
                                  sel.add(r.id);
                                } else {
                                  sel.remove(r.id);
                                }
                              });
                            },
                            title: Text(r.label),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, sel.toList()),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadUploadLimits() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getUploadLimits();
      
      if (mounted) {
        setState(() {
          _uploadLimits = response.data;
        });
      }
    } catch (e) {
      // Limits will default to backend values
    }
  }

  Future<void> _checkVideoAndTrim(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final durationSeconds = controller.value.duration.inSeconds;
      await controller.dispose();

      final maxDuration = _uploadLimits?['status']?['max_duration'] ?? 180;
      
      if (durationSeconds > maxDuration) {
        if (!mounted) return;
        
        final trimmedVideo = await showDialog<File>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: VideoTrimmerWidget(
              videoFile: videoFile,
              maxDuration: maxDuration,
              onTrimComplete: (trimmed) {
                Navigator.pop(context, trimmed);
              },
              onCancel: () {
                Navigator.pop(context);
              },
            ),
          ),
        );

        if (trimmedVideo != null && mounted) {
          setState(() {
            _selectedMedia = trimmedVideo;
            _isVideo = true;
          });
        }
      } else {
        setState(() {
          _selectedMedia = videoFile;
          _isVideo = true;
        });
      }
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to check video: $e');      }
    }
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _statusMediaExtensions,
      allowMultiple: false,
      dialogTitle: 'Photos and videos',
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final path = picked.path;
    if (path == null || path.isEmpty) {
      _showError('Could not read the selected file.');
      return;
    }

    final file = File(path);
    if (ClipboardMediaHelper.isVideoPath(path)) {
      await _checkVideoAndTrim(file);
      return;
    }

    if (ClipboardMediaHelper.isImagePath(path)) {
      setState(() {
        _selectedMedia = file;
        _isVideo = false;
      });
      return;
    }

    _showError('Please choose a photo or video file.');
  }

  Future<void> _createStatus() async {
    if (_isLoading) return;

    if (_selectedMedia == null && _textController.text.trim().isEmpty) {
      _showError('Please add text or select media');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(statusRepositoryProvider);
      if (_statusPrivacy == 'only_share_with' && _privacyIncludedUserIds.isEmpty) {
        _showError(
          'Choose at least one person for “Only selected people”, or change audience.',
        );
        setState(() => _isLoading = false);
        return;
      }
      final audience = StatusRepository.audienceFieldsForStatusPost(
        privacy: _statusPrivacy,
        excludedUserIds: _privacyExcludedUserIds,
        includedUserIds: _privacyIncludedUserIds,
      );

      late final int createdStatusId;

      if (_selectedMedia != null) {
        if (_isVideo) {
          createdStatusId = (await repo.createVideoStatus(
            videoFile: _selectedMedia!,
            caption: _textController.text.isNotEmpty ? _textController.text : null,
            audience: audience,
          ))
              .id;
        } else {
          createdStatusId = (await repo.createImageStatus(
            imageFile: _selectedMedia!,
            caption: _textController.text.isNotEmpty ? _textController.text : null,
            audience: audience,
          ))
              .id;
        }
      } else {
        createdStatusId = (await repo.createTextStatus(
          text: _textController.text.trim(),
          backgroundColor: '#${_selectedColor.value.toRadixString(16).substring(2)}',
          fontSize: statusTextFontSizeIntForLength(_textController.text.trim().length),
          audience: audience,
        ))
            .id;
      }

      if (_mentionedTargets.isNotEmpty) {
        await _sendStatusMentionAlerts(createdStatusId);
      }

      ProductAnalytics.action('status_posted', feature: 'status');

      if (mounted) {
        Navigator.pop(context, true);
                context.showSuccessToast(
              _mentionedTargets.isNotEmpty
                  ? 'Status posted. Mention alerts sent to ${_mentionedTargets.length} contact(s).'
                  : 'Status posted successfully',
            );      }
    } catch (e) {
      _showError('Failed to create status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
        context.showInfoToast(message);  }

  Future<void> _pickMentionTargets() async {
    final selected = await showDialog<List<_StatusMentionTarget>>(
      context: context,
      builder: (ctx) => _StatusMentionPickerDialog(
        initialSelection: List<_StatusMentionTarget>.from(_mentionedTargets),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _mentionedTargets
        ..clear()
        ..addAll(selected);
    });
  }

  int? _parseConversationIdFromStartResponse(dynamic raw) {
    if (raw is! Map) return null;
    final data = raw['data'];
    if (data is Map) {
      final id = data['id'] ?? data['conversation_id'];
      if (id is int) return id;
      if (id is num) return id.toInt();
      if (id is String) return int.tryParse(id);
      final conv = data['conversation'];
      if (conv is Map && conv['id'] != null) {
        final cid = conv['id'];
        if (cid is int) return cid;
        if (cid is num) return cid.toInt();
        if (cid is String) return int.tryParse(cid);
      }
    }
    final top = raw['id'];
    if (top is int) return top;
    if (top is num) return top.toInt();
    if (top is String) return int.tryParse(top);
    return null;
  }

  Future<void> _sendStatusMentionAlerts(int statusId) async {
    final api = ref.read(apiServiceProvider);
    final chatRepo = ref.read(chatRepositoryProvider);
    for (final target in _mentionedTargets) {
      try {
        final response = await api.startConversation(target.userId);
        final conversationId =
            _parseConversationIdFromStartResponse(response.data);
        if (conversationId == null) continue;

        await chatRepo.sendMessageToConversation(
          conversationId: conversationId,
          body: 'You were mentioned in my status',
          referencedStatusId: statusId,
        );
      } catch (e) {
        debugPrint(
          'Failed to send status mention alert to ${target.userId}: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
                // Media preview or text input
                if (_selectedMedia != null)
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isVideo
                        ? const Center(child: Icon(Icons.videocam, size: 64))
                        : Image.file(_selectedMedia!, fit: BoxFit.cover),
                  )
                else
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _textController,
                      maxLength: kStatusTextMaxLength,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(kStatusTextMaxLength),
                      ],
                      style: TextStyle(
                        fontSize: statusTextFontSizeForLength(
                          _textController.text.trim().length,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Colors.transparent,
                        hintText: 'Type a status...',
                        hintStyle: TextStyle(color: Colors.white70),
                        contentPadding: EdgeInsets.all(24),
                        counterText: '',
                      ),
                      maxLines: null,
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                
                // Caption input for media
                if (_selectedMedia != null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _showEmojiPicker = !_showEmojiPicker;
                          });
                        },
                      ),
                    ),
                    maxLines: 3,
                  ),
                  if (_showEmojiPicker)
                    Container(
                      height: 250,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF202C33) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3B4A54) : Colors.grey[300]!,
                        ),
                      ),
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          _textController.text = _textController.text + emoji.emoji;
                        },
                        config: const Config(
                          height: 250,
                          checkPlatformCompatibility: true,
                        ),
                      ),
                    ),
                ],
                
                const SizedBox(height: 24),

                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Audience'),
                  subtitle: Text(_privacySummary()),
                  onTap: _isLoading ? null : _openPrivacyEditor,
                ),

                const SizedBox(height: 8),
                
                // Color picker (for text status)
                if (_selectedMedia == null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _backgroundColors.map((color) {
                      final isSelected = color == _selectedColor;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                
                const SizedBox(height: 24),
                
                // Pick media button
                OutlinedButton.icon(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(_selectedMedia != null ? 'Change Media' : 'Add Photo/Video'),
                ),
                if (_mentionedTargets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Will notify: ${_mentionedTargets.map((e) => e.name).join(', ')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
    );

    if (widget.forModal) {
      return Column(
        children: [
          Expanded(child: content),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              onPressed: _isLoading ? null : _createStatus,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008069),
                minimumSize: const Size.fromHeight(44),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Share status'),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Create Status'),
        actions: [
          IconButton(
            tooltip: 'Who can see your status',
            onPressed: _isLoading ? null : _openPrivacyEditor,
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
          IconButton(
            tooltip: 'Mention people in this status',
            onPressed: _isLoading ? null : _pickMentionTargets,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.alternate_email_rounded),
                if (_mentionedTargets.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: const BoxDecoration(
                        color: Color(0xFF008069),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '${_mentionedTargets.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _createStatus,
            child: const Text('Share'),
          ),
        ],
      ),
      body: content,
    );
  }
}

class _StatusMentionTarget {
  final int userId;
  final String name;
  final String? avatarUrl;

  const _StatusMentionTarget({
    required this.userId,
    required this.name,
    this.avatarUrl,
  });
}

class _StatusMentionPickerDialog extends ConsumerStatefulWidget {
  final List<_StatusMentionTarget> initialSelection;

  const _StatusMentionPickerDialog({required this.initialSelection});

  @override
  ConsumerState<_StatusMentionPickerDialog> createState() =>
      _StatusMentionPickerDialogState();
}

class _StatusMentionPickerDialogState
    extends ConsumerState<_StatusMentionPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<_StatusMentionTarget> _contacts = [];
  late Set<int> _selectedUserIds;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedUserIds = widget.initialSelection.map((e) => e.userId).toSet();
    _loadPeople();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conversations = await repo.getConversations();
      final mapped = <_StatusMentionTarget>[];
      final seen = <int>{};

      for (final conversation in conversations) {
        if (conversation.isSavedMessages) continue;
        final user = conversation.otherUser;
        if (user.id <= 0 || seen.contains(user.id)) continue;
        seen.add(user.id);
        mapped.add(
          _StatusMentionTarget(
            userId: user.id,
            name: user.name,
            avatarUrl: user.avatarUrl,
          ),
        );
      }

      for (final initial in widget.initialSelection) {
        if (seen.contains(initial.userId)) continue;
        seen.add(initial.userId);
        mapped.add(initial);
      }

      mapped.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (mounted) {
        setState(() {
          _contacts = mapped;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_StatusMentionTarget> _currentSelection() {
    final selected = _contacts
        .where((c) => _selectedUserIds.contains(c.userId))
        .toList();
    final foundIds = selected.map((e) => e.userId).toSet();
    for (final initial in widget.initialSelection) {
      if (_selectedUserIds.contains(initial.userId) &&
          !foundIds.contains(initial.userId)) {
        selected.add(initial);
      }
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = _searchController.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _contacts
        : _contacts
            .where(
              (c) =>
                  c.name.toLowerCase().contains(q) ||
                  (c.userId.toString().contains(q)),
            )
            .toList();

    return AlertDialog(
      title: const Text('Mention people'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search people',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No people found.'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final checked = _selectedUserIds.contains(c.userId);
                            return CheckboxListTile(
                              value: checked,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedUserIds.add(c.userId);
                                  } else {
                                    _selectedUserIds.remove(c.userId);
                                  }
                                });
                              },
                              title: Text(c.name),
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    AvatarUtils.getColorForName(c.name),
                                backgroundImage:
                                    resolveStorageUrl(c.avatarUrl) != null
                                    ? CachedNetworkImageProvider(
                                        resolveStorageUrl(c.avatarUrl)!,
                                      )
                                    : null,
                                child: resolveStorageUrl(c.avatarUrl) == null
                                    ? Text(
                                        c.name.isNotEmpty
                                            ? c.name[0].toUpperCase()
                                            : '?',
                                        style:
                                            const TextStyle(color: Colors.white),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _currentSelection()),
          child: Text(
            _selectedUserIds.isEmpty
                ? 'Done'
                : 'Done (${_selectedUserIds.length})',
          ),
        ),
      ],
      backgroundColor: isDark ? const Color(0xFF202C33) : null,
    );
  }
}

