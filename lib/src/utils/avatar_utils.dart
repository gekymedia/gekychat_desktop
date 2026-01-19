import 'package:flutter/material.dart';

/// Utility class for avatar-related functions
class AvatarUtils {
  /// Gradient pairs: [light, dark] for 3D effect similar to Telegram
  static const List<List<Color>> gradientPairs = [
    [Color(0xFFEF5350), Color(0xFFC62828)], // Red
    [Color(0xFF42A5F5), Color(0xFF1565C0)], // Blue
    [Color(0xFF66BB6A), Color(0xFF2E7D32)], // Green
    [Color(0xFFFFA726), Color(0xFFE65100)], // Orange
    [Color(0xFFAB47BC), Color(0xFF6A1B9A)], // Purple
    [Color(0xFFEC407A), Color(0xFFAD1457)], // Pink
    [Color(0xFF5C6BC0), Color(0xFF283593)], // Indigo
    [Color(0xFF26A69A), Color(0xFF00695C)], // Teal
    [Color(0xFF29B6F6), Color(0xFF0277BD)], // Light Blue
    [Color(0xFF9CCC65), Color(0xFF558B2F)], // Light Green
    [Color(0xFFFFCA28), Color(0xFFF57F17)], // Yellow
    [Color(0xFFFF7043), Color(0xFFD84315)], // Deep Orange
    [Color(0xFF8D6E63), Color(0xFF5D4037)], // Brown
    [Color(0xFF78909C), Color(0xFF455A64)], // Blue Grey
    [Color(0xFF7E57C2), Color(0xFF4527A0)], // Deep Purple
    [Color(0xFF00ACC1), Color(0xFF00838F)], // Cyan
  ];

  /// List of colors for avatar placeholders (for backwards compatibility)
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

  /// Get a consistent gradient for a given name (for inline styles)
  /// Returns a LinearGradient that can be used in BoxDecoration
  static LinearGradient getGradientForName(String name) {
    if (name.trim().isEmpty) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientPairs[0],
      );
    }

    // Use hash to get consistent gradient for same name
    // Similar to JavaScript: name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0)
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash += name.codeUnitAt(i);
    }
    
    final index = hash.abs() % gradientPairs.length;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradientPairs[index],
    );
  }

  /// Get a consistent color for a given name/initial (for backwards compatibility)
  static Color getColorForName(String name) {
    if (name.isEmpty) return avatarColors[0];
    
    // Use hash code to get consistent color for same name
    final hash = name.hashCode;
    final index = hash.abs() % avatarColors.length;
    return avatarColors[index];
  }

  /// Get initials from a name
  static String getInitials(String name) {
    if (name.trim().isEmpty) return '?';

    final firstChar = name.trim()[0];
    // If first character is not an alphabet, return placeholder indicator
    if (!RegExp(r'^[a-zA-Z]').hasMatch(firstChar)) {
      return '👤'; // Use a user icon if the first character is not an alphabet
    }
    
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      // First letter of first name + first letter of last name
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    } else if (parts.length == 1 && parts[0].length >= 2) {
      // First two letters if available
      return parts[0].substring(0, 2).toUpperCase();
    } else if (parts.length == 1 && parts[0].length == 1) {
      // Single character
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}
