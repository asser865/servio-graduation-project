import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/core/models/backend_booking_model.dart';

void main() {
  group('BackendBooking.fromJson', () {
    // Represents a real backend response where worker is a raw ObjectId string
    // and service is a populated object (as returned by booking.service.js)
    const Map<String, dynamic> fullJson = {
      '_id': 'booking123',
      'status': 'accepted',
      'scheduledDate': '2026-06-01T10:00:00.000Z',
      'totalPrice': 350.0,
      'description': 'Fix leaking pipe under sink',
      'worker': 'worker456',
      'service': {
        '_id': 'service789',
        'title': 'Plumbing',
        'category': 'home',
        'basePrice': 300,
        'priceUnit': 'fixed',
      },
      'user': {
        '_id': 'customer111',
        'name': 'Ahmed Hassan',
        'phone': '01012345678',
      },
      'address': '12 Tahrir St, Cairo',
    };

    test('parses booking id from _id', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.id, equals('booking123'));
    });

    test('parses status correctly', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.status, equals('accepted'));
    });

    test('parses totalAmount from totalPrice field', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.totalAmount, equals(350.0));
    });

    test('parses notes from description field', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.notes, equals('Fix leaking pipe under sink'));
    });

    test('parses service name from service.title (not service.name)', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.serviceName, equals('Plumbing'));
    });

    test('parses service id from service._id', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.serviceId, equals('service789'));
    });

    test('parses worker id from worker field when it is a raw string', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.workerId, equals('worker456'));
    });

    test('workerName is empty when worker is a raw id string (not populated)', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.workerName, equals(''));
    });

    test('parses customerName from user.name', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.customerName, equals('Ahmed Hassan'));
    });

    test('parses customerId from user._id', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.customerId, equals('customer111'));
    });

    test('parses address as a plain string into addressCity', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.addressCity, equals('12 Tahrir St, Cairo'));
    });

    test('parses scheduledDate correctly', () {
      final booking = BackendBooking.fromJson(fullJson);
      expect(booking.scheduledDate, equals(DateTime.parse('2026-06-01T10:00:00.000Z')));
    });

    test('handles missing optional fields with safe defaults', () {
      final booking = BackendBooking.fromJson({'_id': 'x'});
      expect(booking.id, equals('x'));
      expect(booking.status, equals('pending'));
      expect(booking.totalAmount, equals(0.0));
      expect(booking.notes, equals(''));
      expect(booking.serviceName, equals(''));
      expect(booking.serviceId, equals(''));
      expect(booking.workerId, equals(''));
      expect(booking.workerName, equals(''));
      expect(booking.customerName, equals(''));
      expect(booking.customerId, equals(''));
      expect(booking.addressCity, equals(''));
    });

    test('customerName is empty when user field is absent', () {
      final json = Map<String, dynamic>.from(fullJson)..remove('user');
      final booking = BackendBooking.fromJson(json);
      expect(booking.customerName, equals(''));
    });
  });
}
