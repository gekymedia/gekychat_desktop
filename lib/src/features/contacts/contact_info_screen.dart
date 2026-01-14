import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../chats/models.dart';
import '../chats/chat_repo.dart';
import 'contacts_repository.dart';

class ContactInfoScreen extends ConsumerStatefulWidget {
  final User user;

  const ContactInfoScreen({super.key, required this.user});

  @override
  ConsumerState<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends ConsumerState<ContactInfoScreen> {
  bool _isContact = false;
  bool _isChecking = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkIfContact();
  }

  Future<void> _checkIfContact() async {
    if (widget.user.phone == null) {
      setState(() {
        _isContact = false;
        _isChecking = false;
      });
      return;
    }

    try {
      final contactsRepo = ref.read(contactsRepositoryProvider);
      final contacts = await contactsRepo.listContacts();
      setState(() {
        _isContact = contacts.any((c) => c.phone == widget.user.phone);
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _isContact = false;
        _isChecking = false;
      });
    }
  }

  Future<void> _saveContact() async {
    if (widget.user.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final contactsRepo = ref.read(contactsRepositoryProvider);
      await contactsRepo.saveContact(
        displayName: widget.user.name,
        phone: widget.user.phone!,
        contactUserId: widget.user.id,
      );
      
      if (mounted) {
        setState(() {
          _isContact = true;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save contact: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Contact Info'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
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
                    backgroundImage: widget.user.avatarUrl != null
                        ? CachedNetworkImageProvider(widget.user.avatarUrl!)
                        : null,
                    child: widget.user.avatarUrl == null
                        ? Text(
                            widget.user.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 40),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  if (widget.user.phone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.user.phone!,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ],
                  if (widget.user.isOnline == true)
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
                  else if (widget.user.lastSeenAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last seen ${_formatLastSeen(widget.user.lastSeenAt!)}',
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
            Card(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              child: Column(
                children: [
                  if (!_isContact && widget.user.phone != null)
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
                        final conversationId = await chatRepo.startConversation(widget.user.id);
                        
                        if (mounted) {
                          Navigator.pop(context); // Close contact info
                          // Navigate to chats
                          context.go('/chats');
                          // Select the conversation programmatically
                          ref.read(selectedConversationProvider.notifier).selectConversation(conversationId);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to start conversation: $e')),
                          );
                        }
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
            const SizedBox(height: 8),

            // Media, Links, and Docs
            Card(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              child: ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Media, Links, and Docs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to media gallery
                },
              ),
            ),
            const SizedBox(height: 8),

            // More Options
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
          ],
        ),
      ),
    );
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

  void _showBlockDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: const Text('Block Contact'),
        content: Text('Block ${widget.user.name}? You will no longer receive messages or calls from this contact.'),
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
                await apiService.blockUser(widget.user.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.user.name} has been blocked')),
                  );
                  Navigator.pop(context); // Close contact info screen
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to block contact: $e')),
                  );
                }
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason')),
                );
                return;
              }

              Navigator.pop(context);
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.reportUser(widget.user.id, reason);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to submit report: $e')),
                  );
                }
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

