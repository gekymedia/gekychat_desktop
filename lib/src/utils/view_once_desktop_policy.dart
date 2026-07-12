import 'package:flutter/material.dart';
import 'snackbar_helper.dart';

/// View-once media is not opened on desktop — files can be copied via external apps.
const String kViewOnceDesktopUnavailableBody =
    'View once messages can only be opened in the GekyChat mobile app.';

void showViewOnceUnavailableOnDesktop(BuildContext context) {
    context.showInfoToast(kViewOnceDesktopUnavailableBody);}
