import 'package:flutter/material.dart';

/// Formatting toolbar that appears when text is selected
/// Similar to WhatsApp's text formatting popup
class TextFormattingToolbar extends StatelessWidget {
  final Function(String) onFormat;
  final VoidCallback? onClose;

  const TextFormattingToolbar({
    super.key,
    required this.onFormat,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FormatButton(
            icon: Icons.format_bold,
            label: 'Bold',
            onTap: () => onFormat('bold'),
            isDark: isDark,
          ),
          _FormatButton(
            icon: Icons.format_italic,
            label: 'Italic',
            onTap: () => onFormat('italic'),
            isDark: isDark,
          ),
          _FormatButton(
            icon: Icons.strikethrough_s,
            label: 'Strikethrough',
            onTap: () => onFormat('strikethrough'),
            isDark: isDark,
          ),
          _FormatButton(
            icon: Icons.code,
            label: 'Monospace',
            onTap: () => onFormat('monospace'),
            isDark: isDark,
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              color: isDark ? Colors.white70 : Colors.grey[700],
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _FormatButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
