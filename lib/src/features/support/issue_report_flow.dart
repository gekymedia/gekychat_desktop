import 'package:flutter/material.dart';

import '../../widgets/settings_detail_modal.dart';
import 'issue_report_providers.dart';
import 'issue_report_screen.dart';

/// Opens the in-app issue report form from Settings.
class IssueReportFlow {
  static Future<void> openFromSettings(BuildContext context) {
    return showSettingsDetailModal(
      context,
      title: 'Report a problem',
      maxWidth: 560,
      child: const IssueReportScreen(source: IssueReportSource.settings),
    );
  }
}
