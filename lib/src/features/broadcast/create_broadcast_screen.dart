import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'broadcast_repository.dart';
import '../contacts/contacts_repository.dart';
import '../contacts/contacts_screen.dart';
import '../chats/models.dart' show GekyContact;
import '../../core/providers.dart';

class CreateBroadcastScreen extends ConsumerStatefulWidget {
  const CreateBroadcastScreen({super.key});

  @override
  ConsumerState<CreateBroadcastScreen> createState() => _CreateBroadcastScreenState();
}

class _CreateBroadcastScreenState extends ConsumerState<CreateBroadcastScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<int> _selectedContactIds = {};
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createBroadcastList() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one recipient')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = ref.read(broadcastRepositoryProvider);
      await repo.createBroadcastList(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        recipientIds: _selectedContactIds.toList(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast list created successfully')),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create broadcast list: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contactsRepo = ref.read(contactsRepositoryProvider);
    final contactsFuture = contactsRepo.listContacts();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Create Broadcast List'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _createBroadcastList,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Select Recipients (${_selectedContactIds.length} selected)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<GekyContact>>(
              future: contactsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading contacts: ${snapshot.error}'),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No contacts available',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                }

                final contacts = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    // Use contactUserId (user ID) instead of contact.id for broadcast lists
                    final userId = contact.contactUserId ?? contact.contactUser?['id'];
                    if (userId == null) {
                      // Skip contacts without user IDs (not registered)
                      return const SizedBox.shrink();
                    }
                    final isSelected = _selectedContactIds.contains(userId);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedContactIds.add(userId);
                          } else {
                            _selectedContactIds.remove(userId);
                          }
                        });
                      },
                      title: Text(contact.name),
                      subtitle: contact.phone != null ? Text(contact.phone!) : null,
                      secondary: CircleAvatar(
                        backgroundImage: contact.avatarUrl != null
                            ? CachedNetworkImageProvider(contact.avatarUrl!)
                            : null,
                        child: contact.avatarUrl == null
                            ? Text(contact.name[0].toUpperCase())
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

