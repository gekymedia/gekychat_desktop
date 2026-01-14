import 'package:intl/intl.dart';

class DateFormatter {
  /// Format date for chat message dividers
  /// Returns "Today", "Yesterday", or full date like "January 15, 2025"
  static String formatChatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(date); // e.g., "January 15, 2025"
    }
  }

  /// Check if two dates are on different days
  static bool isDifferentDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) {
      return true;
    }

    final d1 = DateTime(date1.year, date1.month, date1.day);
    final d2 = DateTime(date2.year, date2.month, date2.day);

    return d1 != d2;
  }
}
