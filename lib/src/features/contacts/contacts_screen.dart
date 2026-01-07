import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contacts_repository.dart';
import '../chats/models.dart';
import '../chats/chat_repo.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  late Future<List<GekyContact>> _contactsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() {
    final repo = ref.read(contactsRepositoryProvider);
    setState(() {
      _contactsFuture = repo.listContacts();
    });
  }

  Future<void> _startConversation(BuildContext context, GekyContact contact) async {
    try {
      // Get the user ID - use contactUserId or contactUser['id']
      final userId = contact.contactUserId ?? contact.contactUser?['id'];
      
      if (userId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User ID not available for this contact'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final chatRepo = ref.read(chatRepositoryProvider);
      
      // Try to find existing conversation first
      final conversations = await chatRepo.getConversations();
      ConversationSummary? existingConversation;
      try {
        existingConversation = conversations.firstWhere(
          (c) => c.otherUser.id == userId,
        );
      } catch (e) {
        // Conversation doesn't exist, create it
      }
      
      // Start new conversation if it doesn't exist
      if (existingConversation == null) {
        await chatRepo.startConversation(userId as int);
      }
      
      // Navigate back to chats - the conversation will be in the list
      if (context.mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/chats');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation started! Find it in your chats.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _inviteContact(BuildContext context, GekyContact contact) async {
    if (contact.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact has no phone number')),
      );
      return;
    }

    final inviteMessage = 'Hi! Join me on GekyChat - a secure messaging app. Download it here: https://gekychat.com';
    
    // Try SMS first, fallback to email if available
    final smsUri = Uri.parse('sms:${contact.phone}?body=${Uri.encodeComponent(inviteMessage)}');
    
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      // Fallback: show share dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invite Contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Send this message to ${contact.name}:'),
                const SizedBox(height: 8),
                SelectableText(inviteMessage),
              ],
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/chats');
            }
          },
        ),
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<GekyContact>>(
              future: _contactsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${snapshot.error}'),
                        ElevatedButton(
                          onPressed: _loadContacts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final contacts = snapshot.data ?? [];
                final filtered = _searchQuery.isEmpty
                    ? contacts
                    : contacts.where((c) {
                        return c.name.toLowerCase().contains(_searchQuery) ||
                            (c.phone ?? '').toLowerCase().contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'No contacts' : 'No contacts found',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: contact.avatarUrl != null
                            ? CachedNetworkImageProvider(contact.avatarUrl!)
                            : null,
                        child: contact.avatarUrl == null
                            ? Text((contact.name.isNotEmpty ? contact.name[0] : '?').toUpperCase())
                            : null,
                      ),
                      title: Text(contact.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (contact.phone != null) Text(contact.phone!),
                          const SizedBox(height: 4),
                          contact.isRegistered
                              ? const Text(
                                  'Registered on GekyChat',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                )
                              : const Text(
                                  'Not registered on GekyChat',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                        ],
                      ),
                      trailing: contact.isRegistered
                          ? IconButton(
                              icon: const Icon(Icons.message),
                              onPressed: () => _startConversation(context, contact),
                              tooltip: 'Start conversation',
                            )
                          : IconButton(
                              icon: const Icon(Icons.person_add_alt_1),
                              onPressed: () => _inviteContact(context, contact),
                              tooltip: 'Invite to GekyChat',
                            ),
                      onTap: contact.isRegistered
                          ? () => _startConversation(context, contact)
                          : () => _inviteContact(context, contact),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

