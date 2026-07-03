/// Display-oriented phone number formatter.
///
/// Distinct from [PhoneMatcher] which is for normalisation/matching.
/// This is only for showing human-readable phone strings in the UI.
class PhoneFormatter {
  PhoneFormatter._();

  /// Format a phone string for display.
  ///
  /// Returns a formatted string when a known format is detected,
  /// otherwise returns the input as-is (never returns null / empty).
  static String format(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final cleaned = raw.trim();
    final digits = cleaned.replaceAll(RegExp(r'\D'), '');

    // +233 XX XXX XXXX  (Ghana E.164 / stored as 233XXXXXXXXX)
    if (digits.length == 12 && digits.startsWith('233')) {
      final local = digits.substring(3); // 9 digits
      return '+233 ${local.substring(0, 2)} ${local.substring(2, 5)} ${local.substring(5)}';
    }
    // Local Ghana: 0XXXXXXXXX (10 digits starting with 0)
    if (digits.length == 10 && digits.startsWith('0')) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
    }
    // Generic E.164 with leading + (any length 10–15)
    if (cleaned.startsWith('+') && digits.length >= 10 && digits.length <= 15) {
      // NANP: +1 (NXX) NXX-XXXX
      if (cleaned.startsWith('+1') && digits.length == 11) {
        final rest = digits.substring(1);
        return '+1 (${rest.substring(1, 4)}) ${rest.substring(4, 7)}-${rest.substring(7)}';
      }
      return cleaned;
    }
    // Fallback — return as received
    return cleaned;
  }

  /// Returns true if [raw] looks like a phone number (mostly digits, maybe + prefix).
  static bool looksLikePhone(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final digits = raw.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return digits.length >= 7 && RegExp(r'^\d+$').hasMatch(digits);
  }
}
