/// Strips lone UTF-16 surrogates so Flutter's text engine can layout safely.
String sanitizeDisplayText(String text) {
  if (text.isEmpty) return text;

  final codeUnits = text.codeUnits;
  final buffer = StringBuffer();

  for (var i = 0; i < codeUnits.length; i++) {
    final unit = codeUnits[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 < codeUnits.length) {
        final next = codeUnits[i + 1];
        if (next >= 0xDC00 && next <= 0xDFFF) {
          buffer.writeCharCode(unit);
          buffer.writeCharCode(next);
          i++;
        }
      }
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      continue;
    } else {
      buffer.writeCharCode(unit);
    }
  }

  return buffer.toString();
}
