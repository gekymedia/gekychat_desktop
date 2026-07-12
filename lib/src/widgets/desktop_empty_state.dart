import 'package:flutter/material.dart';

import 'desktop_typography.dart';

/// Centered empty state with icon, message, and optional CTA.
class DesktopEmptyState extends StatelessWidget {
  const DesktopEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.imageAsset,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String message;
  final IconData? icon;
  final String? imageAsset;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF8696A0) : const Color(0xFF707579);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageAsset != null)
            Image.asset(
              imageAsset!,
              width: 72,
              height: 72,
              errorBuilder: (_, __, ___) => Icon(
                icon ?? Icons.inbox_outlined,
                size: 56,
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
            )
          else if (icon != null)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF0F2F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: isDark ? Colors.white54 : const Color(0xFF667781),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DesktopTypography.sectionTitle(isDark: isDark, color: muted)
                .copyWith(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008069),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
