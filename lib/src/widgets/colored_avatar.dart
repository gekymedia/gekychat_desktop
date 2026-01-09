import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/avatar_utils.dart';

/// A reusable avatar widget with colored background for initials
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
    
    return CircleAvatar(
      radius: radius,
      minRadius: minRadius,
      maxRadius: maxRadius,
      backgroundColor: imageUrl == null ? backgroundColor : null,
      backgroundImage: imageUrl != null ? CachedNetworkImageProvider(imageUrl!) : null,
      child: imageUrl == null
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.6,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
