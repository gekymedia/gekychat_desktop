import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/providers.dart';
import 'issue_report_providers.dart';

class IssueReportRepository {
  IssueReportRepository(this._api);

  final ApiService _api;

  Future<void> submit({
    required String category,
    required String description,
    required IssueReportSource source,
    required String appVersion,
    required String platform,
    required String deviceModel,
    required String osVersion,
    String? screenName,
    Map<String, dynamic>? diagnostics,
    File? screenshot,
  }) async {
    final formData = FormData.fromMap({
      'category': category,
      'description': description,
      'source': source.name,
      'app_version': appVersion,
      'platform': platform,
      'device_model': deviceModel,
      'os_version': osVersion,
      if (screenName != null && screenName.isNotEmpty) 'screen_name': screenName,
      if (diagnostics != null && diagnostics.isNotEmpty)
        'diagnostics': jsonEncode(diagnostics),
    });

    if (screenshot != null && await screenshot.exists()) {
      formData.files.add(MapEntry(
        'screenshot',
        await MultipartFile.fromFile(
          screenshot.path,
          filename: screenshot.path.split(Platform.pathSeparator).last,
        ),
      ));
    }

    await _api.post('/support/issue-reports', data: formData);
  }
}

final issueReportRepositoryProvider = Provider<IssueReportRepository>((ref) {
  return IssueReportRepository(ref.read(apiServiceProvider));
});
