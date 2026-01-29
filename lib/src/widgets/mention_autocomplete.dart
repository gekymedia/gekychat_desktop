import 'package:flutter/material.dart';
import '../features/chats/models.dart';

/// Widget that displays an autocomplete dropdown for @mentions
class MentionAutocomplete extends StatelessWidget {
  final String query;
  final List<User> members;
  final Function(User) onMentionSelected;
  final double? maxHeight;

  const MentionAutocomplete({
    super.key,
    required this.query,
    required this.members,
    required this.onMentionSelected,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Filter members by query (case-insensitive)
    final filtered = members.where((member) {
      final lowerQuery = query.toLowerCase();
      final name = member.name.toLowerCase();
      final phone = member.phone?.toLowerCase() ?? '';
      return name.contains(lowerQuery) || phone.contains(lowerQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? 200,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.alternate_email, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Mention someone',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${filtered.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
          // List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final member = filtered[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundImage: member.avatarUrl != null
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                    child: member.avatarUrl == null
                        ? Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 14),
                          )
                        : null,
                  ),
                  title: Text(
                    member.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: member.phone != null
                      ? Text(
                          member.phone!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        )
                      : null,
                  trailing: Text(
                    '@${_getUsernameFromName(member.name)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => onMentionSelected(member),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Generate a username from the user's name
  /// This is a fallback - ideally the API should return actual usernames
  String _getUsernameFromName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

/// Wrapper widget that adds mention autocomplete functionality to a TextField
class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<User> members;
  final String? hintText;
  final Function(String)? onChanged;
  final VoidCallback? onSubmitted;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final InputDecoration? decoration;

  const MentionTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.members,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.maxLines,
    this.minLines,
    this.textInputAction,
    this.decoration,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  String? _currentMention;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // Check if we're typing a mention
    String? mention = _getCurrentMention(text, cursorPosition);

    if (mention != _currentMention) {
      setState(() {
        _currentMention = mention;
      });

      if (mention != null) {
        _showAutocomplete();
      } else {
        _removeOverlay();
      }
    }

    widget.onChanged?.call(text);
  }

  String? _getCurrentMention(String text, int cursorPosition) {
    if (cursorPosition <= 0 || cursorPosition > text.length) return null;

    // Find the last @ before cursor
    int atIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        atIndex = i;
        break;
      }
      // Stop if we hit a space or newline
      if (text[i] == ' ' || text[i] == '\n') {
        break;
      }
    }

    if (atIndex == -1) return null;

    // Check if there's a space or newline right before the @
    if (atIndex > 0 && text[atIndex - 1] != ' ' && text[atIndex - 1] != '\n') {
      return null;
    }

    // Extract the partial username
    final partial = text.substring(atIndex + 1, cursorPosition);

    // Validate it's a valid username pattern
    if (!RegExp(r'^\w*$').hasMatch(partial)) return null;

    return partial;
  }

  void _showAutocomplete() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -200), // Show above the text field
          child: MentionAutocomplete(
            query: _currentMention!,
            members: widget.members,
            onMentionSelected: _insertMention,
            maxHeight: 200,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _insertMention(User user) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // Find the @ position
    int atIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        atIndex = i;
        break;
      }
      if (text[i] == ' ' || text[i] == '\n') {
        break;
      }
    }

    if (atIndex != -1) {
      final username = _getUsernameFromName(user.name);
      final before = text.substring(0, atIndex);
      final after = text.substring(cursorPosition);
      final newText = '$before@$username $after';

      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: atIndex + username.length + 2, // +2 for @ and space
        ),
      );
    }

    _removeOverlay();
    setState(() {
      _currentMention = null;
    });
  }

  String _getUsernameFromName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        textInputAction: widget.textInputAction,
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hintText ?? 'Type a message...',
              border: InputBorder.none,
            ),
        onSubmitted: (_) => widget.onSubmitted?.call(),
      ),
    );
  }
}
