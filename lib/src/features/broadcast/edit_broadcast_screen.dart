import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'broadcast_repository.dart';
import 'models.dart';
import '../contacts/contacts_repository.dart';
import '../chats/models.dart' show GekyContact;
import '../../utils/snackbar_helper.dart';

class EditBroadcastScreen extends ConsumerStatefulWidget {
  final BroadcastList broadcastList;
  final bool forModal;
  final VoidCallback? onComplete;

  const EditBroadcastScreen({
    super.key,
    required this.broadcastList,
    this.forModal = false,
    this.onComplete,
  });

  @override
  ConsumerState<EditBroadcastScreen> createState() => _EditBroadcastScreenState();
}

class _EditBroadcastScreenState extends ConsumerState<EditBroadcastScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Set<int> _selectedContactIds;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.broadcastList.name);
    _descriptionController = TextEditingController(text: widget.broadcastList.description ?? '');
    _selectedContactIds = widget.broadcastList.recipients.map((r) => r.id).toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateBroadcastList() async {
    if (_nameController.text.trim().isEmpty) {
            context.showInfoToast('Please enter a name');      return;
    }

    if (_selectedContactIds.isEmpty) {
            context.showInfoToast('Please select at least one recipient');      return;
    }

    setState(() => _loading = true);

    try {
      final repo = ref.read(broadcastRepositoryProvider);
      await repo.updateBroadcastList(
        id: widget.broadcastList.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        recipientIds: _selectedContactIds.toList(),
      );

      if (mounted) {
        if (widget.forModal) {
          widget.onComplete?.call();
        } else {
          Navigator.pop(context);
        }
        context.showSuccessToast('Broadcast list updated successfully');
      }
    } catch (e) {
      if (mounted) {
                context.showErrorToast('Failed to update broadcast list: $e');      }
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
    // Filter to only show registered contacts (those with user IDs) for broadcast lists
    final contactsFuture = contactsRepo.listContacts().then((contacts) => 
      contactsRepo.filterRegistered(contacts)
    );

    final body = SingleChildScrollView(
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
                if (contacts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'No registered contacts available. Add contacts to create a broadcast list.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    // Use contactUserId (user ID) instead of contact.id for broadcast lists
                    final userId = contact.contactUserId;
                    // Fallback: check contactUser map if contactUserId is null
                    final userIdFromMap = userId ?? 
                        (contact.contactUser != null && contact.contactUser!['id'] != null
                            ? contact.contactUser!['id'] as int
                            : null);
                    
                    if (userIdFromMap == null) {
                      // Skip contacts without user IDs (not registered)
                      // This shouldn't happen since filterRegistered already filters them
                      debugPrint('Warning: Contact ${contact.id} is registered but has no userId');
                      return const SizedBox.shrink();
                    }
                    final isSelected = _selectedContactIds.contains(userIdFromMap);

                    // Get display name
                    String displayName = contact.name;
                    
                    // Get avatar URL
                    String? avatarUrl = contact.avatarUrl;

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedContactIds.add(userIdFromMap);
                          } else {
                            _selectedContactIds.remove(userIdFromMap);
                          }
                        });
                      },
                      title: Text(displayName),
                      subtitle: contact.phone != null ? Text(contact.phone!) : null,
                      secondary: CircleAvatar(
                        backgroundImage: avatarUrl != null
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(displayName[0].toUpperCase())
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          if (widget.forModal) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _updateBroadcastList,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008069),
                minimumSize: const Size.fromHeight(44),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ],
      ),
    );

    if (widget.forModal) {
      return body;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Edit Broadcast List'),
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
              onPressed: _updateBroadcastList,
            ),
        ],
      ),
      body: body,
    );
  }
}

