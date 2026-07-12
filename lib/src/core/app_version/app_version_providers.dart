import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'app_version_info.dart';
import 'app_version_service.dart';

final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  return AppVersionService(ref.read(apiServiceProvider));
});

final appVersionCheckProvider = FutureProvider<AppVersionCheckResult>((ref) async {
  final service = ref.read(appVersionServiceProvider);
  return service.checkForUpdates();
});

final installedAppVersionProvider = FutureProvider<String>((ref) async {
  return ref.read(appVersionServiceProvider).installedVersionLabel();
});
