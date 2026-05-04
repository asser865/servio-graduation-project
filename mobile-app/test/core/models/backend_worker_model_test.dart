import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/core/models/backend_worker_model.dart';

void main() {
  group('BackendWorker.fromJson', () {
    test('prefers populated services over legacy categories and skills', () {
      final worker = BackendWorker.fromJson(const <String, dynamic>{
        '_id': 'worker1',
        'name': 'Mona Adel',
        'email': 'mona@example.com',
        'profileImage': 'https://example.com/mona.png',
        'bio': 'Licensed home maintenance specialist.',
        'skills': <String>['pipe repair'],
        'categories': <String>['plumbing', 'hvac'],
        'services': <Map<String, dynamic>>[
          <String, dynamic>{
            '_id': 'service1',
            'title': 'Drain Cleaning',
            'category': 'plumbing',
          },
          <String, dynamic>{
            '_id': 'service2',
            'name': 'AC Tune Up',
            'category': 'hvac',
          },
        ],
        'averageRating': 4.7,
        'totalReviews': 12,
        'yearsExperience': 6,
        'hourlyRate': 450,
        'isVerified': true,
        'availabilityType': 'weekdays',
      });

      expect(worker.id, 'worker1');
      expect(worker.displayName, 'Mona Adel');
      expect(worker.profileImage, 'https://example.com/mona.png');
      expect(worker.rating, 4.7);
      expect(worker.reviewCount, 12);
      expect(worker.yearsExperience, 6);
      expect(worker.serviceLabels, <String>['Drain Cleaning', 'AC Tune Up']);
    });

    test('falls back to readable categories when services are absent', () {
      final worker = BackendWorker.fromJson(const <String, dynamic>{
        '_id': 'worker2',
        'categories': <String>['plumbing', 'hvac'],
      });

      expect(worker.displayName, 'Technician');
      expect(worker.initials, 'T');
      expect(worker.serviceLabels, <String>['Plumbing', 'HVAC']);
      expect(worker.bio, '');
      expect(worker.rating, 0);
      expect(worker.reviewCount, 0);
    });

    test('falls back to skills when services and categories are absent', () {
      final worker = BackendWorker.fromJson(const <String, dynamic>{
        '_id': 'worker3',
        'skills': <String>['leak repair', 'wall-painting'],
      });

      expect(worker.serviceLabels, <String>['Leak Repair', 'Wall Painting']);
    });
  });
}
