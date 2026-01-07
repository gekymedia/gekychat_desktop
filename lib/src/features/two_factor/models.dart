class TwoFactorStatus {
  final bool enabled;
  final int recoveryCodesCount;

  TwoFactorStatus({
    required this.enabled,
    required this.recoveryCodesCount,
  });

  factory TwoFactorStatus.fromJson(Map<String, dynamic> json) {
    // Handle both boolean and int (0/1) for enabled field
    final enabledValue = json['enabled'];
    final enabled = enabledValue is bool 
        ? enabledValue 
        : (enabledValue is int ? enabledValue == 1 : false);
    
    return TwoFactorStatus(
      enabled: enabled,
      recoveryCodesCount: json['recovery_codes_count'] is int
          ? json['recovery_codes_count'] as int
          : (int.tryParse(json['recovery_codes_count']?.toString() ?? '0') ?? 0),
    );
  }
}

class TwoFactorSetup {
  final String secret;
  final String qrCodeUrl;
  final List<String> recoveryCodes;

  TwoFactorSetup({
    required this.secret,
    required this.qrCodeUrl,
    required this.recoveryCodes,
  });

  factory TwoFactorSetup.fromJson(Map<String, dynamic> json) {
    return TwoFactorSetup(
      secret: json['secret'],
      qrCodeUrl: json['qr_code_url'],
      recoveryCodes: (json['recovery_codes'] as List).map((e) => e.toString()).toList(),
    );
  }
}

