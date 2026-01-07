import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'broadcast_repository.dart';
import 'models.dart';
import '../../core/api_service.dart';
import '../../core/providers.dart';

final broadcastListProvider = FutureProvider.family<BroadcastList, int>((ref, id) async {
  final repo = ref.read(broadcastRepositoryProvider);
  return await repo.getBroadcastList(id);
});

class SendBroadcastScreen extends ConsumerStatefulWidget {
  final int broadcastListId;

  const SendBroadcastScreen({super.key, required this.broadcastListId});

  @override
  ConsumerState<SendBroadcastScreen> createState() => _SendBroadcastScreenState();
}

class _SendBroadcastScreenState extends ConsumerState<SendBroadcastScreen> {
  final _messageController = TextEditingController();
  final List<File> _selectedFiles = [];
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(
          result.files
              .where((file) => file.path != null)
              .map((file) => File(file.path!))
              .toList(),
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message or select files')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final repo = ref.read(broadcastRepositoryProvider);
      final apiService = ref.read(apiServiceProvider);

      List<int> attachmentIds = [];
      if (_selectedFiles.isNotEmpty) {
        for (final file in _selectedFiles) {
          final uploadResponse = await apiService.uploadAttachment(file);
          final attachmentData = uploadResponse.data;
          final attachment = attachmentData is Map && attachmentData['data'] != null
              ? attachmentData['data'] as Map<String, dynamic>
              : attachmentData as Map<String, dynamic>;
          attachmentIds.add(attachment['id'] as int);
        }
      }

      final result = await repo.sendMessage(
        broadcastListId: widget.broadcastListId,
        body: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
        attachmentIds: attachmentIds.isEmpty ? null : attachmentIds,
      );

      if (mounted) {
        Navigator.pop(context);
        final count = result['sent_messages']?.length ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message sent to $count recipients')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listAsync = ref.watch(broadcastListProvider(widget.broadcastListId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: listAsync.when(
          data: (list) => Text(list.name),
          loading: () => const Text('Send Message'),
          error: (_, __) => const Text('Send Message'),
        ),
      ),
      body: listAsync.when(
        data: (list) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recipients (${list.recipientCount})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: list.recipients.take(10).map((recipient) {
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundImage: recipient.avatarUrl != null
                                ? CachedNetworkImageProvider(recipient.avatarUrl!)
                                : null,
                            child: recipient.avatarUrl == null
                                ? Text(recipient.name[0].toUpperCase())
                                : null,
                          ),
                          label: Text(recipient.name),
                        );
                      }).toList(),
                    ),
                    if (list.recipientCount > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'and ${list.recipientCount - 10} more...',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                        hintText: 'Type your message...',
                      ),
                      maxLines: 10,
                      minLines: 5,
                    ),
                    const SizedBox(height: 16),
                    if (_selectedFiles.isNotEmpty) ...[
                      Text(
                        'Attachments (${_selectedFiles.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return Chip(
                            label: Text(file.path.split('/').last),
                            onDeleted: () {
                              setState(() {
                                _selectedFiles.removeAt(index);
                              });
                            },
                            deleteIcon: const Icon(Icons.close, size: 18),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Add Attachment'),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202C33) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008069),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send Message'),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading broadcast list: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(broadcastListProvider(widget.broadcastListId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

