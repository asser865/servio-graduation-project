import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/core/models/user_account.dart';

void main() {
  group('UserAccount services/pricing fields', () {
    test('fromBackend parses serviceIds', () {
      final json = _baseWorkerJson()
        ..['services'] = ['svc1', 'svc2'];

      final account = UserAccount.fromBackend(json);

      expect(account.serviceIds, ['svc1', 'svc2']);
    });

    test('fromBackend parses pendingCategories', () {
      final json = _baseWorkerJson()
        ..['pendingCategories'] = ['roofing', 'painting'];

      final account = UserAccount.fromBackend(json);

      expect(account.pendingCategories, ['roofing', 'painting']);
    });

    test('fromBackend parses pricing fields', () {
      final json = _baseWorkerJson()
        ..['minFee'] = 50
        ..['travelFee'] = 20
        ..['emergencyMultiplier'] = 1.5
        ..['acceptCash'] = true
        ..['acceptCard'] = false
        ..['acceptInstapay'] = true
        ..['acceptWallet'] = false;

      final account = UserAccount.fromBackend(json);

      expect(account.minFee, 50.0);
      expect(account.travelFee, 20.0);
      expect(account.emergencyMultiplier, 1.5);
      expect(account.acceptCash, true);
      expect(account.acceptCard, false);
      expect(account.acceptInstapay, true);
      expect(account.acceptWallet, false);
    });

    test('fromBackend uses safe defaults for missing fields', () {
      final account = UserAccount.fromBackend(_baseWorkerJson());

      expect(account.serviceIds, isEmpty);
      expect(account.pendingCategories, isEmpty);
      expect(account.minFee, 0.0);
      expect(account.travelFee, 0.0);
      expect(account.emergencyMultiplier, 1.0);
      expect(account.acceptCash, false);
      expect(account.acceptCard, false);
      expect(account.acceptInstapay, false);
      expect(account.acceptWallet, false);
    });

    test('fromBackend handles populated service objects (not just IDs)', () {
      final json = _baseWorkerJson()
        ..['services'] = [
          {'_id': 'svc1', 'title': 'Pipe Repair'},
          {'_id': 'svc2', 'title': 'Wiring'},
        ];

      final account = UserAccount.fromBackend(json);

      expect(account.serviceIds, ['svc1', 'svc2']);
    });

    test('copyWith updates serviceIds', () {
      final account = UserAccount.fromBackend(_baseWorkerJson());
      final updated = account.copyWith(serviceIds: ['svc3']);

      expect(updated.serviceIds, ['svc3']);
      expect(updated.name, account.name);
    });
  });
}

Map<String, dynamic> _baseWorkerJson() => {
      '_id': 'worker1',
      'name': 'Ali Hassan',
      'email': 'ali@example.com',
      'phone': '01012345678',
      'role': 'worker',
    };
