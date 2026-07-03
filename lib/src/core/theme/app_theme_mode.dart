/// Theme color categories (shared with mobile).
enum ThemeColor {
  classic,
  golden,
  telegram,
  blue,
  pink,
  amoled,
  ios,
}

/// Theme mode options for GekyChat (GBWhatsApp-style themes).
enum AppThemeMode {
  classicLight('classic_light', 'Classic', false, ThemeColor.classic),
  classicDark('classic_dark', 'Classic Dark', false, ThemeColor.classic),
  goldenLight('golden_light', 'Golden', true, ThemeColor.golden),
  goldenDark('golden_dark', 'Golden Dark', true, ThemeColor.golden),
  telegramLight('telegram_light', 'Telegram', false, ThemeColor.telegram),
  telegramDark('telegram_dark', 'Telegram Dark', false, ThemeColor.telegram),
  blueLight('blue_light', 'Blue', false, ThemeColor.blue),
  blueDark('blue_dark', 'Blue Dark', false, ThemeColor.blue),
  pinkLight('pink_light', 'Pink', false, ThemeColor.pink),
  pinkDark('pink_dark', 'Pink Dark', false, ThemeColor.pink),
  amoledDark('amoled_dark', 'AMOLED Black', false, ThemeColor.amoled),
  iosLight('ios_light', 'iOS', false, ThemeColor.ios),
  iosDark('ios_dark', 'iOS Dark', false, ThemeColor.ios);

  const AppThemeMode(this.key, this.displayName, this.isGolden, this.themeColor);

  final String key;
  final String displayName;
  final bool isGolden;
  final ThemeColor themeColor;

  bool get isDark => key.contains('dark') || key.contains('amoled');
  bool get isLight => !isDark;

  String get appIconPath {
    switch (themeColor) {
      case ThemeColor.golden:
        return 'gold_with_text';
      case ThemeColor.telegram:
        return 'telegram_with_text';
      case ThemeColor.blue:
        return 'blue_with_text';
      case ThemeColor.pink:
        return 'pink_with_text';
      default:
        return 'white_with_text';
    }
  }

  int get primaryColorValue {
    switch (themeColor) {
      case ThemeColor.classic:
        return 0xFF008069;
      case ThemeColor.golden:
        return 0xFFFFD700;
      case ThemeColor.telegram:
        return 0xFF3390EC;
      case ThemeColor.blue:
        return 0xFF1976D2;
      case ThemeColor.pink:
        return 0xFFF50057;
      case ThemeColor.amoled:
        return 0xFF000000;
      case ThemeColor.ios:
        return 0xFF007AFF;
    }
  }

  ThemeColor get colorCategory => themeColor;

  static AppThemeMode fromKey(String key) {
    final normalized = switch (key) {
      'white_light' => classicLight.key,
      'white_dark' => classicDark.key,
      _ => key,
    };
    return AppThemeMode.values.firstWhere(
      (mode) => mode.key == normalized,
      orElse: () => AppThemeMode.classicLight,
    );
  }
}
