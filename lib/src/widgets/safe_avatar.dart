import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A safe avatar widget that handles image loading errors gracefully
/// Falls back to a text/icon avatar if the image fails to load
class SafeAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final IconData? fallbackIcon;
  final Color? backgroundColor;
  final Color? textColor;

  const SafeAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.fallbackIcon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBgColor = backgroundColor ?? 
        (isDark ? const Color(0xFF3B4A54) : Colors.grey[300]!);
    final defaultTextColor = textColor ?? 
        (isDark ? Colors.white : Colors.black87);

    // If no image URL, show fallback immediately
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback(defaultBgColor, defaultTextColor);
    }

    // Try to load the image with error handling
    return CircleAvatar(
      radius: radius,
      backgroundColor: defaultBgColor,
      child: ClipOval(
        child: Image(
          image: CachedNetworkImageProvider(imageUrl!),
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) {
            // Log error in debug mode but don't spam console
            debugPrint('Avatar image failed to load: $imageUrl');
            return _buildFallback(defaultBgColor, defaultTextColor);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            // Show a subtle loading indicator
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallback(Color bgColor, Color textColor) {
    if (fallbackIcon != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Icon(
          fallbackIcon,
          size: radius,
          color: textColor,
        ),
      );
    }

    // Use first letter of name, or default icon
    final displayText = name != null && name!.isNotEmpty
        ? name![0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
