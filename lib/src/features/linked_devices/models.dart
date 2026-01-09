class LinkedDevice {
  final String id; // Changed to String to handle 'web_session_id' format
  final String name;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final bool isCurrentDevice;
  final String? deviceType; // 'web', 'mobile_desktop', etc.

  LinkedDevice({
    required this.id,
    required this.name,
    this.lastUsedAt,
    required this.createdAt,
    this.isCurrentDevice = false,
    this.deviceType,
  });

  factory LinkedDevice.fromJson(Map<String, dynamic> json) {
    // Handle both int and string IDs (web sessions use string IDs like 'web_session_id')
    final idValue = json['id'];
    final id = idValue is int ? idValue.toString() : (idValue?.toString() ?? '');
    
    return LinkedDevice(
      id: id,
      name: json['name'] ?? 'Unknown Device',
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      isCurrentDevice: json['is_current_device'] ?? false,
      deviceType: json['device_type'],
    );
  }
}

