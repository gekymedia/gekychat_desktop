import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../chats/models.dart';
import '../chats/chat_providers.dart';
import '../media/media_gallery_screen.dart';
import '../../widgets/constrained_slide_route.dart';
import 'contacts_repository.dart';
import 'edit_gekychat_contact_dialog.dart';
import '../../utils/phone_matcher.dart';
import '../../utils/snackbar_helper.dart';

class ContactInfoScreen extends ConsumerStatefulWidget {
  final User user;
  final bool embedded;
  final VoidCallback? onClose;
  final bool isSavedMessages;
  final int? conversationId;

  const ContactInfoScreen({
    super.key,
    required this.user,
    this.embedded = false,
    this.onClose,
    this.isSavedMessages = false,
    this.conversationId,
  });

  @override
  ConsumerState<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends ConsumerState<ContactInfoScreen> {
  bool _isContact = false;
  bool _isChecking = true;
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  int? _currentConversationId;
  User? _displayUser;
  GekyContact? _gekyContact;

  User get _user => _displayUser ?? widget.user;

  bool _isSelfChat(WidgetRef ref) {
    if (widget.isSavedMessages) return true;
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (me != null && _user.id > 0 && me.id == _user.id) return true;
    return _user.name.trim().toLowerCase() == 'saved messages';
  }

  @override
  void initState() {
    super.initState();
    _displayUser = widget.user;
    _loadProfile();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversationId();
    });
  }

  Future<void> _loadProfile() async {
    if (widget.user.id <= 0) {
      await _checkIfContact();
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final contactsRepo = ref.read(contactsRepositoryProvider);
      final profile = await contactsRepo.getUserProfile(widget.user.id);
      if (!mounted) return;

      var user = profile.user;
      final savedName = widget.user.name.trim();
      final preferSavedName = savedName.isNotEmpty &&
          savedName != 'Unknown' &&
          !savedName.startsWith('DM #') &&
          user.name != savedName;
      // Keep chat/list phone when profile omits it (privacy or unlinked contact).
      user = User(
        id: user.id,
        name: preferSavedName ? savedName : user.name,
        phone: user.phone ?? widget.user.phone,
        avatarUrl: user.avatarUrl ?? widget.user.avatarUrl,
        isOnline: user.isOnline,
        lastSeenAt: user.lastSeenAt,
      );

      setState(() {
        _displayUser = user;
        _isContact = profile.isContact || profile.gekyContact != null;
        _gekyContact = profile.gekyContact;
        _isChecking = false;
        _isLoadingProfile = false;
      });

      if (!_isContact || _gekyContact == null) {
        await _checkIfContact(user: user);
      }
    } catch (e) {
      debugPrint('ContactInfoScreen._loadProfile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        await _checkIfContact();
      }
    }
  }
  
  Future<void> _initializeConversationId() async {
    final directId = widget.conversationId;
    if (directId != null && directId > 0) {
      if (mounted) {
        setState(() => _currentConversationId = directId);
      }
      return;
    }

    if (widget.isSavedMessages || _isSelfChat(ref)) return;

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      // Try to get existing conversation with this user
      final conversationId = await chatRepo.startConversation(widget.user.id);
      if (mounted) {
        setState(() {
          _currentConversationId = conversationId;
        });
      }
    } catch (e) {
      // User might not have a conversation yet, that's okay
      debugPrint('No existing conversation with ${widget.user.id}: $e');
    }
  }

  Future<void> _checkIfContact({User? user}) async {
    final target = user ?? _user;
    if (target.id <= 0 &&
        (target.phone == null || target.phone!.trim().isEmpty)) {
      setState(() {
        _isContact = false;
        _isChecking = false;
      });
      return;
    }

    try {
      final contactsRepo = ref.read(contactsRepositoryProvider);
      final matched = await contactsRepo.isUserInContacts(
        userId: target.id > 0 ? target.id : null,
        phone: target.phone ?? widget.user.phone,
      );
      GekyContact? geky = _gekyContact;
      if (matched || geky == null) {
        geky = await contactsRepo.getGekyContactForUser(
          userId: target.id > 0 ? target.id : null,
          phone: target.phone ?? widget.user.phone ?? geky?.phone,
        );
      }
      if (mounted) {
        setState(() {
          _isContact = matched || geky != null;
          _gekyContact = geky ?? _gekyContact;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isContact = false;
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _saveContact() async {
    final user = _user;
    var phone = user.phone;
    if (phone == null || phone.trim().isEmpty) {
      if (user.id > 0) {
        try {
          final profile = await ref.read(contactsRepositoryProvider).getUserProfile(user.id);
          phone = profile.user.phone;
          if (mounted && phone != null && phone.isNotEmpty) {
            setState(() {
              _displayUser = User(
                id: user.id,
                name: user.name,
                phone: phone,
                avatarUrl: user.avatarUrl,
                isOnline: profile.user.isOnline ?? user.isOnline,
                lastSeenAt: profile.user.lastSeenAt ?? user.lastSeenAt,
              );
            });
          }
        } catch (_) {}
      }
    }

    if (phone == null || phone.trim().isEmpty) {
            context.showErrorToast('Phone number not available');      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final contactsRepo = ref.read(contactsRepositoryProvider);
      final saved = await contactsRepo.saveContact(
        displayName: user.name,
        phone: PhoneMatcher.normalizeGhanaLoginPhone(phone).isNotEmpty
            ? PhoneMatcher.normalizeGhanaLoginPhone(phone)
            : phone,
        contactUserId: user.id > 0 ? user.id : null,
      );
      
      if (mounted) {
        setState(() {
          _isContact = true;
          _gekyContact = saved;
          _isSaving = false;
        });
                context.showSuccessToast('Contact saved successfully');      }
    } on ContactAlreadyExistsException {
      GekyContact? existing;
      try {
        existing = await ref.read(contactsRepositoryProvider).getGekyContactForUser(
          userId: user.id > 0 ? user.id : null,
          phone: phone,
        );
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isContact = true;
          _gekyContact = existing ?? _gekyContact;
          _isSaving = false;
        });
        context.showSuccessToast('Contact is already saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
                context.showErrorToast('Failed to save contact: $e');      }
    }
  }

  Future<void> _editInGekyChat() async {
    final user = _user;
    if (!_isContact && _gekyContact == null) {
      context.showWarningToast('Save this contact first to edit it');
      return;
    }

    final contactsRepo = ref.read(contactsRepositoryProvider);
    final phoneHint =
        user.phone ?? widget.user.phone ?? _gekyContact?.phone;

    // Always resolve a fresh contact row id (profile contact_data, then search).
    var gekyContact = await contactsRepo.getGekyContactForUser(
      userId: user.id > 0 ? user.id : null,
      phone: phoneHint,
    );
    gekyContact ??= _gekyContact;

    if (gekyContact == null || gekyContact.id <= 0) {
      if (mounted) {
        context.showWarningToast('Contact not found in GekyChat');
      }
      return;
    }

    if (!mounted) return;

    setState(() => _gekyContact = gekyContact);

    final result = await showEditGekyChatContactDialog(
      context,
      displayName: gekyContact.name.trim().isNotEmpty
          ? gekyContact.name.trim()
          : user.name,
      phone: gekyContact.phone?.trim().isNotEmpty == true
          ? gekyContact.phone!.trim()
          : (phoneHint ?? ''),
      note: gekyContact.note,
    );

    if (result == null || !mounted) return;

    try {
      await contactsRepo.updateContact(
        gekyContact.id,
        displayName: result['displayName'],
        phone: result['phone'],
        note: result['note'],
      );

      if (!mounted) return;
      setState(() {
        _displayUser = User(
          id: user.id,
          name: result['displayName'] ?? user.name,
          phone: result['phone'] ?? user.phone,
          avatarUrl: user.avatarUrl,
          isOnline: user.isOnline,
          lastSeenAt: user.lastSeenAt,
        );
        _gekyContact = GekyContact(
          id: gekyContact!.id,
          name: result['displayName'] ?? gekyContact.name,
          phone: result['phone'] ?? gekyContact.phone,
          avatarUrl: gekyContact.avatarUrl,
          isRegistered: gekyContact.isRegistered,
          contactUserId: gekyContact.contactUserId,
          contactUser: gekyContact.contactUser,
          note: result['note'],
        );
        _isContact = true;
      });
      context.showSuccessToast('Contact updated in GekyChat');
      await _loadProfile();
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to update contact: $e');
      }
    }
  }

  int? get _resolvedConversationId =>
      widget.conversationId ?? _currentConversationId;

  void _openMediaGallery(BuildContext context) {
    final conversationId = _resolvedConversationId;
    if (conversationId == null || conversationId <= 0) {
            context.showErrorToast('Conversation not available yet');      return;
    }

    final isSelfChat = _isSelfChat(ref);
    Navigator.push(
      context,
      ConstrainedSlideRightRoute(
        page: MediaGalleryScreen(
          conversationId: conversationId,
          title: isSelfChat ? 'Saved Messages' : _user.name,
        ),
        leftOffset: 400.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Close when another conversation is selected (defer to avoid navigator lock).
    ref.listen<int?>(selectedConversationProvider, (previous, next) {
      final openId = _resolvedConversationId;
      if (next == null || (openId != null && next == openId)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.embedded) {
          widget.onClose?.call();
        } else if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
      });
    });

    final user = _user;
    final isSelfChat = _isSelfChat(ref);
    final panelTitle = isSelfChat ? 'Saved Messages' : 'Contact Info';
    final displayName = isSelfChat ? 'Saved Messages' : user.name;

    final body = _isLoadingProfile
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Contact Header
            Container(
              padding: const EdgeInsets.all(24),
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: isSelfChat
                        ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                        : null,
                    backgroundImage: !isSelfChat && user.avatarUrl != null
                        ? CachedNetworkImageProvider(user.avatarUrl!)
                        : null,
                    child: isSelfChat
                        ? const Icon(
                            Icons.bookmark,
                            size: 44,
                            color: AppTheme.primaryGreen,
                          )
                        : user.avatarUrl == null
                        ? Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 40),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  if (!isSelfChat && user.phone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.phone!,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ],
                  if (!isSelfChat && user.isOnline == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Online',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!isSelfChat && user.lastSeenAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last seen ${_formatLastSeen(user.lastSeenAt!)}',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Actions
            if (!isSelfChat)
            Card(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              child: Column(
                children: [
                  if (!_isChecking && !_isContact && user.phone != null)
                    ListTile(
                      leading: _isSaving 
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add),
                      title: Text(_isSaving ? 'Saving...' : 'Save to Contacts'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isSaving ? null : _saveContact,
                    ),
                  ListTile(
                    leading: const Icon(Icons.message),
                    title: const Text('Message'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      try {
                        final chatRepo = ref.read(chatRepositoryProvider);
                        // Start or get existing conversation
                        final conversationId = await chatRepo.startConversation(user.id);
                        
                        if (mounted) {
                          Navigator.pop(context); // Close contact info
                          // Navigate to chats
                          context.go('/chats');
                          // Select the conversation programmatically
                          ref.read(selectedConversationProvider.notifier).selectConversation(conversationId);
                        }
                      } catch (e) {
                        if (mounted) {
                                                    context.showErrorToast('Failed to start conversation: $e');                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.call),
                    title: const Text('Voice Call'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Start voice call
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.videocam),
                    title: const Text('Video Call'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Start video call
                    },
                  ),
                ],
              ),
            ),
            if (!isSelfChat) const SizedBox(height: 8),

            // Media, Links, and Docs (DM + Saved Messages)
            if (_resolvedConversationId != null && _resolvedConversationId! > 0)
              Card(
                color: isDark ? const Color(0xFF202C33) : Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Media, Links, and Docs'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openMediaGallery(context),
                ),
              ),
            if (_resolvedConversationId != null && _resolvedConversationId! > 0)
              const SizedBox(height: 8),

            // More Options
            if (!isSelfChat)
            Card(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('Block'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showBlockDialog(context, isDark);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.report),
                    title: const Text('Report'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showReportDialog(context, isDark);
                    },
                  ),
                ],
              ),
            ),
            if (!isSelfChat) const SizedBox(height: 8),
          ],
        ),
    );

    if (widget.embedded) {
      return ColoredBox(
        color: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202C33) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.grey[700]),
                    onPressed: widget.onClose,
                    tooltip: 'Close',
                  ),
                  Expanded(
                    child: Text(
                      panelTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  if (!_isChecking && _isContact && !isSelfChat)
                    IconButton(
                      tooltip: 'Edit contact',
                      icon: Icon(
                        Icons.edit_outlined,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                      onPressed: _editInGekyChat,
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(panelTitle),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          if (!_isChecking && _isContact && !isSelfChat)
            IconButton(
              tooltip: 'Edit contact',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editInGekyChat,
            ),
        ],
      ),
      body: body,
    );
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

  void _showBlockDialog(BuildContext context, bool isDark) {
    final user = _user;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: const Text('Block Contact'),
        content: Text('Block ${user.name}? You will no longer receive messages or calls from this contact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.blockUser(user.id);
                if (context.mounted) {
                                    context.showSuccessToast('${user.name} has been blocked');                  Navigator.pop(context); // Close contact info screen
                }
              } catch (e) {
                if (context.mounted) {
                                    context.showErrorToast('Failed to block contact: $e');                }
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, bool isDark) {
    final user = _user;
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: const Text('Report Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this contact?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason (e.g., spam, harassment, inappropriate content)',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                                context.showInfoToast('Please enter a reason');                return;
              }

              Navigator.pop(context);
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.reportUser(user.id, reason);
                if (context.mounted) {
                                    context.showSuccessToast('Report submitted successfully');                }
              } catch (e) {
                if (context.mounted) {
                                    context.showErrorToast('Failed to submit report: $e');                }
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}

