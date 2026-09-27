import 'package:flutter_test/flutter_test.dart';
import 'package:gekychat_desktop/src/utils/phone_country.dart';

void main() {
  test('detects Ghana from +233 and local 0 numbers', () {
    expect(PhoneCountry.fromPhone('+233557547810'), 'Ghana');
    expect(PhoneCountry.fromPhone('0557547810'), 'Ghana');
    expect(PhoneCountry.phoneOriginLabel('+233557547810'),
        'Phone number from Ghana');
  });

  test('detects other dial codes', () {
    expect(PhoneCountry.fromPhone('+2348012345678'), 'Nigeria');
    expect(PhoneCountry.fromPhone('+447911123456'), 'United Kingdom');
  });
}
