import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/services/device_contacts_service.dart';

void main() {
  group('DeviceContactsService Tests', () {
    final service = DeviceContactsService();

    test('normalizePhone removes prefix and formatting characters', () {
      expect(service.normalizePhone('+84 912-345-678'), '912345678');
      expect(service.normalizePhone('0912 345 678'), '912345678');
      expect(service.normalizePhone('(0912) 345 678'), '912345678');
    });

    test('normalizePhone rejects invalid lengths', () {
      expect(service.normalizePhone('12345'), isEmpty);
      expect(service.normalizePhone('12345678'), isEmpty);
    });

    test('phoneForLookup restores leading zero for API lookup', () {
      expect(service.phoneForLookup('912345678'), '0912345678');
    });
  });
}
