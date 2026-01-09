import 'package:flutter/material.dart';

/// Utility class for avatar-related functions
class AvatarUtils {
  /// List of colors for avatar placeholders
  static const List<Color> avatarColors = [
    Color(0xFFEF5350), // Red
    Color(0xFF42A5F5), // Blue
    Color(0xFF66BB6A), // Green
    Color(0xFFFFA726), // Orange
    Color(0xFFAB47BC), // Purple
    Color(0xFFEC407A), // Pink
    Color(0xFF5C6BC0), // Indigo
    Color(0xFF26A69A), // Teal
    Color(0xFF29B6F6), // Cyan
    Color(0xFF9CCC65), // Lime
    Color(0xFFFFCA28), // Amber
    Color(0xFFFF7043), // Deep Orange
    Color(0xFF8D6E63), // Brown
    Color(0xFF78909C), // Blue Grey
    Color(0xFF7E57C2), // Deep Purple
    Color(0xFF00ACC1), // Cyan (darker)
  ];

  /// Get a consistent color for a given name/initial
  static Color getColorForName(String name) {
    if (name.isEmpty) return avatarColors[0];
    
    // Use hash code to get consistent color for same name
    final hash = name.hashCode;
    final index = hash.abs() % avatarColors.length;
    return avatarColors[index];
  }

  /// Get initials from a name
  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      // First letter of first name + first letter of last name
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      // First letter (or first two if single character)
      final first = parts[0];
      if (first.length >= 2) {
        return first.substring(0, 2).toUpperCase();
      }
      return first[0].toUpperCase();
    }
    return '?';
  }
}
