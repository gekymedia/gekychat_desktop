/// Whole seconds from API / call_data (may be int, double, or string).
int? parseCallDurationSeconds(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw >= 0 ? raw : null;
  if (raw is double) return raw.isFinite && raw >= 0 ? raw.round() : null;
  if (raw is num) return raw >= 0 ? raw.round() : null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final asDouble = double.tryParse(text);
  if (asDouble != null && asDouble.isFinite && asDouble >= 0) {
    return asDouble.round();
  }
  return int.tryParse(text.split('.').first);
}

/// Formats [duration] as `MM:SS` or `HH:MM:SS` when over an hour (in-call timers).
String formatCallDurationHms(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
  return '${twoDigits(minutes)}:${twoDigits(seconds)}';
}

/// Formats completed call length for logs and message cards.
String formatCallDurationLabel(int seconds) {
  if (seconds <= 0) return '';
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final rem = seconds % 60;
  return '$minutes:${rem.toString().padLeft(2, '0')}';
}
