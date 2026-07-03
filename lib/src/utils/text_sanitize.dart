/// Removes lone UTF-16 surrogates that crash Flutter [Text] and native CallKit APIs.
String sanitizeDisplayText(String? value, {String fallback = ''}) {
  if (value == null || value.isEmpty) return fallback;
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 0xD800 && rune <= 0xDFFF) continue;
    buffer.writeCharCode(rune);
  }
  final trimmed = buffer.toString().trim();
  return trimmed.isEmpty ? fallback : trimmed;
}
