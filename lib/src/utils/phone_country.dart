/// Maps phone dial codes / prefixes to a country display name for chat UI.
class PhoneCountry {
  PhoneCountry._();

  static const Map<String, String> _dialCodes = {
    '233': 'Ghana',
    '234': 'Nigeria',
    '254': 'Kenya',
    '27': 'South Africa',
    '1': 'United States',
    '44': 'United Kingdom',
    '91': 'India',
    '971': 'United Arab Emirates',
    '966': 'Saudi Arabia',
    '49': 'Germany',
    '33': 'France',
    '39': 'Italy',
    '34': 'Spain',
    '31': 'Netherlands',
    '32': 'Belgium',
    '41': 'Switzerland',
    '43': 'Austria',
    '46': 'Sweden',
    '47': 'Norway',
    '45': 'Denmark',
    '358': 'Finland',
    '353': 'Ireland',
    '61': 'Australia',
    '64': 'New Zealand',
    '86': 'China',
    '81': 'Japan',
    '82': 'South Korea',
    '65': 'Singapore',
    '60': 'Malaysia',
    '62': 'Indonesia',
    '66': 'Thailand',
    '84': 'Vietnam',
    '63': 'Philippines',
    '55': 'Brazil',
    '52': 'Mexico',
    '54': 'Argentina',
    '20': 'Egypt',
    '212': 'Morocco',
    '216': 'Tunisia',
    '250': 'Rwanda',
    '256': 'Uganda',
    '255': 'Tanzania',
    '251': 'Ethiopia',
    '237': 'Cameroon',
    '225': "Côte d'Ivoire",
    '221': 'Senegal',
  };

  /// Digits only, no leading +.
  static String digitsOnly(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'\D'), '');
  }

  /// Best-effort country name from an E.164 / local phone string.
  /// Ghana local numbers starting with 0 are treated as Ghana.
  static String? fromPhone(String? phone) {
    final digits = digitsOnly(phone);
    if (digits.isEmpty) return null;

    // Local Ghana mobile: 0XXXXXXXXX (10 digits)
    if (digits.length == 10 && digits.startsWith('0')) {
      return 'Ghana';
    }

    // Try longest dial-code match first.
    final keys = _dialCodes.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final code in keys) {
      if (digits.startsWith(code)) {
        return _dialCodes[code];
      }
    }
    return null;
  }

  static String phoneOriginLabel(String? phone) {
    final country = fromPhone(phone);
    if (country == null) return 'Phone number';
    return 'Phone number from $country';
  }
}
