import 'call_repository.dart';
import 'current_user_phone.dart';

Future<void> requireCallerPhoneOnFile() async {
  final phone = await CurrentUserPhone.resolve();
  if (phone.isEmpty) {
    throw const CallStartException(
      'Add a phone number to your GekyChat account before placing calls.',
    );
  }
}
