import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Get or create a unique device ID for desktop
Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  String? deviceId = prefs.getString('device_id');
  
  if (deviceId == null) {
    String hostname;
    if (Platform.isWindows) {
      hostname = Platform.environment['COMPUTERNAME'] ?? 
                 Platform.environment['HOSTNAME'] ?? 
                 'desktop_${DateTime.now().millisecondsSinceEpoch}';
    } else if (Platform.isLinux) {
      hostname = Platform.environment['HOSTNAME'] ?? 
                 Platform.environment['HOST'] ??
                 'desktop_${DateTime.now().millisecondsSinceEpoch}';
    } else if (Platform.isMacOS) {
      hostname = Platform.environment['HOSTNAME'] ?? 
                 Platform.environment['COMPUTERNAME'] ??
                 'desktop_${DateTime.now().millisecondsSinceEpoch}';
    } else {
      hostname = 'desktop_${DateTime.now().millisecondsSinceEpoch}';
    }
    deviceId = 'desktop_$hostname';
    await prefs.setString('device_id', deviceId);
  }
  
  return deviceId;
}

