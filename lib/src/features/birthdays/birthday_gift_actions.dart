import 'package:flutter/material.dart';

import '../sika/sika_send_coins_sheet.dart';
import '../../utils/snackbar_helper.dart';
import 'models.dart';

/// Opens GekyCoin gift flow for a birthday celebrant.
void showBirthdayGiftSheet(BuildContext context, BirthdayCelebrant celebrant) {
  if (celebrant.isSelf) {
    context.showInfoToast('Treat yourself from your Sika wallet');
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, __) => SikaSendCoinsSheet(
        isGift: true,
        preselectedUserId: celebrant.userId,
        preselectedUserName: celebrant.name,
      ),
    ),
  );
}
