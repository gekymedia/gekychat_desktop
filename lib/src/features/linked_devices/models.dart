class LinkedDevice {
  final int id;
  final String name;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final bool isCurrentDevice;

  LinkedDevice({
    required this.id,
    required this.name,
    this.lastUsedAt,
    required this.createdAt,
    this.isCurrentDevice = false,
  });

  factory LinkedDevice.fromJson(Map<String, dynamic> json) {
    return LinkedDevice(
      id: json['id'],
      name: json['name'] ?? 'Unknown Device',
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      isCurrentDevice: json['is_current_device'] ?? false,
    );
  }
}

