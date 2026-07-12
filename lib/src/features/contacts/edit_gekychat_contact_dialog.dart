import 'package:flutter/material.dart';

import '../../utils/snackbar_helper.dart';
import '../../widgets/desktop_center_modal.dart';

/// Desktop dialog to edit a contact saved in GekyChat (name, phone, note).
Future<Map<String, String>?> showEditGekyChatContactDialog(
  BuildContext context, {
  required String displayName,
  required String phone,
  String? note,
}) {
  return showDesktopCenterModal<Map<String, String>?>(
    context: context,
    title: 'Edit in GekyChat',
    maxWidth: 440,
    maxHeightFraction: 0.7,
    child: _EditGekyChatContactForm(
      displayName: displayName,
      phone: phone,
      note: note,
    ),
  );
}

class _EditGekyChatContactForm extends StatefulWidget {
  const _EditGekyChatContactForm({
    required this.displayName,
    required this.phone,
    this.note,
  });

  final String displayName;
  final String phone;
  final String? note;

  @override
  State<_EditGekyChatContactForm> createState() =>
      _EditGekyChatContactFormState();
}

class _EditGekyChatContactFormState extends State<_EditGekyChatContactForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.displayName);
    _phoneController = TextEditingController(text: widget.phone);
    _noteController = TextEditingController(text: widget.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      context.showWarningToast('Name is required');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      context.showWarningToast('Phone is required');
      return;
    }
    Navigator.pop(context, {
      'displayName': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'note': _noteController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
            maxLines: 2,
            maxLength: 500,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
