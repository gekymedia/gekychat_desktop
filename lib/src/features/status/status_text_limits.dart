/// Shared limits for text-only status posts (matches API `max:700`).
const int kStatusTextMaxLength = 700;

const double kStatusTextFontSizeMax = 42;
const double kStatusTextFontSizeMin = 18;

/// WhatsApp-style: shrink font as the user approaches the character cap.
double statusTextFontSizeForLength(int length) {
  if (length <= 0) return kStatusTextFontSizeMax;
  final progress = (length / kStatusTextMaxLength).clamp(0.0, 1.0);
  return kStatusTextFontSizeMax -
      progress * (kStatusTextFontSizeMax - kStatusTextFontSizeMin);
}

int statusTextFontSizeIntForLength(int length) =>
    statusTextFontSizeForLength(length).round();
