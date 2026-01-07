import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../../core/providers.dart';
import '../chat_repo.dart';
import '../../../theme/app_theme.dart';

final groupDetailsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, groupId) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/groups/$groupId');
  return response.data['data'] ?? {};
});

class EditGroupScreen extends ConsumerStatefulWidget {
  final int groupId;

  const EditGroupScreen({super.key, required this.groupId});

  @override
  ConsumerState<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends ConsumerState<EditGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedAvatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupDetails() async {
    try {
      final groupAsync = await ref.read(groupDetailsProvider(widget.groupId).future);
      if (mounted) {
        setState(() {
          _nameController.text = groupAsync['name'] ?? '';
          _descriptionController.text = groupAsync['description'] ?? '';
        });
      }
    } catch (e) {
      // Error will be handled by the widget's error state
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedAvatar = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.updateGroup(
        widget.groupId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        avatar: _selectedAvatar,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupAsync = ref.watch(groupDetailsProvider(widget.groupId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Edit Group'),
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: const Text('Save'),
            ),
        ],
      ),
      body: groupAsync.when(
        data: (group) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar Section
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _selectedAvatar != null
                            ? FileImage(_selectedAvatar!) as ImageProvider
                            : (group['avatar_url'] != null
                                ? CachedNetworkImageProvider(group['avatar_url']) as ImageProvider
                                : null),
                        child: _selectedAvatar == null && group['avatar_url'] == null
                            ? const Icon(Icons.group, size: 60)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryGreen,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                            onPressed: _pickAvatar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name Field
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Description Field
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading group: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(groupDetailsProvider(widget.groupId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

