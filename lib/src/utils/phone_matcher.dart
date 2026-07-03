/// Shared phone normalization for login (matches gekychat_mobile).
class PhoneMatcher {
  static String normalize(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'\D'), '');
  }

  /// Ghana login/API storage format: `0` + 9 mobile digits.
  static String normalizeGhanaLoginPhone(String? raw) {
    var d = normalize(raw);
    if (d.isEmpty) return '';

    if (d.startsWith('233') && d.length >= 11) {
      d = d.substring(3);
    }
    if (d.startsWith('0')) {
      d = d.substring(1);
    }
    if (d.length > 9) {
      d = d.substring(d.length - 9);
    }
    if (d.length != 9) return '';
    return '0$d';
  }

  static bool isValidGhanaLoginPhone(String? raw) {
    final n = normalizeGhanaLoginPhone(raw);
    return RegExp(r'^0\d{9}$').hasMatch(n);
  }

  /// Candidate forms used for tolerant phone matching across formats.
  static Set<String> candidates(String? raw) {
    final digits = normalize(raw);
    if (digits.isEmpty) return const <String>{};
    final out = <String>{digits};
    final noLeadingZeros = digits.replaceFirst(RegExp(r'^0+'), '');
    if (noLeadingZeros.isNotEmpty) out.add(noLeadingZeros);
    if (digits.length >= 10) out.add(digits.substring(digits.length - 10));
    if (noLeadingZeros.length >= 10) {
      out.add(noLeadingZeros.substring(noLeadingZeros.length - 10));
    }
    out.removeWhere((v) => v.isEmpty);
    return out;
  }

  static bool matchesLoose(String? a, String? b, {int minSuffix = 8}) {
    final aSet = candidates(a);
    final bSet = candidates(b);
    if (aSet.isEmpty || bSet.isEmpty) return false;
    if (aSet.intersection(bSet).isNotEmpty) return true;
    for (final x in aSet) {
      for (final y in bSet) {
        final min = x.length < y.length ? x.length : y.length;
        if (min >= minSuffix && (x.endsWith(y) || y.endsWith(x))) {
          return true;
        }
      }
    }
    return false;
  }
}
