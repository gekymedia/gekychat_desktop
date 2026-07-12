import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog showing all available keyboard shortcuts
/// Shows when user presses Ctrl+? or from help menu
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.keyboard,
                    size: 28,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Keyboard Shortcuts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSection(
                    'General',
                    [
                      _ShortcutItem('Show keyboard shortcuts', 'Ctrl + Shift + /'),
                      _ShortcutItem('Search chats', 'Ctrl + K'),
                      _ShortcutItem('New chat', 'Ctrl + N'),
                      _ShortcutItem('Settings', 'Ctrl + ,'),
                      _ShortcutItem('Clear search / close chat', 'Esc'),
                    ],
                    isDark,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'Navigation',
                    [
                      _ShortcutItem('Next chat', 'Ctrl + Tab'),
                      _ShortcutItem('Previous chat', 'Ctrl + Shift + Tab'),
                      _ShortcutItem('Archive chat', 'Ctrl + E'),
                      _ShortcutItem('Close current chat', 'Ctrl + W'),
                    ],
                    isDark,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'Messaging',
                    [
                      _ShortcutItem('Send message', 'Ctrl + Enter'),
                      _ShortcutItem('New line', 'Shift + Enter'),
                      _ShortcutItem('Attach file', 'Ctrl + U'),
                      _ShortcutItem('Emoji picker', 'Ctrl + E'),
                      _ShortcutItem('Search in chat', 'Ctrl + Shift + F'),
                    ],
                    isDark,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'Text Formatting',
                    [
                      _ShortcutItem('Bold', 'Ctrl + B'),
                      _ShortcutItem('Italic', 'Ctrl + I'),
                      _ShortcutItem('Strikethrough', 'Ctrl + Shift + X'),
                      _ShortcutItem('Monospace', 'Ctrl + Shift + M'),
                    ],
                    isDark,
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    'Media',
                    [
                      _ShortcutItem('View media', 'Ctrl + M'),
                      _ShortcutItem('Voice call', 'Ctrl + Shift + C'),
                      _ShortcutItem('Video call', 'Ctrl + Shift + V'),
                    ],
                    isDark,
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
              ),
              child: Text(
                'Tip: Press Ctrl+? anytime to view these shortcuts',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<_ShortcutItem> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                  ),
                ),
                child: Text(
                  item.shortcut,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

class _ShortcutItem {
  final String description;
  final String shortcut;

  _ShortcutItem(this.description, this.shortcut);
}

/// Global keyboard shortcut handler
/// Add this to your root widget to enable keyboard shortcuts
class KeyboardShortcutHandler extends StatefulWidget {
  final Widget child;

  const KeyboardShortcutHandler({
    super.key,
    required this.child,
  });

  @override
  State<KeyboardShortcutHandler> createState() => _KeyboardShortcutHandlerState();
}

class _KeyboardShortcutHandlerState extends State<KeyboardShortcutHandler> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Request focus on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        // Ctrl + ? - Show keyboard shortcuts
        if (isCtrl && 
            isShift && 
            event.logicalKey == LogicalKeyboardKey.slash) {
          _showKeyboardShortcuts();
          return KeyEventResult.handled;
        }

        // Esc - Close dialogs/cancel actions
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }

  void _showKeyboardShortcuts() {
    showDialog(
      context: context,
      builder: (context) => const KeyboardShortcutsDialog(),
    );
  }
}
