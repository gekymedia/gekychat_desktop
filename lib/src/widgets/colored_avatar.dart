import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/avatar_utils.dart';

/// A reusable avatar widget with colored background for initials
/// Handles image loading errors gracefully by falling back to initials
class ColoredAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final double? minRadius;
  final double? maxRadius;

  const ColoredAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 20,
    this.minRadius,
    this.maxRadius,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AvatarUtils.getColorForName(name);
    final initials = AvatarUtils.getInitials(name);
    
    // If no image URL, show initials immediately
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        minRadius: minRadius,
        maxRadius: maxRadius,
        backgroundColor: backgroundColor,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    
    // Try to load image with error handling
    return CircleAvatar(
      radius: radius,
      minRadius: minRadius,
      maxRadius: maxRadius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: Image(
          image: CachedNetworkImageProvider(imageUrl!),
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) {
            // Silently fall back to initials on error
            // Only log in debug mode to avoid console spam
            debugPrint('Avatar image failed to load: $imageUrl');
            return Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            // Show a subtle loading indicator
            return Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
