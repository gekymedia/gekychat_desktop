/// Theme mode options for GekyChat
enum AppThemeMode {
  /// Golden theme with light mode
  goldenLight('golden_light', 'Golden Light', true),
  
  /// Golden theme with dark mode
  goldenDark('golden_dark', 'Golden Dark', true),
  
  /// White theme with light mode
  whiteLight('white_light', 'White Light', false),
  
  /// White theme with dark mode
  whiteDark('white_dark', 'White Dark', false);

  const AppThemeMode(this.key, this.displayName, this.isGolden);

  final String key;
  final String displayName;
  final bool isGolden;

  bool get isDark => this == goldenDark || this == whiteDark;
  bool get isLight => !isDark;

  /// Get icon path based on theme
  String get appIconPath {
    if (isGolden) {
      return 'gold_with_text';
    } else {
      return 'white_with_text';
    }
  }

  /// Get primary color based on theme
  int get primaryColorValue {
    if (isGolden) {
      return 0xFFD4AF37; // Gold color
    } else {
      return 0xFF008069; // WhatsApp green
    }
  }

  static AppThemeMode fromKey(String key) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.key == key,
      orElse: () => AppThemeMode.whiteLight,
    );
  }
}
