import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../chats/models.dart';
import '../chats/chat_providers.dart';
import '../chats/hidden_chat/hidden_chat_setup_flow.dart';
import '../chats/create_group_screen.dart';
import '../labels/labels_repository.dart';
import '../media/media_gallery_screen.dart';
import '../media/media_repository.dart';
import '../../widgets/constrained_slide_route.dart';
import '../../services/hidden_chat_service.dart';
import 'add_to_group_sheet.dart';
import 'contacts_repository.dart';
import 'edit_gekychat_contact_dialog.dart';
import '../../utils/phone_matcher.dart';
import '../../utils/snackbar_helper.dart';

const _waGreen = Color(0xFF00A884);
const _waRed = Color(0xFFEA4335);
const _cardDark = Color(0xFF202C33);
const _pageDark = Color(0xFF0B141A);

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
  List<GroupSummary> _commonGroups = const [];
  bool _loadingCommonGroups = false;
  bool _isHidden = false;

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
      unawaited(_loadCommonGroups(user.id));
    } catch (e) {
      debugPrint('ContactInfoScreen._loadProfile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        await _checkIfContact();
      }
    }
  }

  Future<void> _loadCommonGroups(int userId) async {
    if (userId <= 0) return;
    setState(() => _loadingCommonGroups = true);
    try {
      final groups =
          await ref.read(contactsRepositoryProvider).getCommonGroups(userId);
      if (mounted) {
        setState(() {
          _commonGroups = groups;
          _loadingCommonGroups = false;
        });
      }
    } catch (e) {
      debugPrint('ContactInfoScreen._loadCommonGroups: $e');
      if (mounted) setState(() => _loadingCommonGroups = false);
    }
  }

  Future<void> _initializeConversationId() async {
    final directId = widget.conversationId;
    if (directId != null && directId > 0) {
      if (mounted) {
        setState(() => _currentConversationId = directId);
      }
      await _refreshHiddenState(directId);
      return;
    }

    if (widget.isSavedMessages || _isSelfChat(ref)) return;

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conversationId = await chatRepo.startConversation(widget.user.id);
      if (mounted) {
        setState(() => _currentConversationId = conversationId);
      }
      await _refreshHiddenState(conversationId);
    } catch (e) {
      debugPrint('No existing conversation with ${widget.user.id}: $e');
    }
  }

  Future<void> _refreshHiddenState(int? conversationId) async {
    if (conversationId == null || conversationId <= 0) return;
    final hidden =
        await ref.read(hiddenChatServiceProvider).isHidden(conversationId);
    if (mounted) setState(() => _isHidden = hidden);
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
          final profile =
              await ref.read(contactsRepositoryProvider).getUserProfile(user.id);
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
      context.showErrorToast('Phone number not available');
      return;
    }

    setState(() => _isSaving = true);

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
        context.showSuccessToast('Contact saved successfully');
      }
    } on ContactAlreadyExistsException {
      GekyContact? existing;
      try {
        existing =
            await ref.read(contactsRepositoryProvider).getGekyContactForUser(
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
        setState(() => _isSaving = false);
        context.showErrorToast('Failed to save contact: $e');
      }
    }
  }

  Future<void> _editInGekyChat() async {
    final user = _user;
    if (!_isContact && _gekyContact == null) {
      context.showWarningToast('Save this contact first to edit it');
      return;
    }

    final contactsRepo = ref.read(contactsRepositoryProvider);
    final phoneHint = user.phone ?? widget.user.phone ?? _gekyContact?.phone;

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

  Color _cardColor(bool isDark) => isDark ? _cardDark : Colors.white;

  Widget _sectionCard({required bool isDark, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardColor(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildMediaSection(bool isDark) {
    final conversationId = _resolvedConversationId;
    if (conversationId == null || conversationId <= 0) {
      return const SizedBox.shrink();
    }

    final galleryAsync =
        ref.watch(conversationMediaGalleryProvider(conversationId));

    return galleryAsync.when(
      loading: () => _sectionCard(
        isDark: isDark,
        children: [
          ListTile(
            title: const Text('Media, links and docs'),
            trailing: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            onTap: () => _openMediaGallery(context),
          ),
        ],
      ),
      error: (_, __) => _sectionCard(
        isDark: isDark,
        children: [
          ListTile(
            title: Text(
              'Media, links and docs',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            onTap: () => _openMediaGallery(context),
          ),
        ],
      ),
      data: (gallery) {
        final allMedia = [...gallery.images, ...gallery.videos];
        final count = allMedia.length +
            gallery.documents.length +
            gallery.links.length;
        // Single horizontal row only — never wrap to 2 rows on iPhone.
        final previewItems = allMedia.take(8).toList();

        return _sectionCard(
          isDark: isDark,
          children: [
            ListTile(
              title: Text(
                'Media, links and docs',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
              onTap: () => _openMediaGallery(context),
            ),
            if (previewItems.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: previewItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final attachment = previewItems[index];
                    final isVideo = attachment.isVideo ||
                        attachment.mimeType
                            .toLowerCase()
                            .startsWith('video/');
                    final imageUrl = attachment.thumbnailUrl ??
                        attachment.compressedUrl ??
                        attachment.url;
                    return GestureDetector(
                      onTap: () => _openMediaGallery(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 64,
                                height: 64,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                            if (isVideo)
                              const Positioned.fill(
                                child: Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _openMediaGallery(BuildContext context) {
    final conversationId = _resolvedConversationId;
    if (conversationId == null || conversationId <= 0) {
      context.showErrorToast('Conversation not available yet');
      return;
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

  Future<void> _startMessage() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conversationId = await chatRepo.startConversation(_user.id);
      if (!mounted) return;
      if (widget.embedded) {
        widget.onClose?.call();
      } else if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
      context.go('/chats');
      ref
          .read(selectedConversationProvider.notifier)
          .selectConversation(conversationId);
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to start conversation: $e');
      }
    }
  }

  Future<void> _shareContact() async {
    final user = _user;
    final buffer = StringBuffer(user.name);
    if (user.phone != null && user.phone!.isNotEmpty) {
      buffer.writeln();
      buffer.write(user.phone);
    }
    await Share.share(buffer.toString(), subject: user.name);
  }

  Future<void> _exportChat() async {
    final conversationId = _resolvedConversationId;
    if (conversationId == null || conversationId <= 0) {
      context.showErrorToast('Conversation not available yet');
      return;
    }
    try {
      final content = await ref
          .read(chatRepositoryProvider)
          .exportConversation(conversationId);
      if (!mounted) return;
      await Share.share(content, subject: 'Chat with ${_user.name}');
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to export chat: $e');
      }
    }
  }

  Future<void> _clearChat() async {
    final conversationId = _resolvedConversationId;
    if (conversationId == null || conversationId <= 0) {
      context.showErrorToast('Conversation not available yet');
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor(isDark),
        title: const Text('Clear chat?'),
        content: const Text(
          'Are you sure you want to clear all messages in this chat?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _waRed),
            child: const Text('Clear chat'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).clearConversation(conversationId);
      if (mounted) context.showSuccessToast('Chat cleared');
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to clear chat: $e');
    }
  }

  Future<void> _addToList() async {
    final conversationId = _resolvedConversationId;
    if (conversationId == null || conversationId <= 0) {
      context.showErrorToast('Conversation not available yet');
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      final labelsRepo = ref.read(labelsRepositoryProvider);
      final labels = await labelsRepo.getLabels();
      if (!mounted) return;
      if (labels.isEmpty) {
        context.showInfoToast('No labels yet. Create one in Settings.');
        return;
      }
      final selected = await showDialog<Label>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardColor(isDark),
          title: const Text('Add to list'),
          content: SizedBox(
            width: 320,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: labels.length,
              itemBuilder: (context, index) {
                final label = labels[index];
                return ListTile(
                  leading: const Icon(Icons.label_outline, color: _waGreen),
                  title: Text(label.name),
                  onTap: () => Navigator.pop(context, label),
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
      if (selected == null || !mounted) return;
      await labelsRepo.attachLabelToConversation(selected.id, conversationId);
      if (mounted) {
        context.showSuccessToast('Added to ${selected.name}');
      }
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to add to list: $e');
    }
  }

  Future<void> _toggleChatLock() async {
    final conversationId = _resolvedConversationId;
    if (conversationId == null || conversationId <= 0) {
      context.showErrorToast('Conversation not available yet');
      return;
    }
    final service = ref.read(hiddenChatServiceProvider);
    if (_isHidden) {
      await service.unhideConversation(conversationId);
      if (mounted) {
        setState(() => _isHidden = false);
        context.showInfoToast('Chat unlocked and visible in inbox');
      }
      return;
    }
    await HiddenChatSetupFlow.start(
      context,
      ref,
      conversationIdToHide: conversationId,
    );
    await _refreshHiddenState(conversationId);
    if (_isHidden && mounted) {
      if (widget.embedded) {
        widget.onClose?.call();
      } else if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
      final selected = ref.read(selectedConversationProvider);
      if (selected == conversationId) {
        ref.read(selectedConversationProvider.notifier).clearSelection();
      }
    }
  }

  Widget _greenAction({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            color: _waGreen,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _redAction({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            color: _waRed,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 16,
        color: isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF),
      );

  Widget _buildGroupsSection(bool isDark) {
    final count = _commonGroups.length;
    final header = count == 1
        ? '1 group in common'
        : '$count groups in common';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 16, 6),
          child: Text(
            _loadingCommonGroups ? 'Groups in common' : header,
            style: TextStyle(
              color: isDark ? const Color(0xFF8696A0) : Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _sectionCard(
          isDark: isDark,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _waGreen.withValues(alpha: 0.15),
                child: const Icon(Icons.add, color: _waGreen),
              ),
              title: Text(
                'Create group with ${_user.name}',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                CreateGroupScreen.showModal(
                  context,
                  initialMemberIds: _user.id > 0 ? [_user.id] : const [],
                );
              },
            ),
            _divider(isDark),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _waGreen.withValues(alpha: 0.15),
                child: const Icon(Icons.group_add, color: _waGreen),
              ),
              title: Text(
                'Add to group',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () => AddToGroupSheet.show(context, _user),
            ),
            if (_loadingCommonGroups) ...[
              _divider(isDark),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ] else
              for (var i = 0; i < _commonGroups.length; i++) ...[
                _divider(isDark),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isDark ? const Color(0xFF2A3942) : Colors.grey.shade200,
                    backgroundImage: _commonGroups[i].avatarUrl != null
                        ? CachedNetworkImageProvider(
                            _commonGroups[i].avatarUrl!,
                          )
                        : null,
                    child: _commonGroups[i].avatarUrl == null
                        ? Text(
                            _commonGroups[i].name.isNotEmpty
                                ? _commonGroups[i].name[0].toUpperCase()
                                : 'G',
                          )
                        : null,
                  ),
                  title: Text(
                    _commonGroups[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  subtitle: _commonGroups[i].memberCount != null
                      ? Text(
                          '${_commonGroups[i].memberCount} members',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF8696A0)
                                : Colors.black54,
                          ),
                        )
                      : null,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  onTap: () {
                    ref.read(pendingDesktopGroupSelectProvider.notifier).state =
                        _commonGroups[i].id;
                    if (widget.embedded) {
                      widget.onClose?.call();
                    } else if (Navigator.of(context).canPop()) {
                      Navigator.pop(context);
                    }
                    context.go('/chats');
                  },
                ),
              ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
    final muted = isDark ? const Color(0xFF8696A0) : Colors.black54;

    final body = _isLoadingProfile
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    final avatarRadius = isNarrow ? 42.0 : 50.0;
                    final nameFontSize = isNarrow ? 20.0 : 24.0;
                    final phoneFontSize = isNarrow ? 13.0 : 14.0;
                    final verticalPadding = isNarrow ? 16.0 : 24.0;

                    return Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      padding: EdgeInsets.all(verticalPadding),
                      decoration: BoxDecoration(
                        color: _cardColor(isDark),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: isSelfChat
                                ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                                : null,
                            backgroundImage: !isSelfChat &&
                                    user.avatarUrl != null
                                ? CachedNetworkImageProvider(user.avatarUrl!)
                                : null,
                            child: isSelfChat
                                ? Icon(
                                    Icons.bookmark,
                                    size: avatarRadius * 0.88,
                                    color: AppTheme.primaryGreen,
                                  )
                                : user.avatarUrl == null
                                    ? Text(
                                        user.name.isNotEmpty
                                            ? user.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: avatarRadius * 0.8,
                                        ),
                                      )
                                    : null,
                          ),
                          SizedBox(height: isNarrow ? 12 : 16),
                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: nameFontSize,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          if (!isSelfChat && user.phone != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              user.phone!,
                              style: TextStyle(
                                fontSize: phoneFontSize,
                                color: muted,
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
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontSize: phoneFontSize,
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
                                color: muted,
                                fontSize: phoneFontSize - 1,
                              ),
                            ),
                          ],
                          if (!isSelfChat) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _quickAction(
                                  icon: Icons.message,
                                  label: 'Message',
                                  onTap: _startMessage,
                                ),
                                _quickAction(
                                  icon: Icons.call,
                                  label: 'Audio',
                                  onTap: () {},
                                ),
                                _quickAction(
                                  icon: Icons.videocam,
                                  label: 'Video',
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),

                if (!isSelfChat)
                  _sectionCard(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: Icon(Icons.lock_outline, color: muted),
                        title: Text(
                          'Encryption',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          'Messages and calls are end-to-end encrypted.',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                if (!isSelfChat) const SizedBox(height: 8),

                if (!isSelfChat && !_isChecking && !_isContact && user.phone != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _sectionCard(
                      isDark: isDark,
                      children: [
                        ListTile(
                          leading: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add, color: _waGreen),
                          title: Text(
                            _isSaving ? 'Saving...' : 'Save to Contacts',
                            style: const TextStyle(color: _waGreen),
                          ),
                          onTap: _isSaving ? null : _saveContact,
                        ),
                      ],
                    ),
                  ),

                if (_resolvedConversationId != null &&
                    _resolvedConversationId! > 0) ...[
                  _buildMediaSection(isDark),
                  const SizedBox(height: 8),
                ],

                if (!isSelfChat) ...[
                  _buildGroupsSection(isDark),
                  const SizedBox(height: 8),
                ],

                if (!isSelfChat &&
                    _resolvedConversationId != null &&
                    _resolvedConversationId! > 0) ...[
                  _sectionCard(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: Icon(
                          _isHidden ? Icons.lock_open : Icons.lock_outline,
                          color: muted,
                        ),
                        title: Text(
                          _isHidden ? 'Unlock chat' : 'Chat lock',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          _isHidden
                              ? 'Hidden on this device — tap to unlock'
                              : 'Lock and hide this chat on this device',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: muted,
                        ),
                        onTap: _toggleChatLock,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                if (!isSelfChat) ...[
                  _sectionCard(
                    isDark: isDark,
                    children: [
                      _greenAction(
                        label: 'Share contact',
                        onTap: _shareContact,
                        isDark: isDark,
                      ),
                      _divider(isDark),
                      _greenAction(
                        label: 'Add to list',
                        onTap: _addToList,
                        isDark: isDark,
                      ),
                      if (_resolvedConversationId != null &&
                          _resolvedConversationId! > 0) ...[
                        _divider(isDark),
                        _greenAction(
                          label: 'Export chat',
                          onTap: _exportChat,
                          isDark: isDark,
                        ),
                        _divider(isDark),
                        _redAction(
                          label: 'Clear chat',
                          onTap: _clearChat,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _sectionCard(
                    isDark: isDark,
                    children: [
                      _redAction(
                        label: 'Block ${user.name}',
                        onTap: () => _showBlockDialog(context, isDark),
                      ),
                      _divider(isDark),
                      _redAction(
                        label: 'Report ${user.name}',
                        onTap: () => _showReportDialog(context, isDark),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );

    if (widget.embedded) {
      return ColoredBox(
        color: isDark ? _pageDark : const Color(0xFFF0F2F5),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _cardColor(isDark),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF2A3942)
                        : const Color(0xFFD1D7DB),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
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
      backgroundColor: isDark ? _pageDark : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(panelTitle),
        backgroundColor: _cardColor(isDark),
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

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: _waGreen, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _waGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }

    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfThatDay = DateTime(local.year, local.month, local.day);
    final dayDiff = startOfToday.difference(startOfThatDay).inDays;

    if (dayDiff == 0) return 'today at ${timeOfDay(local)}';
    if (dayDiff == 1) return 'yesterday at ${timeOfDay(local)}';
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
        backgroundColor: _cardColor(isDark),
        title: const Text('Block Contact'),
        content: Text(
          'Block ${user.name}? You will no longer receive messages or calls from this contact.',
        ),
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
                  context.showSuccessToast('${user.name} has been blocked');
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  context.showErrorToast('Failed to block contact: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: _waRed),
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
        backgroundColor: _cardColor(isDark),
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
                hintText:
                    'Enter reason (e.g., spam, harassment, inappropriate content)',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _waRed),
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
                context.showInfoToast('Please enter a reason');
                return;
              }

              Navigator.pop(context);
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.reportUser(user.id, reason);
                if (context.mounted) {
                  context.showSuccessToast('Report submitted successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  context.showErrorToast('Failed to report contact: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: _waRed),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}
